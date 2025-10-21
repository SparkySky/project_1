import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'sound_trigger.dart';
import 'gemini_analysis_service.dart' hide GEMINI_API_KEY;
import '../lodge_incident_page.dart';
import '../api_keys.dart';

//region Adjustable Thresholds and Configuration
/// TODO: Fine-tune these values based on testing.

/// Threshold for significant motion (e.g., a fall or sudden stop).
/// This is the magnitude of the accelerometer vector.
const double HIGH_MOTION_THRESHOLD = 25.0; // m/s^2

/// Threshold for significant rotation (e.g., a spin or fall).
const double HIGH_ROTATION_THRESHOLD = 15.0; // rad/s

/// Time window in seconds to correlate sound and motion events.
const int EVENT_CORRELATION_WINDOW_SECONDS = 5;

/// The Gemini model to use for analysis.
/// Selected based on the available models for your API version.
const String GEMINI_MODEL = 'gemini-2.0-flash';
//endregion

class SensorsAnalysisService {
  final SoundTriggerService _soundTriggerService = SoundTriggerService();
  final GeminiAnalysisService _geminiAnalysisService =
      GeminiAnalysisService(apiKey: GEMINI_API_KEY, modelName: GEMINI_MODEL);
  final GlobalKey<NavigatorState> navigatorKey;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  AccelerometerEvent? _lastAccelerometerEvent;
  GyroscopeEvent? _lastGyroscopeEvent;

  SensorsAnalysisService({required this.navigatorKey});

  /// Initializes the services and starts listening to sensors.
  Future<void> initialize() async {
    await _soundTriggerService.initialize(
      onKeywordDetected: _handleKeywordDetection,
    );
    _soundTriggerService.startListening();
    _startListeningToSensors();
  }

  /// Starts listening to accelerometer and gyroscope.
  void _startListeningToSensors() {
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      _lastAccelerometerEvent = event;
      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > HIGH_MOTION_THRESHOLD) {
        if (kDebugMode) {
          print(
              '[SensorsAnalysisService] High motion detected: ${magnitude.toStringAsFixed(2)}');
        }
        _analyzeAndTriggerIfNeeded(speech: "High motion detected");
      }
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _lastGyroscopeEvent = event;
      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > HIGH_ROTATION_THRESHOLD) {
        if (kDebugMode) {
          print(
              '[SensorsAnalysisService] High rotation detected: ${magnitude.toStringAsFixed(2)}');
        }
        _analyzeAndTriggerIfNeeded(speech: "High rotation detected");
      }
    });
  }

  /// Handles the detection of an emergency keyword.
  void _handleKeywordDetection(String keyword) {
    _analyzeAndTriggerIfNeeded(speech: "Emergency keyword: $keyword");
  }

  /// The core AI/LLM logic.
  Future<void> _analyzeAndTriggerIfNeeded({required String speech}) async {
    // Ensure we have recent sensor data
    if (_lastAccelerometerEvent == null || _lastGyroscopeEvent == null) {
      return;
    }

    final analysisResult = await _geminiAnalysisService.analyzeIncident(
      accelX: _lastAccelerometerEvent!.x,
      accelY: _lastAccelerometerEvent!.y,
      accelZ: _lastAccelerometerEvent!.z,
      gyroX: _lastGyroscopeEvent!.x,
      gyroY: _lastGyroscopeEvent!.y,
      gyroZ: _lastGyroscopeEvent!.z,
      speech: speech,
    );

    if (analysisResult != null && analysisResult['isIncident'] == true) {
      if (kDebugMode) {
        print(
            '[SensorsAnalysisService] Gemini detected an incident: $analysisResult');
      }
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LodgeIncidentPage(
            incidentType: analysisResult['incidentType'],
            description: analysisResult['description'],
            district: analysisResult['district'],
            postcode: analysisResult['postcode'],
            state: analysisResult['state'],
          ),
        ),
      );
    }
  }

  /// Stops all listeners.
  void dispose() {
    _soundTriggerService.dispose();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
  }
}
