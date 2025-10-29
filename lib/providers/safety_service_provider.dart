import 'package:flutter/material.dart';
import '../bg_services/safety_trigger_service.dart';
import '../bg_services/overlay_service.dart';
import '../providers/user_provider.dart';
import '../lodge/lodge_incident_page.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing the Safety Trigger Service state
class SafetyServiceProvider extends ChangeNotifier {
  final SafetyTriggerService _service = SafetyTriggerService();

  bool _isEnabled = false;
  bool _isInitialized = false;
  String? _lastTrigger;
  bool? _lastAnalysisResult;
  List<IMUReading> _captureWindowData = [];
  String _captureTranscript = '';
  Map<String, dynamic>? _pendingLodgeData; // Store data for lodge navigation

  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  String? get lastTrigger => _lastTrigger;
  bool? get lastAnalysisResult => _lastAnalysisResult;
  List<IMUReading> get captureWindowData => _captureWindowData;
  String get captureTranscript => _captureTranscript;
  bool get isCaptureWindowActive => _service.isCaptureWindowActive;

  // Debug streams
  Stream<double> get magnitudeDebugStream => _service.magnitudeDebugStream;
  Stream<String> get transcriptDebugStream => _service.transcriptDebugStream;

  SafetyServiceProvider() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _service.initialize();

    final overlayService = OverlayService();

    // Set up callbacks
    _service.onTriggerDetectedCallback = (source) {
      _lastTrigger = source;
      notifyListeners();

      // Show capture window overlay
      overlayService.showCaptureWindow();
    };

    _service.onStartAnalyzing = () {


      // Hide capture window and show analyzing screen
      overlayService.showAnalyzingScreen();
    };

    _service.onAnalysisResult = (isIncident, title, description, transcript) {
      _lastAnalysisResult = isIncident;
      notifyListeners();
      if (isIncident) {
        // TRUE POSITIVE: Show 15-second confirmation screen
        // Store data for later use
        _pendingLodgeData = {
          'title': title,
          'description': description,
          'transcript': transcript,
          'triggerSource': _lastTrigger ?? 'Unknown',
        };

        overlayService.showIncidentConfirmation(
          description: description,
          transcript: transcript,
          onConfirm: () {
            // User did NOT cancel - proceed to lodge page
            overlayService.hideCurrentOverlay();
            _triggerLodgeNavigation();
            // Monitoring will resume after lodge page is submitted or closed
          },
          onCancel: () {
            // User clicked FALSE ALARM - restart monitoring immediately

            overlayService.hideCurrentOverlay();
            _pendingLodgeData = null;
            // Resume monitoring immediately
            _service.resumeMonitoring();
          },
        );
      } else {
        // FALSE POSITIVE: Show simple result screen
        overlayService.showAnalysisResult(
          isIncident: false,
          description: description,
          triggerSource: _lastTrigger ?? 'Unknown',
          transcript: transcript,
          onDismiss: () {
            // Resume monitoring when user dismisses false positive
            _service.resumeMonitoring();
          },
        );
      }
    };

    _service.onCaptureWindowData = (readings, transcript) {
      _captureWindowData = readings;
      _captureTranscript = transcript;
      notifyListeners();
    };

    _service.onNavigateToLodge = (lodgeData) {

      // Store the lodge data from the service (includes audio file path, location, etc.)
      _pendingLodgeData = {
        ...?_pendingLodgeData, // Keep existing data (description, transcript)
        ...lodgeData, // Add service data (mediaID, latitude, longitude, etc.)
      };
      // Navigation will be triggered by the confirmation screen's onConfirm callback
    };

    _isInitialized = true;
    notifyListeners();
  }

  /// Navigate to lodge page with pre-filled data
  void _triggerLodgeNavigation() {
    if (_pendingLodgeData == null) {

      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {

      return;
    }

    // Extract data from pending lodge data
    final title = _pendingLodgeData!['title'] as String? ?? '';
    final transcript = _pendingLodgeData!['transcript'] as String? ?? '';
    final aiDescription = _pendingLodgeData!['description'] as String? ?? '';

    // Format the description with transcript and AI analysis
    final formattedDescription =
        'Transcript: "$transcript"\n\nAI Description: $aiDescription';

    // Get audio file path (mediaID from service)
    final audioPath = _pendingLodgeData!['mediaID'] as String? ?? '';






    navigator
        .push(
          MaterialPageRoute(
            builder: (context) => LodgeIncidentPage(
              incidentType:
                  'threat', // Always "threat" for AI-detected incidents
              title: title, // Pass the AI-generated title
              description: formattedDescription,
              audioRecordingPath: audioPath, // Pass the 8-second audio file
              // Lodge page will handle district, postcode, state from coordinates internally
            ),
          ),
        )
        .then((_) {
          // Resume monitoring when user returns from lodge page (submitted or cancelled)
          _service.resumeMonitoring();
        });

    // Clear pending data
    _pendingLodgeData = null;
  }

  /// Toggle the safety service on/off
  Future<void> toggle(bool enabled, BuildContext context) async {
    if (!_isInitialized) {

      return;
    }

    if (enabled) {
      // Set current user ID and language preference
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.agcUser?.uid != null) {
        _service.setCurrentUserId(userProvider.agcUser!.uid!);

        // Load preferred language from SharedPreferences (persistent)
        // Falls back to CloudDB user, then defaults to 'en'
        final prefs = await SharedPreferences.getInstance();
        final savedLanguage = prefs.getString('voice_detection_language');

        final detectionLanguage =
            savedLanguage ??
            userProvider.cloudDbUser?.detectionLanguage ??
            'en';
        await _service.setPreferredLanguage(detectionLanguage);
      }

      await _service.start();
      _isEnabled = true;
    } else {
      await _service.stop();
      _isEnabled = false;
      _lastTrigger = null;
      _lastAnalysisResult = null;
      _captureWindowData = [];
      _captureTranscript = '';
    }

    notifyListeners();
  }

  /// Manually trigger for testing
  Future<void> manualTrigger(String source) async {
    if (!_isEnabled) return;
    _service.onTriggerDetected(source);
  }

  /// Update language while system is running
  Future<void> updateLanguage(String language) async {


    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_detection_language', language);
    await _service.setPreferredLanguage(language);
  }

  /// Get available locales from the device
  Future<List<dynamic>> getAvailableLocales() async {
    return await _service.getAvailableLocales();
  }

  /// Cancel the current 8-second capture window
  Future<void> cancelCapture() async {

    await _service.cancelCapture();

    // Clear UI state
    _captureWindowData = [];
    _captureTranscript = '';
    _lastTrigger = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
