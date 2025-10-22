import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'safety_config.dart';

/// Enhanced sensor manager with sophisticated false positive elimination
class EnhancedSensorManager {
  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Speech recognition & Transcript Buffering
  final stt.SpeechToText _speech = stt.SpeechToText();
  final List<String> _transcriptBuffer = [];
  bool _isSpeechInitialized = false;
  bool _isListening = false;

  // Current sensor values
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;
  MagnetometerEvent? _lastMag;

  // False positive elimination
  final List<double> _recentAccelMagnitudes = [];
  final List<DateTime> _recentTriggerTimes = [];
  DateTime? _lastSustainedHighAccelStart;

  // Magnetometer baseline
  double? _baselineMagX, _baselineMagY, _baselineMagZ;

  // State
  Function(String triggerType, Map<String, dynamic> context)? _onTrigger;
  Timer? _debugTimer;
  Timer? _speechRestartTimer;

  EnhancedSensorManager();

  /// Checks for required permissions (Microphone and Location)
  Future<bool> checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    final locStatus = await Permission.locationAlways.status;
    return micStatus.isGranted && locStatus.isGranted;
  }

  /// Initialize and start monitoring
  Future<bool> initialize({
    required Function(String, Map<String, dynamic>) onTrigger,
  }) async {
    _onTrigger = onTrigger;
    _log("Initializing speech recognition...");
    _isSpeechInitialized = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
      debugLogging: SafetyConfig.enableVerboseLogging,
    );
    if (!_isSpeechInitialized) {
      _log('ERROR: Speech recognition initialization failed.');
      return false;
    }
    _log("Speech recognition initialized successfully.");
    resumeListeners(); // Start listeners on initial setup
    _startDebugTimer();
    return true;
  }

  /// Pauses all listeners during data collection.
  void pauseListeners() {
    _log('Pausing listeners for data collection...');
    _accelSubscription?.pause();
    _gyroSubscription?.pause();
    _magnetometerSubscription?.pause();
    _speechRestartTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    _isListening = false;
  }

  /// Resumes all listeners after data collection/cooldown.
  void resumeListeners() {
    _log('Resuming listeners...');
    _startSensors(); // Re-establishes the streams
    _startSpeechListening();
  }
  
  void _startSensors() {
    // Ensure old subscriptions are cancelled before creating new ones
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magnetometerSubscription?.cancel();

    _accelSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval)
        .listen(_onAccelEvent, onError: (e) => _log('Accelerometer error: $e'));
    
    _gyroSubscription = gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval)
        .listen(_onGyroEvent, onError: (e) => _log('Gyroscope error: $e'));

    _magnetometerSubscription = magnetometerEventStream(samplingPeriod: SensorInterval.normalInterval)
        .listen(_onMagnetometerEvent, onError: (e) => _log('Magnetometer error: $e'));
  }

  /// Handle accelerometer events with false positive filtering
  void _onAccelEvent(AccelerometerEvent event) {
    _lastAccel = event;
    final magnitude = SafetyConfig.calculateMagnitude(event.x, event.y, event.z);
    _recentAccelMagnitudes.add(magnitude);
    if (_recentAccelMagnitudes.length > 20) _recentAccelMagnitudes.removeAt(0);

    if (SafetyConfig.isHighAcceleration(magnitude)) {
      final now = DateTime.now();
      _lastSustainedHighAccelStart ??= now;
      final duration = now.difference(_lastSustainedHighAccelStart!);

      if (duration.inMilliseconds >= (SafetyConfig.minSustainedAccelDuration * 1000)) {
        if (!_isRepetitiveMotion()) {
          _triggerIncident('High Impact', {'magnitude': magnitude});
        }
        _lastSustainedHighAccelStart = null;
      }
    } else {
      _lastSustainedHighAccelStart = null;
    }
  }

  /// Handle gyroscope events
  void _onGyroEvent(GyroscopeEvent event) {
    _lastGyro = event;
    final magnitude = SafetyConfig.calculateMagnitude(event.x, event.y, event.z);
    if (SafetyConfig.isHighRotation(magnitude)) {
      _triggerIncident('Violent Rotation', {'magnitude': magnitude});
    }
  }

  /// Handle magnetometer events
  void _onMagnetometerEvent(MagnetometerEvent event) {
    _lastMag = event;
    _baselineMagX ??= event.x;
    _baselineMagY ??= event.y;
    _baselineMagZ ??= event.z;
    final change = max((event.x - _baselineMagX!).abs(), max((event.y - _baselineMagY!).abs(), (event.z - _baselineMagZ!).abs()));
    if (SafetyConfig.isSignificantMagnetometerChange(change)) {
      _triggerIncident('Environmental Anomaly', {'change': change});
    }
  }

  bool _isRepetitiveMotion() {
    if (_recentAccelMagnitudes.length < 10) return false;
    final mean = _recentAccelMagnitudes.reduce((a, b) => a + b) / _recentAccelMagnitudes.length;
    int crossings = 0;
    for (int i = 1; i < _recentAccelMagnitudes.length; i++) {
      if ((_recentAccelMagnitudes[i - 1] - mean) * (_recentAccelMagnitudes[i] - mean) < 0) {
        crossings++;
      }
    }
    final frequency = crossings / (_recentAccelMagnitudes.length * 0.2); // Approximation
    return frequency >= SafetyConfig.maxRepetitiveMotionFrequency;
  }

  void _startSpeechListening() {
    if (!_isSpeechInitialized || _isListening) return;
    _isListening = true;
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      onSoundLevelChange: _onSoundLevelChange,
    );
  }
  
  void _onSpeechResult(result) {
    if (result.finalResult) {
      final words = result.recognizedWords.toLowerCase();
      _transcriptBuffer.add(words);
      // Keep buffer size manageable, e.g., last 10 entries
      if (_transcriptBuffer.length > 10) {
        _transcriptBuffer.removeAt(0);
      }
      
      if (result.confidence < SafetyConfig.speechRecognitionConfidence) return;

      for (final keyword in SafetyConfig.emergencyKeywords) {
        if (RegExp(r'\b' + RegExp.escape(keyword) + r'\b').hasMatch(words)) {
          _triggerIncident('Distress Keyword', {'keyword': keyword, 'sentence': words});
          return;
        }
      }
    }
  }

  void _onSoundLevelChange(double level) {
    if (level > SafetyConfig.soundLevelThreshold) {
      _triggerIncident('Loud Noise', {'level': level});
    }
  }

  void _onSpeechStatus(String status) {
    _log('Speech status: $status');
    if ((status == 'notListening' || status == 'done') && _isListening) {
      // This handles graceful restarts (e.g., after a pause)
      _restartListening();
    }
  }

  void _onSpeechError(stt.SpeechRecognitionError error) {
    _log('Speech error: ${error.errorMsg}, permanent: ${error.permanent}');
    // This specifically handles the "no_match" error, which occurs during silence
    if (error.permanent && error.errorMsg == 'error_no_match') {
      _restartListening();
    }
  }
  
  void _restartListening() {
      _speechRestartTimer?.cancel();
      _speechRestartTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isListening && _isSpeechInitialized) {
          _startSpeechListening();
        }
      });
  }

  void _triggerIncident(String type, Map<String, dynamic> context) {
    final now = DateTime.now();
    _recentTriggerTimes.removeWhere((t) => now.difference(t).inSeconds > SafetyConfig.multipleTriggerWindowSeconds);
    _recentTriggerTimes.add(now);
    if (SafetyConfig.requireMultipleTriggers && _recentTriggerTimes.length < 2) {
      _log('Waiting for multiple triggers (${_recentTriggerTimes.length}/2)');
      return;
    }
    context['current_sensors'] = getCurrentSensorSnapshot();
    _onTrigger?.call(type, context);
    _recentTriggerTimes.clear();
  }

  /// Get current sensor snapshot for data collection
  Map<String, dynamic> getCurrentSensorSnapshot() {
    return {
      'accel': _lastAccel != null ? {'x': _lastAccel!.x, 'y': _lastAccel!.y, 'z': _lastAccel!.z, 'magnitude': SafetyConfig.calculateMagnitude(_lastAccel!.x, _lastAccel!.y, _lastAccel!.z)} : null,
      'gyro': _lastGyro != null ? {'x': _lastGyro!.x, 'y': _lastGyro!.y, 'z': _lastGyro!.z, 'magnitude': SafetyConfig.calculateMagnitude(_lastGyro!.x, _lastGyro!.y, _lastGyro!.z)} : null,
      'mag': _lastMag != null ? {'x': _lastMag!.x, 'y': _lastMag!.y, 'z': _lastMag!.z} : null,
    };
  }
  
  /// Public accessor for the recent transcript.
  String getRecentTranscript() => _transcriptBuffer.join('\n');
  
  /// Clears the transcript buffer after collection.
  void clearTranscriptBuffer() => _transcriptBuffer.clear();

  void _startDebugTimer() {
    _debugTimer?.cancel();
    if (!SafetyConfig.enableVerboseLogging) return;
    _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final accelMag = _lastAccel != null ? SafetyConfig.calculateMagnitude(_lastAccel!.x, _lastAccel!.y, _lastAccel!.z) : 0;
      final gyroMag = _lastGyro != null ? SafetyConfig.calculateMagnitude(_lastGyro!.x, _lastGyro!.y, _lastGyro!.z) : 0;
      _log('Status - Accel: ${accelMag.toStringAsFixed(1)} m/s², Gyro: ${gyroMag.toStringAsFixed(1)} rad/s, Speech: ${_isListening ? "Listening" : "Idle"}');
    });
  }

  /// Completely stops and disposes of all resources.
  void destroy() {
    _log('Destroying all listeners and resources...');
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _debugTimer?.cancel();
    _speechRestartTimer?.cancel();
    if (_speech.isListening) _speech.stop();
    _isListening = false;
  }
  
  void _log(String message) {
    if (SafetyConfig.enableVerboseLogging) {
      if (kDebugMode) print('[EnhancedSensorManager] $message');
    }
  }
}
