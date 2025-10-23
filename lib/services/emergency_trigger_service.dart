import 'dart:async';

import '../util/imu_centre.dart';
import '../util/location_centre.dart';
import '../util/microphone_centre.dart';
import 'ai_analysis_service.dart';
import 'cloud_db_service.dart';
import 'package:flutter/material.dart';
import 'hms_cloud_function_service.dart';

class EmergencyTriggerService {
  // Create an instance of the audio analysis service
  final HmsAudioAnalysisService _audioAnalysisService = HmsAudioAnalysisService();

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
      // Ensure context is available before formatting time
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null) {
        final timestamp = TimeOfDay.now().format(currentContext);
        imuReadings.add(
            "[$timestamp] Accel: X:${event.x.toStringAsFixed(2)}, Y:${event.y.toStringAsFixed(2)}, Z:${event.z.toStringAsFixed(2)}");
      } else {
        // Fallback if context is not immediately available
        imuReadings.add(
            "[${DateTime.now().toIso8601String()}] Accel: X:${event.x.toStringAsFixed(2)}, Y:${event.y.toStringAsFixed(2)}, Z:${event.z.toStringAsFixed(2)}");
      }

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
      _isProcessingIncident = false; // Reset flag
      // Maybe show a quick error message to the user?
      return;
    }
    print("EmergencyTrigger: Audio recorded to $audioPath");


// --- ⬇️ USE THE HMS AUDIO ANALYSIS SERVICE HERE ⬇️ ---
    print("EmergencyTrigger: Sending audio for HMS Cloud Function analysis...");
    // Replace _aiService.processAudio with _audioAnalysisService.analyzeAudio
    final audioAnalysisResult = await _audioAnalysisService.analyzeAudio(audioPath);

    // --- Handle potential errors from the Cloud Function ---
    if (audioAnalysisResult.containsKey('error')) {
      print("EmergencyTrigger: HMS Audio analysis failed: ${audioAnalysisResult['error']}");
      _isProcessingIncident = false; // Reset flag
      // Decide how to handle the error (e.g., log it, show message, restart)
      _restartTriggerSystem(); // Example: Restart detection
      return; // Stop processing this trigger
    }
    // --- ✅ SUCCESSFUL ANALYSIS - Extract results ---
    String transcription = audioAnalysisResult['transcription'] ?? "";
    String emotion = audioAnalysisResult['emotion'] ?? "unknown";
    print("EmergencyTrigger: HMS Analysis Result - Transcription: '$transcription', Emotion: '$emotion'");
    // --- ⬆️ END OF HMS AUDIO ANALYSIS CALL ⬆️ ---


    // --- Call Gemini Service with the results from HMS ---
    print("EmergencyTrigger: Sending data to Gemini for analysis...");
    final aiResult = await _aiService.analyzeIncident(
      trigger: trigger,
      imuReadings: imuReadings.take(10).toList(), // Take up to 10 readings
      audioTranscription: transcription, // Use transcription from HMS
      audioEmotion: emotion,             // Use emotion from HMS
    );

    // --- Handle Gemini Result ---
    bool isTruePositive = aiResult["isTruePositive"] ?? false; // Default to false if key doesn't exist
    String geminiDescription = aiResult["description"] ?? "AI analysis description unavailable.";

    _showResultVisual(isTruePositive);

    if (isTruePositive) {
      print("EmergencyTrigger: Gemini confirmed TRUE POSITIVE. Submitting incident.");
      final currentLocation = await _locationCentre.getCurrentLocation();
      if (currentLocation != null && currentLocation.latitude != null && currentLocation.longitude != null) {

        // TODO: Implement media upload to Cloud Storage and get mediaID
        String mediaId = "placeholder_media_id"; // Replace with actual ID after uploading audioPath file

        await _dbService.saveIncident(
          // TODO: Replace with actual user ID from your auth service
          uid: "current_user_id",
          latitude: currentLocation.latitude!,
          longitude: currentLocation.longitude!,
          datetime: DateTime.now(),
          incidentType: "threat",
          isAIGenerated: true,
          desc: geminiDescription, // Use description from Gemini
          mediaID: mediaId, // Use the ID from Cloud Storage
          status: "active",
        );
        print("EmergencyTrigger: Incident submitted to CloudDB.");
      } else {
        print("EmergencyTrigger: Failed to get current location for incident submission.");
      }
    } else {
      print("EmergencyTrigger: Gemini confirmed FALSE POSITIVE.");
      _restartTriggerSystem(); // Restart if false positive
    }

    // Reset processing flag only after handling is complete (or aborted)
    // Removed the reset from here, it's handled in error cases and after submission/restart.
    // _isProcessingIncident = false;
  }

  void _restartTriggerSystem() {
    print("EmergencyTrigger: Restarting detection loop.");
    _isProcessingIncident = false; // Ensure flag is reset before restarting
    // Add logic here if needed to explicitly re-enable listeners,
    // though _startListeningForTriggers might handle this if called again.
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
