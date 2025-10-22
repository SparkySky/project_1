// lib/bg_services/data_collection_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'safety_config.dart';
import 'enhanced_sensor_manager.dart';

/// Data class to hold all information collected during the 8-second window
class CollectedIncidentData {
  final DateTime startTime;
  final List<String> initialTriggers;
  final List<SensorDataPoint> sensorDataPoints;
  final String fullTranscript;
  final String? audioFilePath;

  CollectedIncidentData({
    required this.startTime,
    required this.initialTriggers,
    required this.sensorDataPoints,
    required this.fullTranscript,
    this.audioFilePath,
  });

  String formatForGemini() {
    final sensorDataString = sensorDataPoints.map((p) => p.toString()).join('\n');
    final triggersString = initialTriggers.join(', ');
    return SafetyConfig.geminiPromptTemplate
        .replaceAll('{triggers}', triggersString)
        .replaceAll('{sensorData}', sensorDataString.isNotEmpty ? sensorDataString : "No significant sensor events.")
        .replaceAll('{transcript}', fullTranscript.isNotEmpty ? fullTranscript : "No speech detected.")
        .replaceAll('{emotions}', "None detected."); // Placeholder
  }
}

/// Manages the 8-second data collection window after a trigger
class DataCollectionManager {
  final EnhancedSensorManager sensorManager;
  final ServiceInstance service;
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isCollecting = false;
  Timer? _collectionTimer;
  Timer? _sensorLogTimer;
  DateTime? _collectionStartTime;
  Completer<CollectedIncidentData?>? _completer;

  final List<SensorDataPoint> _sensorDataPoints = [];
  final List<String> _initialTriggers = [];
  String? _audioFilePath;

  DataCollectionManager(this.sensorManager, this.service);

  Future<CollectedIncidentData?> startCollection({
    required String initialTrigger,
    required Map<String, dynamic> triggerContext,
  }) async {
    if (_isCollecting) return null;
    _log('==== STARTING 8-SECOND COLLECTION WINDOW ====');
    _isCollecting = true;
    _collectionStartTime = DateTime.now();
    _completer = Completer<CollectedIncidentData?>();

    _sensorDataPoints.clear();
    _initialTriggers.clear();
    _initialTriggers.add('$initialTrigger: ${_formatContext(triggerContext)}');
    _audioFilePath = null;

    await _startAudioRecording();
    _startSensorLogging();

    _collectionTimer = Timer(Duration(seconds: SafetyConfig.collectionWindowSeconds), _completeCollection);
    
    return _completer?.future;
  }

  void _startSensorLogging() {
    _sensorLogTimer = Timer.periodic(
      Duration(milliseconds: (SafetyConfig.sensorLogIntervalSeconds * 1000).toInt()),
      (timer) {
        final snapshot = sensorManager.getCurrentSensorSnapshot();
        final accelMag = snapshot['accel']?['magnitude'] ?? 0.0;
        final gyroMag = snapshot['gyro']?['magnitude'] ?? 0.0;
        String reason = '';
        if (SafetyConfig.shouldLogAcceleration(accelMag)) reason += 'High Accel; ';
        if (SafetyConfig.shouldLogRotation(gyroMag)) reason += 'High Gyro; ';

        if (reason.isNotEmpty) {
          final dataPoint = SensorDataPoint(
            timestamp: DateTime.now(),
            accelX: snapshot['accel']['x'], accelY: snapshot['accel']['y'], accelZ: snapshot['accel']['z'],
            gyroX: snapshot['gyro']['x'], gyroY: snapshot['gyro']['y'], gyroZ: snapshot['gyro']['z'],
            magX: snapshot['mag']?['x'] ?? 0.0, magY: snapshot['mag']?['y'] ?? 0.0, magZ: snapshot['mag']?['z'] ?? 0.0,
            accelMagnitude: accelMag, gyroMagnitude: gyroMag,
            triggerReason: reason.trim(),
          );
          _sensorDataPoints.add(dataPoint);
          
          service.invoke('updateCollectionData', {'sensorLog': dataPoint.toString()});
        }
        
        service.invoke('updateCollectionData', {'transcript': sensorManager.getRecentTranscript()});
      },
    );
  }

  Future<void> _startAudioRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _audioFilePath = '${directory.path}/incident_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _audioFilePath!,
      );
    } catch (e) {
      _log('ERROR starting audio recording: $e');
    }
  }

  Future<void> _completeCollection() async {
    if (!_isCollecting) return;

    _log('==== 8-SECOND COLLECTION WINDOW COMPLETE ====');
    _collectionTimer?.cancel();
    _sensorLogTimer?.cancel();
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    
    final collectedData = CollectedIncidentData(
      startTime: _collectionStartTime!,
      initialTriggers: List.from(_initialTriggers),
      sensorDataPoints: List.from(_sensorDataPoints),
      fullTranscript: sensorManager.getRecentTranscript(),
      audioFilePath: _audioFilePath,
    );
    
    sensorManager.clearTranscriptBuffer();
    _isCollecting = false;
    
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(collectedData);
    }
  }

  void stopCollection() {
    if (_isCollecting) {
      _log('Collection stopped prematurely.');
      _completeCollection();
    }
  }

  String _formatContext(Map<String, dynamic> context) => jsonEncode(context);
  
  void _log(String message) {
    if (SafetyConfig.enableVerboseLogging) {
      if (kDebugMode) print('[DataCollectionManager] $message');
    }
  }
}
