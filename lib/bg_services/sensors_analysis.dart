import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:project_1/services/hms_cloud_function_service.dart';
import 'sound_trigger.dart';
import 'gemini_analysis_service.dart';
import '../lodge_incident_page.dart';
import '../util/debug_state.dart';
import '../widgets/incident_collection_page.dart';


class SensorsAnalysisService {
  final SoundTriggerService _soundTriggerService = SoundTriggerService();
  final GeminiAnalysisService _geminiAnalysisService =
      GeminiAnalysisService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? '', modelName: 'gemini-2.0-flash');
  final HmsCloudFunctionService _hmsCloudService = HmsCloudFunctionService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final GlobalKey<NavigatorState> navigatorKey;
  
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  bool _isProcessingIncident = false;
  String? _audioRecordingPath;
  final DebugState _debugState = DebugState();

  SensorsAnalysisService({required this.navigatorKey});

  Future<void> initialize() async {
    await _soundTriggerService.initialize(
      onKeywordDetected: (keyword, sentence) => _onPotentialIncidentTrigger(trigger: "Keyword: '$keyword'"),
    );
    _soundTriggerService.startListening();
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    accelerometerEvents.listen((event) {
      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > 25.0) {
        _onPotentialIncidentTrigger(trigger: "High motion (${magnitude.toStringAsFixed(1)} m/s^2)");
      }
    });

    gyroscopeEvents.listen((event) {
      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > 15.0) {
        _onPotentialIncidentTrigger(trigger: "High rotation (${magnitude.toStringAsFixed(1)} rad/s)");
      }
    });
  }

  Future<void> _onPotentialIncidentTrigger({required String trigger}) async {
    if (_isProcessingIncident) return;
    _isProcessingIncident = true;
    _debugState.addTrigger(trigger);

    await _startAudioRecording();

    final collectedData = await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => IncidentCollectionPage(initialTrigger: trigger),
      ),
    );

    await _stopAudioRecording();

    if (collectedData == null || _audioRecordingPath == null) {
      print("[SensorsAnalysisService] Incident collection cancelled or failed. Resetting.");
      _resetState();
      return;
    }
    
    // Send audio to HMS Cloud Function for analysis
    final hmsResult = await _hmsCloudService.processAudioForAnalysis(_audioRecordingPath!);

    // Now send everything to Gemini
    final analysisResult = await _geminiAnalysisService.analyzeIncident(
      accelX: 0, // IMU data is now in a list, this needs adjustment in Gemini prompt
      accelY: 0,
      accelZ: 0,
      gyroX: 0,
      gyroY: 0,
      gyroZ: 0,
      initialTriggers: _debugState.collectedTriggers.toSet().join(", "),
      transcript: "IMU LOG:\n${collectedData['imuReadings'].join('\n')}\n\nTRANSCRIPT:\n${hmsResult['formatted_transcript']}",
    );

    final isTruePositive = analysisResult != null && analysisResult['isIncident'] == true;
    _showResultVisual(isTruePositive);

    if (isTruePositive) {
      _debugState.setGeminiVerdict("True Positive");
      pause();
      await navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LodgeIncidentPage(
            incidentType: analysisResult!['incidentType'],
            description: analysisResult['description'],
            district: analysisResult['district'],
            postcode: analysisResult['postcode'],
            state: analysisResult['state'],
            audioRecordingPath: _audioRecordingPath,
          ),
        ),
      );
      resume();
    } else {
      _debugState.setGeminiVerdict("False Positive");
    }

    _resetState();
  }

  void _resetState() {
    _isProcessingIncident = false;
    _audioRecordingPath = null;
    Future.delayed(const Duration(seconds: 5), () {
      _debugState.clearIncidentDebugInfo();
    });
  }

  void _showResultVisual(bool isTruePositive) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: isTruePositive ? Colors.red.withOpacity(0.7) : Colors.green.withOpacity(0.7),
        child: Center(child: Icon(isTruePositive ? Icons.dangerous_outlined : Icons.check_circle_outline, color: Colors.white, size: 150)),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () => overlayEntry.remove());
  }

  Future<void> _startAudioRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        _audioRecordingPath = '${directory.path}/incident_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _audioRecordingPath!);
      }
    } catch (e) {
      if (kDebugMode) print("[SensorsAnalysisService] Error recording audio: $e");
    }
  }

  Future<void> _stopAudioRecording() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
  }

  void pause() {
    _soundTriggerService.stopListening();
    _accelerometerSubscription?.pause();
    _gyroscopeSubscription?.pause();
  }

  void resume() {
    _soundTriggerService.startListening();
    _accelerometerSubscription?.resume();
    _gyroscopeSubscription?.resume();
  }

  void dispose() {
    _soundTriggerService.dispose();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _audioRecorder.dispose();
  }
}
