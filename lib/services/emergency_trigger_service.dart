import 'dart:async';

import '../util/imu_centre.dart';
import '../util/location_centre.dart';
import '../util/microphone_centre.dart';
import 'ai_analysis_service.dart';
import 'cloud_db_service.dart';
import 'package:flutter/material.dart';

class EmergencyTriggerService {
  static final EmergencyTriggerService _instance = EmergencyTriggerService._internal();
  factory EmergencyTriggerService() => _instance;
  EmergencyTriggerService._internal();

  final _imuCentre = IMUCentre();
  final _locationCentre = LocationCentre();
  final _microphoneCentre = MicrophoneCentre();
  final _aiService = AiAnalysisService();
  final _dbService = CloudDBService();

  bool _isEmergencyResponseEnabled = false;
  bool _isProcessingIncident = false;

  StreamSubscription? _magnitudeSubscription;
  
  // This would be used for real-time audio analysis if implemented
  // StreamSubscription? _audioSubscription;

  Future<void> init() async {
    _imuCentre.startIMUUpdates();
    await _locationCentre.init();
    _locationCentre.startLocationUpdates();
    await _dbService.init();
  }

  void enableEmergencyResponse(bool isEnabled) {
    _isEmergencyResponseEnabled = isEnabled;
    if (isEnabled) {
      _startListeningForTriggers();
    } else {
      _stopListeningForTriggers();
    }
  }

  void _startListeningForTriggers() {
    _magnitudeSubscription ??= _imuCentre.magnitudeStream.listen(_onMagnitudeChange);
    // In a real app, you would also start listening for distress keywords here.
  }

  void _stopListeningForTriggers() {
    _magnitudeSubscription?.cancel();
    _magnitudeSubscription = null;
  }

  void _onMagnitudeChange(double magnitude) {
    // Debug print to see the magnitude in the console
    print("Current IMU Magnitude: ${magnitude.toStringAsFixed(2)}");

    // Example threshold, this would need to be tuned
    if (!_isProcessingIncident && magnitude > 20.0) { 
      _isProcessingIncident = true;
      _handlePotentialIncident("IMU Trigger: High magnitude detected");
    }
  }
  
  /// Call this from a debug button to test the incident flow.
  void manualTrigger() {
    if (!_isProcessingIncident) {
      print("MANUAL TRIGGER ACTIVATED");
      _isProcessingIncident = true;
      _handlePotentialIncident("Manual Trigger");
    } else {
      print("Manual trigger ignored: Incident already in progress.");
    }
  }


  Future<void> _handlePotentialIncident(String trigger) async {
    print("Potential incident triggered: $trigger");

    List<String> imuReadings = [];
    final recordingCompleter = Completer<String?>();

    // Start 8-second collection window
    final imuSubscription = _imuCentre.accelerometerStream.listen((event) {
      final timestamp = TimeOfDay.now().format(navigatorKey.currentContext!);
      // Fixed typo here: toStringAsField -> toStringAsFixed
      imuReadings.add("[$timestamp] Accel: X:${event.x.toStringAsFixed(2)}, Y:${event.y.toStringAsFixed(2)}, Z:${event.z.toStringAsFixed(2)}");
    });

    _microphoneCentre.startRecording();
    
    Future.delayed(const Duration(seconds: 8), () async {
      imuSubscription.cancel();
      final audioPath = await _microphoneCentre.stopRecording();
      recordingCompleter.complete(audioPath);
    });

    final audioPath = await recordingCompleter.future;

    if (audioPath == null) {
      print("Failed to record audio. Aborting incident processing.");
      _isProcessingIncident = false;
      return;
    }

    final audioAnalysis = await _aiService.processAudio(audioPath);

    final aiResult = await _aiService.analyzeIncident(
      trigger: trigger,
      imuReadings: imuReadings.take(10).toList(), // Take up to 10 readings
      audioTranscription: audioAnalysis["transcription"]!,
      audioEmotion: audioAnalysis["emotion"]!,
    );

    _showResultVisual(aiResult["isTruePositive"]);

    if (aiResult["isTruePositive"]) {
      final currentLocation = await _locationCentre.getCurrentLocation();
      if (currentLocation != null && currentLocation.latitude != null && currentLocation.longitude != null) {
        _dbService.saveIncident(
          uid: "current_user_id", // Replace with actual user ID
          latitude: currentLocation.latitude!,
          longitude: currentLocation.longitude!,
          datetime: DateTime.now(),
          incidentType: "threat",
          isAIGenerated: true,
          desc: aiResult["description"],
          mediaID: audioPath,
          status: "active",
        );
      }
    }

    _isProcessingIncident = false;
  }
  
  void _showResultVisual(bool isTruePositive) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: isTruePositive ? Colors.red.withOpacity(0.7) : Colors.green.withOpacity(0.7),
        child: Center(
          child: Icon(
            isTruePositive ? Icons.dangerous : Icons.check_circle,
            color: Colors.white,
            size: 150,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }

  void dispose() {
    _stopListeningForTriggers();
    _imuCentre.dispose();
    _locationCentre.dispose();
    _microphoneCentre.dispose();
  }
}

// You need a way to get the current context for overlays. A global key on the Navigator is a common way.
// In your main.dart, you'd have something like:
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//
// And then assign it to your MaterialApp:
// MaterialApp(navigatorKey: navigatorKey, ...)
// For this example, I'll just define it here.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
