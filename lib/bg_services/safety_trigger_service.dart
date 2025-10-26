import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../sensors/microphone_centre.dart';
import '../sensors/location_centre.dart';
import '../util/imu_centre.dart';
import '../bg_services/gemini_analysis_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

/// Central service for managing the emergency safety trigger system
class SafetyTriggerService {
  static final SafetyTriggerService _instance =
      SafetyTriggerService._internal();
  factory SafetyTriggerService() => _instance;
  SafetyTriggerService._internal();

  // Centralized sensor services
  final MicrophoneService _microphoneService = MicrophoneService();
  final LocationServiceHelper _locationService = LocationServiceHelper();
  final IMUCentre _imuCentre = IMUCentre();

  // Gemini service for AI analysis
  late GeminiAnalysisService _geminiService;

  // Current user ID for location updates
  String? _currentUserId;

  // State management
  bool _isRunning = false;
  bool _isCaptureWindowActive = false;

  // Public getters
  bool get isCaptureWindowActive => _isCaptureWindowActive;

  /// Get available locales from microphone service
  Future<List<dynamic>> getAvailableLocales() async {
    return await _microphoneService.getAvailableLocales();
  }

  // Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<double>? _magnitudeSubscription;
  StreamSubscription<String>? _keywordSubscription;
  StreamSubscription<String>? _transcriptSubscription;

  // Data collection for 8-second window
  final List<IMUReading> _imuReadings = [];
  String? _audioFilePath;
  String _triggerSource = '';
  Timer? _captureTimer;

  // Thresholds
  static const double IMU_MAGNITUDE_THRESHOLD =
      12.0; // Lowered for better sensitivity

  // Keywords with phonetic variations for multilingual support
  static const List<String> KEYWORDS = [
    // English
    'help', 'please', 'emergency', 'danger',

    // SOS variations (often transcribed as "sauce", "so so", "sos")
    'sos', 'sauce', 'so so', 'soss',

    // Malay - "tolong" variations (might be heard as "to long", "too long", "toh long")
    'tolong', 'to long', 'too long', 'toh long', 'tulun',

    // Chinese pinyin variations
    'qiujiu', 'chew chew', 'chiu chiu', 'jiu jiu', // 救救 (save/help)
    'jiuming', 'chew ming', 'jiu ming', // 救命 (save life)
    'bangwo', 'bang wo', 'bung wo', // 帮我 (help me)
  ];
  static const int CAPTURE_WINDOW_SECONDS = 8;
  static const int MAX_IMU_READINGS = 10;
  static const Duration IMU_SAMPLE_INTERVAL = Duration(milliseconds: 800);

  // Callbacks for UI updates
  Function(String)? onTriggerDetectedCallback;
  Function()? onStartAnalyzing; // Show "Analyzing..." screen
  Function(bool, String, String)?
  onAnalysisResult; // (isIncident, description, transcript)
  Function(Map<String, dynamic>)?
  onNavigateToLodge; // Navigate to lodge screen with pre-filled data
  Function(List<IMUReading>, String)? onCaptureWindowData; // For debug overlay

  // Debug streams
  final StreamController<double> _magnitudeDebugController =
      StreamController<double>.broadcast();
  final StreamController<String> _transcriptDebugController =
      StreamController<String>.broadcast();

  Stream<double> get magnitudeDebugStream => _magnitudeDebugController.stream;
  Stream<String> get transcriptDebugStream => _transcriptDebugController.stream;

  bool get isRunning => _isRunning;

  /// Get diagnostic information
  String getDiagnostics() {
    return '''
    Safety Trigger Diagnostics:
    - Service Running: $_isRunning
    - Capture Window Active: $_isCaptureWindowActive
    - Current User ID: $_currentUserId
    - IMU Threshold: $IMU_MAGNITUDE_THRESHOLD
    - Location Service Initialized: true
    ''';
  }

  /// Initialize the service
  Future<void> initialize() async {
    // Check for custom API key from secure storage first (AES-256-GCM encrypted)
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
    );

    String? customApiKey = await secureStorage.read(key: 'gemini_api_key');

    // Migration: Check SharedPreferences if not in secure storage
    if (customApiKey == null) {
      final prefs = await SharedPreferences.getInstance();
      customApiKey = prefs.getString('gemini_api_key');

      if (customApiKey != null && customApiKey.isNotEmpty) {
        // Migrate to secure storage
        await secureStorage.write(key: 'gemini_api_key', value: customApiKey);
        await prefs.remove('gemini_api_key');
        debugPrint('[SafetyTrigger] 🔄 Migrated API key to secure storage');
      }
    }

    // Use custom key if available, otherwise fallback to default
    final apiKey = customApiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '';

    _geminiService = GeminiAnalysisService(apiKey: apiKey);
    debugPrint(
      '[SafetyTrigger] Initialized with ${customApiKey != null ? 'custom (🔐 encrypted)' : 'default'} Gemini API key',
    );
  }

  /// Set current user ID for location updates
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    debugPrint('[SafetyTrigger] Set current user ID: $userId');
  }

  String _preferredLanguage = 'en'; // Default to English

  /// Detect system language from phone settings
  /// Returns the first available non-English locale, or 'en' if only English is available
  Future<String> _detectSystemLanguage() async {
    final locales = await _microphoneService.getAvailableLocales();

    // Get the first available locale (system default)
    if (locales.isEmpty) {
      debugPrint('[SafetyTrigger] No locales available, defaulting to English');
      return 'en';
    }

    debugPrint(
      '[SafetyTrigger] 🔍 Scanning ${locales.length} available locales',
    );

    // Priority 1: Check for Malay (if phone is in Malay, use it)
    final hasMalay = locales.any((locale) => locale.localeId.startsWith('ms'));
    if (hasMalay) {
      debugPrint(
        '[SafetyTrigger] ✅ Malay (ms) locale detected - using Malay mode',
      );
      return 'ms';
    }

    // Priority 2: Check for Chinese (Traditional or Simplified)
    final hasChinese = locales.any(
      (locale) =>
          locale.localeId.startsWith('zh') || locale.localeId.startsWith('cmn'),
    );
    if (hasChinese) {
      debugPrint(
        '[SafetyTrigger] ✅ Chinese (zh/cmn) locale detected - using Chinese mode',
      );
      return 'zh';
    }

    // Priority 3: Check for other non-English languages
    // This allows the system to adapt to ANY language the user has installed
    for (final locale in locales) {
      final localeId = locale.localeId.toLowerCase();
      if (!localeId.startsWith('en')) {
        debugPrint(
          '[SafetyTrigger] ✅ Found non-English locale: ${locale.localeId}',
        );
        // For other languages, fall back to English mode with phonetic matching
        debugPrint(
          '[SafetyTrigger] 💡 Using English mode with custom keywords for: ${locale.localeId}',
        );
        return 'en'; // Use English for phonetic matching + custom keywords
      }
    }

    // Default to English
    debugPrint('[SafetyTrigger] ✅ Using English mode (default)');
    return 'en';
  }

  /// Set preferred detection language ('en', 'zh', 'ms', or 'auto')
  Future<void> setPreferredLanguage(String language) async {
    if (_preferredLanguage == language) {
      debugPrint('[SafetyTrigger] Language unchanged, skipping update');
      return;
    }

    // Handle 'auto' mode - detect phone's system language
    if (language == 'auto') {
      debugPrint('[SafetyTrigger] 🤖 Auto-Detect mode activated');
      final detectedLanguage = await _detectSystemLanguage();
      debugPrint(
        '[SafetyTrigger] 📱 Detected system language: $detectedLanguage',
      );
      language = detectedLanguage;
    }

    // Check if the requested language is available
    final isAvailable = await _microphoneService.isLanguageAvailable(language);

    if (!isAvailable && language != 'en') {
      debugPrint(
        '[SafetyTrigger] ⚠️  $language is not available on this device',
      );
      debugPrint('[SafetyTrigger] 🔄 Falling back to English mode');

      final languageName = language == 'ms' ? 'Malay' : 'Chinese (Traditional)';
      debugPrint('[SafetyTrigger] 💡 To use $languageName mode:');
      if (language == 'ms') {
        debugPrint(
          '[SafetyTrigger] 💡 Change your phone language to Bahasa Melayu',
        );
      } else {
        debugPrint('[SafetyTrigger] 💡 Add Chinese language to your phone');
      }

      // Fallback to English
      language = 'en';
    }

    _preferredLanguage = language;
    final languageName = language == 'en'
        ? 'English'
        : language == 'ms'
        ? 'Malay'
        : language == 'zh'
        ? 'Chinese (Traditional)'
        : 'Auto-Detect';
    debugPrint('[SafetyTrigger] Set preferred language: $languageName');

    // If system is running, restart keyword detection with new language
    if (_isRunning) {
      debugPrint(
        '[SafetyTrigger] System is running, restarting keyword detection with new language...',
      );
      await _microphoneService.stopKeywordDetection();
      await Future.delayed(const Duration(milliseconds: 300));
      await _microphoneService.startKeywordDetection(
        preferredLanguage: language,
      );
      debugPrint(
        '[SafetyTrigger] ✅ Keyword detection restarted with $languageName',
      );
    }
  }

  /// Start the safety trigger system
  Future<void> start() async {
    if (_isRunning) {
      debugPrint('[SafetyTrigger] Already running');
      return;
    }

    debugPrint('[SafetyTrigger] Starting safety trigger system');

    // Handle 'auto' mode at startup
    String languageToUse = _preferredLanguage;
    if (_preferredLanguage == 'auto') {
      debugPrint('[SafetyTrigger] 🤖 Auto-Detect mode at startup');
      languageToUse = await _detectSystemLanguage();
      debugPrint('[SafetyTrigger] 📱 Using detected language: $languageToUse');
    }

    // Verify language availability before starting
    final isAvailable = await _microphoneService.isLanguageAvailable(
      languageToUse,
    );
    if (!isAvailable && languageToUse != 'en') {
      debugPrint(
        '[SafetyTrigger] ⚠️  $languageToUse not available, falling back to English',
      );
      languageToUse = 'en';
    }

    _isRunning = true;

    // Start centralized sensor services
    _imuCentre.startIMUUpdates();

    // Subscribe to IMU magnitude stream for trigger detection
    _magnitudeSubscription = _imuCentre.magnitudeStream.listen(
      _checkIMUTrigger,
    );

    // Start keyword detection
    await _startKeywordDetection();

    // Start location updates if user is signed in
    if (_currentUserId != null) {
      await _locationService.startLocationUpdates(_currentUserId!);
    }

    debugPrint('[SafetyTrigger] System started successfully');
  }

  /// Stop the safety trigger system
  Future<void> stop() async {
    if (!_isRunning) return;

    debugPrint('[SafetyTrigger] Stopping safety trigger system');
    _isRunning = false;
    _isCaptureWindowActive = false;

    // Cancel all subscriptions
    await _accelSubscription?.cancel();
    await _gyroSubscription?.cancel();
    await _magnitudeSubscription?.cancel();

    // Stop sensors
    _imuCentre.stopIMUUpdates();
    await _stopKeywordDetection();

    // Stop location updates
    _locationService.stopLocationUpdates();

    // Cancel capture timer
    _captureTimer?.cancel();

    // Clear data
    _imuReadings.clear();
    _audioFilePath = null;
    _triggerSource = '';

    debugPrint('[SafetyTrigger] System stopped');
  }

  /// Cancel the current 8-second capture window
  Future<void> cancelCapture() async {
    if (!_isCaptureWindowActive) {
      debugPrint('[SafetyTrigger] No active capture to cancel');
      return;
    }

    debugPrint('[SafetyTrigger] ❌ Cancelling capture window');

    // Cancel the capture timer
    _captureTimer?.cancel();
    _captureTimer = null;

    // Stop audio recording if active
    if (_audioFilePath != null) {
      await _microphoneService.stopRecording();
      debugPrint('[SafetyTrigger] Audio recording stopped');
    }

    // Resume speech-to-text listening
    await _microphoneService.resumeListening();
    debugPrint('[SafetyTrigger] Speech recognition resumed');

    // Clear captured data
    _imuReadings.clear();
    _audioFilePath = null;
    _triggerSource = '';

    // Mark capture as inactive
    _isCaptureWindowActive = false;

    debugPrint(
      '[SafetyTrigger] ✅ Capture cancelled, system ready for next trigger',
    );
  }

  /// Check if IMU magnitude exceeds threshold
  void _checkIMUTrigger(double magnitude) {
    // Always send to debug stream
    _magnitudeDebugController.add(magnitude);

    if (!_isRunning || _isCaptureWindowActive) return;

    // Debug: Log magnitude occasionally
    if (magnitude > 5.0) {
      debugPrint(
        '[SafetyTrigger] IMU magnitude: ${magnitude.toStringAsFixed(2)}',
      );
    }

    if (magnitude > IMU_MAGNITUDE_THRESHOLD) {
      debugPrint(
        '[SafetyTrigger] 🚨 IMU TRIGGER DETECTED! Magnitude: ${magnitude.toStringAsFixed(2)}',
      );
      onTriggerDetected('IMU - Magnitude: ${magnitude.toStringAsFixed(2)}');
    }
  }

  /// Start keyword detection from microphone
  Future<void> _startKeywordDetection() async {
    debugPrint('[SafetyTrigger] Starting keyword detection');

    // Cancel existing subscriptions
    await _transcriptSubscription?.cancel();
    await _keywordSubscription?.cancel();

    // Initialize speech-to-text
    await _microphoneService.initializeSpeechToText();

    // Resolve 'auto' to actual language
    String languageToUse = _preferredLanguage;
    if (_preferredLanguage == 'auto') {
      languageToUse = await _detectSystemLanguage();
      debugPrint('[SafetyTrigger] 🤖 Auto mode resolved to: $languageToUse');
    }

    // Start keyword detection with user's preferred language
    await _microphoneService.startKeywordDetection(
      preferredLanguage: languageToUse,
    );

    // Listen for transcripts (for debug)
    _transcriptSubscription = _microphoneService.transcriptStream.listen((
      transcript,
    ) {
      _transcriptDebugController.add(transcript);
    });

    // Listen for keyword detections
    _keywordSubscription = _microphoneService.keywordStream.listen((keyword) {
      debugPrint(
        '[SafetyTrigger] 🔔 Keyword stream fired: $keyword, isRunning=$_isRunning, isCaptureActive=$_isCaptureWindowActive',
      );

      if (!_isCaptureWindowActive) {
        debugPrint('[SafetyTrigger] 🚨 KEYWORD TRIGGER DETECTED: $keyword');
        onTriggerDetected('Keyword: $keyword');
      } else {
        debugPrint(
          '[SafetyTrigger] ⚠️  Keyword ignored - capture window already active',
        );
      }
    });

    debugPrint('[SafetyTrigger] ✅ Keyword detection subscriptions set up');
  }

  /// Stop keyword detection
  Future<void> _stopKeywordDetection() async {
    debugPrint('[SafetyTrigger] Stopping keyword detection');
    await _keywordSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    await _microphoneService.stopKeywordDetection();
  }

  /// Handle trigger detection
  void onTriggerDetected(String source) async {
    if (_isCaptureWindowActive) return;

    _isCaptureWindowActive = true;
    _triggerSource = source;
    _imuReadings.clear();

    debugPrint(
      '[SafetyTrigger] Trigger detected: $source. Starting 8-second capture window',
    );

    debugPrint(
      '[SafetyTrigger] 🔔 About to call onTriggerDetectedCallback: ${onTriggerDetectedCallback != null}',
    );
    onTriggerDetectedCallback?.call(source);
    debugPrint('[SafetyTrigger] ✅ onTriggerDetectedCallback called');

    // Start 8-second capture window (will record audio, not transcript)
    await _startCaptureWindow();
  }

  /// Start the 8-second data capture window
  Future<void> _startCaptureWindow() async {
    debugPrint('[SafetyTrigger] 📊 Starting 8-second data collection');

    // PAUSE speech-to-text and start audio recording for Gemini analysis
    debugPrint(
      '[SafetyTrigger] Pausing speech recognition, starting audio recording',
    );
    await _microphoneService.pauseListening();
    _audioFilePath = await _startAudioRecording();
    debugPrint('[SafetyTrigger] Audio recording started: $_audioFilePath');

    // Show initial message on overlay
    onCaptureWindowData?.call(_imuReadings, 'Recording audio for analysis...');

    // Collect IMU readings every 0.8 seconds for 8 seconds
    int readingCount = 0;
    _captureTimer = Timer.periodic(IMU_SAMPLE_INTERVAL, (timer) async {
      if (readingCount >= MAX_IMU_READINGS) {
        timer.cancel();
        await _finishCaptureWindow();
        return;
      }

      // Collect current IMU reading
      _collectIMUReading();
      readingCount++;

      debugPrint(
        '[SafetyTrigger] Collected IMU reading $readingCount/$MAX_IMU_READINGS',
      );

      // Update overlay with progress
      onCaptureWindowData?.call(
        _imuReadings,
        'Recording audio... ($readingCount/$MAX_IMU_READINGS)',
      );
    });
  }

  /// Collect a single IMU reading with timestamp
  void _collectIMUReading() {
    // Subscribe temporarily to get current values
    AccelerometerEvent? accelEvent;
    GyroscopeEvent? gyroEvent;

    final accelSub = _imuCentre.accelerometerStream.listen((event) {
      accelEvent = event;
    });

    final gyroSub = _imuCentre.gyroscopeStream.listen((event) {
      gyroEvent = event;
    });

    // Wait a moment for data
    Future.delayed(const Duration(milliseconds: 100), () {
      accelSub.cancel();
      gyroSub.cancel();

      if (accelEvent != null && gyroEvent != null) {
        final reading = IMUReading(
          timestamp: DateFormat('HHmmss').format(DateTime.now()),
          accelX: accelEvent!.x,
          accelY: accelEvent!.y,
          accelZ: accelEvent!.z,
          gyroX: gyroEvent!.x,
          gyroY: gyroEvent!.y,
          gyroZ: gyroEvent!.z,
        );

        _imuReadings.add(reading);
      }
    });
  }

  /// Start audio recording for Gemini analysis
  Future<String> _startAudioRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/safety_audio_$timestamp.m4a';

    // Start recording audio for Gemini analysis
    await _microphoneService.startRecording(filePath);
    debugPrint('[SafetyTrigger] 🎙️ Audio recording started: $filePath');

    return filePath;
  }

  /// Finish the capture window and analyze data
  Future<void> _finishCaptureWindow() async {
    debugPrint('[SafetyTrigger] Finishing capture window');

    // Stop audio recording
    if (_audioFilePath != null) {
      await _microphoneService.stopRecording();
      debugPrint('[SafetyTrigger] Audio recording stopped: $_audioFilePath');
    }

    // Resume speech-to-text listening
    await _microphoneService.resumeListening();
    debugPrint('[SafetyTrigger] Speech recognition resumed');

    // Get pre-trigger context (what was said BEFORE the keyword)
    final preTriggerContext = _microphoneService.getPreTriggerContext();
    debugPrint('[SafetyTrigger] 📜 Pre-trigger context: "$preTriggerContext"');

    // Use ONLY the pre-trigger context for Gemini (audio file will provide the rest)
    // No need for placeholder text since Gemini will transcribe the audio
    final transcriptForGemini = preTriggerContext;
    debugPrint(
      '[SafetyTrigger] 📝 Sending pre-trigger context to Gemini: "$transcriptForGemini"',
    );

    // Clear the buffer for next trigger
    _microphoneService.clearPreTriggerContext();

    // Update debug overlay (show placeholder for UI)
    const displayMessage = 'Recording audio for Gemini analysis...';
    onCaptureWindowData?.call(_imuReadings, displayMessage);

    // Show "Analyzing..." screen
    onStartAnalyzing?.call();

    // Calculate peak IMU values for Gemini
    final peakAccel = _calculatePeakAccel();
    final peakGyro = _calculatePeakGyro();

    // Send to Gemini for analysis (with audio and pre-trigger context)
    debugPrint('[SafetyTrigger] Sending data to Gemini for analysis');
    debugPrint(
      '[SafetyTrigger] Audio file: ${_audioFilePath ?? "Not recorded"}',
    );
    final result = await _geminiService.analyzeIncident(
      accelX: peakAccel.x,
      accelY: peakAccel.y,
      accelZ: peakAccel.z,
      gyroX: peakGyro.x,
      gyroY: peakGyro.y,
      gyroZ: peakGyro.z,
      initialTriggers: _triggerSource,
      transcript:
          transcriptForGemini, // Send only pre-trigger context (audio has the rest)
      audioFilePath: _audioFilePath, // Pass audio file to Gemini
    );

    if (result != null) {
      final isIncident = result['isIncident'] as bool;
      final description = result['description'] as String? ?? '';
      final geminiTranscript = result['transcript'] as String? ?? '';
      debugPrint(
        '[SafetyTrigger] Gemini verdict: ${isIncident ? "TRUE POSITIVE" : "FALSE POSITIVE"}',
      );
      debugPrint('[SafetyTrigger] Gemini transcript: $geminiTranscript');

      // Show result screen with Gemini's transcript
      onAnalysisResult?.call(isIncident, description, geminiTranscript);

      if (isIncident) {
        // Wait a bit, then navigate to lodge screen with pre-filled data
        await Future.delayed(const Duration(seconds: 3));
        await _navigateToLodgeScreen(result, geminiTranscript);
      } else {
        // For false positive: restart monitoring after 10 seconds
        // (User can still see the screen and click OK button)
        debugPrint(
          '[SafetyTrigger] False positive - will restart monitoring in 10 seconds',
        );
        Future.delayed(const Duration(seconds: 10), () {
          _isCaptureWindowActive = false;
          debugPrint(
            '[SafetyTrigger] Monitoring restarted after false positive',
          );
        });
      }
    } else {
      debugPrint('[SafetyTrigger] Gemini analysis failed');
      _isCaptureWindowActive = false;
    }
  }

  /// Start capturing transcript updates during the 8-second window
  // REMOVED: _startTranscriptCapture()
  // Now using audio recording instead of live transcript during capture window
  // Gemini will transcribe the recorded audio file

  // REMOVED: _getAudioTranscript()
  // No longer needed - we send only pre-trigger context to Gemini
  // Gemini will transcribe the audio file and combine it with pre-trigger text

  /// Calculate peak acceleration values
  ({double x, double y, double z}) _calculatePeakAccel() {
    if (_imuReadings.isEmpty) return (x: 0.0, y: 0.0, z: 0.0);

    double maxX = _imuReadings
        .map((r) => r.accelX.abs())
        .reduce((a, b) => a > b ? a : b);
    double maxY = _imuReadings
        .map((r) => r.accelY.abs())
        .reduce((a, b) => a > b ? a : b);
    double maxZ = _imuReadings
        .map((r) => r.accelZ.abs())
        .reduce((a, b) => a > b ? a : b);

    return (x: maxX, y: maxY, z: maxZ);
  }

  /// Calculate peak gyroscope values
  ({double x, double y, double z}) _calculatePeakGyro() {
    if (_imuReadings.isEmpty) return (x: 0.0, y: 0.0, z: 0.0);

    double maxX = _imuReadings
        .map((r) => r.gyroX.abs())
        .reduce((a, b) => a > b ? a : b);
    double maxY = _imuReadings
        .map((r) => r.gyroY.abs())
        .reduce((a, b) => a > b ? a : b);
    double maxZ = _imuReadings
        .map((r) => r.gyroZ.abs())
        .reduce((a, b) => a > b ? a : b);

    return (x: maxX, y: maxY, z: maxZ);
  }

  /// Navigate to lodge screen with pre-filled incident data
  Future<void> _navigateToLodgeScreen(
    Map<String, dynamic> geminiResult,
    String transcript,
  ) async {
    debugPrint(
      '[SafetyTrigger] Navigating to lodge screen with pre-filled data',
    );

    try {
      // Get current location
      final location = await _locationService.getCurrentLocation();

      // Extract title and description from Gemini result
      final title = geminiResult['title'] as String? ?? 'AI-Detected Incident';
      final description =
          geminiResult['description'] as String? ??
          'AI-detected incident: $_triggerSource';

      // Combine title and description with separator (format: "Title\n---\nDescription")
      final combinedDescription = '$title\n---\n$description';

      // Prepare data for lodge screen
      final lodgeData = {
        'incidentType': 'threat',
        'description': combinedDescription,
        'mediaID': _audioFilePath ?? '',
        'isAIGenerated': true,
        'latitude': location?.latitude,
        'longitude': location?.longitude,
        'triggerSource': _triggerSource,
      };

      // Call the callback to navigate
      onNavigateToLodge?.call(lodgeData);

      _isCaptureWindowActive = false;
    } catch (e) {
      debugPrint('[SafetyTrigger] Error preparing lodge data: $e');
      _isCaptureWindowActive = false;
    }
  }

  void dispose() {
    stop();
    _keywordSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _imuCentre.dispose();
    _locationService.dispose();
    _magnitudeDebugController.close();
    _transcriptDebugController.close();
  }
}

/// Data class for IMU readings
class IMUReading {
  final String timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  IMUReading({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  @override
  String toString() {
    return '[$timestamp] Accel: (${accelX.toStringAsFixed(2)}, ${accelY.toStringAsFixed(2)}, ${accelZ.toStringAsFixed(2)}) '
        'Gyro: (${gyroX.toStringAsFixed(2)}, ${gyroY.toStringAsFixed(2)}, ${gyroZ.toStringAsFixed(2)})';
  }
}
