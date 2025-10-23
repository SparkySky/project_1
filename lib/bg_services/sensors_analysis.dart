import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'sound_trigger.dart';
import 'gemini_analysis_service.dart' hide GEMINI_API_KEY;
import '../lodge/lodge_incident_page.dart';
import '../api_keys.dart';
import '../util/debug_state.dart';

//region Adjustable Thresholds and Configuration
/// TODO: Fine-tune these values based on testing.

/// Threshold for significant motion (e.g., a fall or sudden stop).
const double HIGH_MOTION_THRESHOLD = 25.0; // m/s^2

/// Threshold for significant rotation (e.g., a spin or fall).
const double HIGH_ROTATION_THRESHOLD = 15.0; // rad/s

/// Time in seconds to collect data after an initial trigger.
const int DATA_COLLECTION_WINDOW_SECONDS = 10;

/// Duration in seconds to record audio evidence after a trigger.
const int AUDIO_RECORDING_DURATION_SECONDS = 20;

/// The Gemini model to use for analysis.
const String GEMINI_MODEL = 'gemini-2.0-flash';
//endregion

class SensorsAnalysisService {
  final SoundTriggerService _soundTriggerService = SoundTriggerService();
  final GeminiAnalysisService _geminiAnalysisService =
      GeminiAnalysisService(apiKey: GEMINI_API_KEY, modelName: GEMINI_MODEL);
  final AudioRecorder _audioRecorder = AudioRecorder();
  final stt.SpeechToText _contextualSpeech = stt.SpeechToText();
  final GlobalKey<NavigatorState> navigatorKey;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  // State for data collection window
  bool _isCollectingData = false;
  Timer? _collectionTimer;
  String _fullTranscript = "";
  AccelerometerEvent? _peakAccelEvent;
  GyroscopeEvent? _peakGyroEvent;
  String? _audioRecordingPath;
  final DebugState _debugState = DebugState();

  SensorsAnalysisService({required this.navigatorKey});

  Future<void> initialize() async {
    await _soundTriggerService.initialize(
      onKeywordDetected: _handleKeywordDetection,
    );
    await _contextualSpeech.initialize();
    _soundTriggerService.startListening();
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      if (_isCollectingData) {
        if (_peakAccelEvent == null ||
            (event.x.abs() + event.y.abs() + event.z.abs()) >
                (_peakAccelEvent!.x.abs() +
                    _peakAccelEvent!.y.abs() +
                    _peakAccelEvent!.z.abs())) {
          _peakAccelEvent = event;
        }
      }

      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > HIGH_MOTION_THRESHOLD) {
        _onPotentialIncidentTrigger(
            trigger: "High motion (${magnitude.toStringAsFixed(1)} m/s^2)");
      }
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (_isCollectingData) {
        if (_peakGyroEvent == null ||
            (event.x.abs() + event.y.abs() + event.z.abs()) >
                (_peakGyroEvent!.x.abs() +
                    _peakGyroEvent!.y.abs() +
                    _peakGyroEvent!.z.abs())) {
          _peakGyroEvent = event;
        }
      }

      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > HIGH_ROTATION_THRESHOLD) {
        _onPotentialIncidentTrigger(
            trigger: "High rotation (${magnitude.toStringAsFixed(1)} rad/s)");
      }
    });
  }

  void _handleKeywordDetection(String keyword, String fullSentence) {
    // We no longer use the full sentence from the trigger service,
    // as we are now capturing the full 10-second context ourselves.
    _onPotentialIncidentTrigger(trigger: "Keyword: '$keyword'");
  }

  void _onPotentialIncidentTrigger({required String trigger}) {
    if (_isCollectingData) {
      if (kDebugMode) {
        print("[SensorsAnalysisService] Adding to collection: $trigger");
      }
      _debugState.addTrigger(trigger);
      return;
    }

    if (kDebugMode) {
      print(
          "[SensorsAnalysisService] First trigger. Starting ${DATA_COLLECTION_WINDOW_SECONDS}s window.");
    }
    _isCollectingData = true;
    _debugState.addTrigger(trigger);
    _peakAccelEvent = null;
    _peakGyroEvent = null;

    // Start evidence gathering
    _startAudioRecording();
    _startContextualSpeechCapture();

    _collectionTimer?.cancel();
    _collectionTimer = Timer(
        const Duration(seconds: DATA_COLLECTION_WINDOW_SECONDS),
        _finalizeAndAnalyzeIncident);
  }

  void _startContextualSpeechCapture() {
    if (!_contextualSpeech.isListening) {
      _contextualSpeech.listen(
        onResult: (result) {
          _fullTranscript = result.recognizedWords;
          // Also update the debug overlay with the live transcript
          _debugState.updateRecognizedWords(_fullTranscript);
        },
        listenFor: const Duration(seconds: DATA_COLLECTION_WINDOW_SECONDS + 2),
      );
    }
  }

  Future<void> _finalizeAndAnalyzeIncident() async {
    if (kDebugMode) {
      print(
          "[SensorsAnalysisService] Collection window finished. Finalizing...");
    }
    _contextualSpeech.stop();

    final initialTriggers = _debugState.collectedTriggers.toSet().join(", ");

    final analysisResult = await _geminiAnalysisService.analyzeIncident(
      accelX: _peakAccelEvent?.x ?? 0.0,
      accelY: _peakAccelEvent?.y ?? 0.0,
      accelZ: _peakAccelEvent?.z ?? 0.0,
      gyroX: _peakGyroEvent?.x ?? 0.0,
      gyroY: _peakGyroEvent?.y ?? 0.0,
      gyroZ: _peakGyroEvent?.z ?? 0.0,
      initialTriggers: initialTriggers,
      transcript: _fullTranscript,
    );

    if (analysisResult != null && analysisResult['isIncident'] == true) {
      if (kDebugMode) {
        print(
            '[SensorsAnalysisService] Gemini confirmed an incident: $analysisResult');
      }
      _debugState.setGeminiVerdict("True Positive");
      
      pause();

      await navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LodgeIncidentPage(
            incidentType: analysisResult['incidentType'],
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
      if (kDebugMode) {
        print(
            '[SensorsAnalysisService] Gemini classified as false positive. Resetting.');
      }
      _debugState.setGeminiVerdict("False Positive");
    }

    _isCollectingData = false;
    _fullTranscript = "";
    _peakAccelEvent = null;
    _peakGyroEvent = null;
    _audioRecordingPath = null;
    _collectionTimer = null;

    // Clear the debug info after a short delay so the user can see the verdict.
    Future.delayed(const Duration(seconds: 5), () {
      _debugState.clearIncidentDebugInfo();
    });
  }

  Future<void> _startAudioRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        _audioRecordingPath =
            '${directory.path}/incident_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _audioRecordingPath!,
        );

        Future.delayed(
            const Duration(seconds: AUDIO_RECORDING_DURATION_SECONDS), () async {
          if (await _audioRecorder.isRecording()) {
            await _audioRecorder.stop();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("[SensorsAnalysisService] Error recording audio: $e");
      }
    }
  }

  void pause() {
    if (kDebugMode) {
      print("[SensorsAnalysisService] Pausing monitoring.");
    }
    _soundTriggerService.stopListening();
    _accelerometerSubscription?.pause();
    _gyroscopeSubscription?.pause();
  }

  void resume() {
    if (kDebugMode) {
      print("[SensorsAnalysisService] Resuming monitoring.");
    }
    _soundTriggerService.startListening();
    _accelerometerSubscription?.resume();
    _gyroscopeSubscription?.resume();
  }

  void dispose() {
    _soundTriggerService.dispose();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _collectionTimer?.cancel();
    _audioRecorder.dispose();
    _contextualSpeech.stop();
  }
}
