// lib/bg_services/sensor_manager.dart
import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:huawei_ml_language/huawei_ml_language.dart';

class SensorManager {
  // HMS Listeners
  MLSpeechRealTimeTranscription? _speechRealTimeTranscription;

  // Sensor Listener Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // State
  Timer? _debugTimer;
  AccelerometerEvent? _lastAccelEvent;
  GyroscopeEvent? _lastGyroEvent;
  Function(String)? _onTrigger;
  bool _isSpeechRealTimeTranscriptionStarted = false;

  SensorManager(); // Constructor

  void startMonitoring({required Function(String) onTrigger}) {
    print("[SENSOR_MANAGER] Starting sensor monitoring...");
    _onTrigger = onTrigger;
    _startSpeechRealTimeTranscription();
    _startImuSensors();
    _startDebugTimer();
  }

  void _startSpeechRealTimeTranscription() async {
    print("[SENSOR_MANAGER] - _startSpeechRealTimeTranscription()");
    try {
      _speechRealTimeTranscription = MLSpeechRealTimeTranscription();
      
      // Create an anonymous implementation of MLSpeechRealTimeTranscriptionListener
      _speechRealTimeTranscription?.setRealTimeTranscriptionListener(
        MLSpeechRealTimeTranscriptionListener(
          onResult: (
            MLSpeechRealTimeTranscriptionResult result,
          ) {
            final text = result.result; // Get the transcribed text using the 'result' property
            print("[SENSOR_MANAGER] - Text: '$text'");
            if (text != null && text.toLowerCase().contains("help")) {
              print("[SENSOR_MANAGER] TRIGGER: 'Help' keyword detected! Transcribed: '$text'");
              _onTrigger?.call("Help Keyword Detected");
              // Stop and restart recognizer to avoid multiple triggers on the same utterance
              _speechRealTimeTranscription?.destroy();
              _speechRealTimeTranscription = null;
              _isSpeechRealTimeTranscriptionStarted = false;
              _startSpeechRealTimeTranscription(); // Restart for continuous monitoring
            }
          },
          onError: (
            int errCode,
            String errorMessage,
          ) {
            print("[SENSOR_MANAGER] MLSpeechRealTimeTranscription Error: $errCode - $errorMessage");
            // Handle error, e.g., restart recognizer
            _speechRealTimeTranscription?.destroy();
            _speechRealTimeTranscription = null;
            _isSpeechRealTimeTranscriptionStarted = false;
            _startSpeechRealTimeTranscription();
          },
          // You can add other optional callbacks here if needed:
          // onStartListening: () { print("[SENSOR_MANAGER] RealTimeTranscription: onStartListening"); },
          // onStartingOfSpeech: () { print("[SENSOR_MANAGER] RealTimeTranscription: onStartingOfSpeech"); },
          // onState: (int state) { print("[SENSOR_MANAGER] RealTimeTranscription: onState: $state"); },
          // onVoiceDataReceived: (Uint8List voiceData) { /* Handle voice data */ },
        ),
      );

      final config = MLSpeechRealTimeTranscriptionConfig(
        language: MLSpeechRealTimeTranscriptionConfig.LAN_EN_US,
        // You can add other configurations here if needed, e.g., enablePunctuation
      );

      _speechRealTimeTranscription?.startRecognizing(config); // Removed 'await'
      _isSpeechRealTimeTranscriptionStarted = true;
      print("[SENSOR_MANAGER] MLSpeechRealTimeTranscription started for keyword detection.");
    } catch (e) {
      print("[SENSOR_MANAGER] Error starting MLSpeechRealTimeTranscription: $e");
      _isSpeechRealTimeTranscriptionStarted = false;
      _speechRealTimeTranscription = null;
    }
  }

  // The _onRealTimeTranscriptionResult function is no longer needed as the listener is implemented anonymously.

  void _startImuSensors() {
    try {
      _accelSubscription = accelerometerEventStream(
          samplingPeriod: SensorInterval.normalInterval
      ).listen(_onAccelEvent, onError: (e) { print("[SENSOR_MANAGER] Accel Error: $e");});

      _gyroSubscription = gyroscopeEventStream(
          samplingPeriod: SensorInterval.normalInterval
      ).listen(_onGyroEvent, onError: (e) { print("[SENSOR_MANAGER] Gyro Error: $e");});
      print("[SENSOR_MANAGER] IMU sensors started.");
    } catch (e) {
      print("[SENSOR_MANAGER] Error starting IMU sensors: $e");
    }
  }

  void _startDebugTimer() {
    _debugTimer?.cancel(); // Cancel any existing timer
    _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final accel = _lastAccelEvent;
      final gyro = _lastGyroEvent;
      if (accel != null && gyro != null) {
        print("[SENSOR_DEBUG] Accel(x: ${accel.x.toStringAsFixed(2)}, y: ${accel.y.toStringAsFixed(2)}, z: ${accel.z.toStringAsFixed(2)}) | Gyro(x: ${gyro.x.toStringAsFixed(2)}, y: ${gyro.y.toStringAsFixed(2)}, z: ${gyro.z.toStringAsFixed(2)})");
      }
    });
  }

  void _onAccelEvent(AccelerometerEvent event) {
    _lastAccelEvent = event;
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (magnitude > 35.0) {
      print("[SENSOR_MANAGER] TRIGGER: High-G event detected! ($magnitude m/s^2)");
      _onTrigger?.call("Impact Detected");
    }
  }

  void _onGyroEvent(GyroscopeEvent event) {
    _lastGyroEvent = event;
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (magnitude > 10.0) {
      print("[SENSOR_MANAGER] TRIGGER: Violent rotation detected! ($magnitude rad/s)");
      _onTrigger?.call("Violent Motion Detected");
    }
  }

  void stopAllListeners() {
    print("[SENSOR_MANAGER] Stopping all sensor listeners...");
    _debugTimer?.cancel();
    _debugTimer = null;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;

    if (_speechRealTimeTranscription != null && _isSpeechRealTimeTranscriptionStarted) {
      try {
        _speechRealTimeTranscription?.destroy();
      } catch (e) {
        print("[SENSOR_MANAGER] Error destroying MLSpeechRealTimeTranscription: $e");
      }
    }
    _speechRealTimeTranscription = null;
    _isSpeechRealTimeTranscriptionStarted = false;
    print("[SENSOR_MANAGER] Sensor listeners stopped.");
  }
}
