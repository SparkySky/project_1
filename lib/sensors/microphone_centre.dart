import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class MicrophoneService {
  AudioRecorder? _audioRecorder;
  SpeechToText? _speechToText;

  // Keyword detection
  bool _isListening = false;
  bool _shouldKeepListening = false;
  String _preferredLanguage =
      'en'; // 'en' for English, 'zh' for Chinese (Traditional), 'ms' for Malay, 'smart' for Smart Mode

  Timer? _monitorTimer;
  StreamController<String>? _transcriptController;
  StreamController<String>? _keywordController;

  // Rolling buffer for pre-trigger context (stores last 10 seconds of transcripts)
  final List<String> _transcriptBuffer = [];
  static const int MAX_BUFFER_SIZE = 10; // Keep last 10 transcript chunks

  // Custom keywords loaded from SharedPreferences
  List<String> _customKeywords = [];

  // Keywords to detect - SUPER FLEXIBLE phonetic matching
  // English mode will transcribe everything phonetically, so we match those too
  static const List<String> KEYWORDS = [
    // English
    'help', 'please', 'emergency', 'danger',

    // SOS variations (often transcribed as "sauce", "so so", "sos")
    'sos', 'sauce', 'so so', 'soss', 's.o.s', 'essay',

    // Malay - "tolong" (help) and all phonetic variations
    'tolong', 'to long', 'too long', 'toh long', 'tulun', 'tollong',
    'two long', 'telong', 'tol long', 't long',

    // Malay - "bantu" (help/assist) and variations
    'bantu', 'ban too', 'ban tu', 'bahn too',

    // Malay - "selamatkan" (save) variations
    'selamatkan', 'sell a mat can', 'selah mat can', 'slam at can',

    // Malay - "bahaya" (danger) variations
    'bahaya', 'bah eye yah', 'ba ha ya', 'buh hi ya',

    // Mandarin/Cantonese 求救 (qiu jiu - "seek rescue")
    'qiujiu', 'qiu jiu', 'chew chew', 'chiu chiu', 'kau gau', 'cow gow',
    'q jiu', 'chew jew', 'kyoo jyoo',

    // Mandarin/Cantonese 救救 (jiu jiu - "save save")
    'jiujiu', 'jiu jiu', 'jew jew', 'choo choo', 'chu chu', 'gau gau',
    'gow gow', 'jyoo jyoo',

    // Mandarin 救命 (jiu ming - "save life")
    'jiuming', 'jiu ming', 'chew ming', 'jew ming', 'joe ming',
    'gau meng', 'gow ming',

    // Mandarin/Cantonese 帮我 (bang wo - "help me")
    'bangwo', 'bang wo', 'bung wo', 'bong wo', 'pang wo', 'bong ngo',
    'pong ngo', 'baan ngo',

    // Cantonese 帮忙 (bang mang - "help" / "assist")
    'bangmang', 'bang mang', 'bong mong', 'pong mong', 'baan mong',
    'bong maang', 'pong maang', 'baan maang',

    // Chinese actual characters (if API does transcribe them)
    '救命', '救', '帮我', '救救', '帮', '求救', '帮忙',
  ];

  // Map phonetic variations to canonical keywords for Gemini
  static const Map<String, String> KEYWORD_NORMALIZATION = {
    // SOS variations → "SOS"
    'sauce': 'SOS',
    'so so': 'SOS',
    'soss': 'SOS',
    's.o.s': 'SOS',
    'essay': 'SOS',
    'sos': 'SOS',

    // Malay tolong → "tolong"
    'to long': 'tolong',
    'too long': 'tolong',
    'toh long': 'tolong',
    'tulun': 'tolong',
    'tollong': 'tolong',
    'two long': 'tolong',
    'telong': 'tolong',
    'tol long': 'tolong',
    't long': 'tolong',

    // Malay bantu → "bantu"
    'ban too': 'bantu',
    'ban tu': 'bantu',
    'bahn too': 'bantu',

    // Malay selamatkan → "selamatkan"
    'sell a mat can': 'selamatkan',
    'selah mat can': 'selamatkan',
    'slam at can': 'selamatkan',

    // Malay bahaya → "bahaya"
    'bah eye yah': 'bahaya',
    'ba ha ya': 'bahaya',
    'buh hi ya': 'bahaya',

    // Mandarin/Cantonese 求救 (qiu jiu - "seek rescue") → "qiujiu"
    'qiu jiu': 'qiujiu',
    'chew chew': 'qiujiu',
    'chiu chiu': 'qiujiu',
    'kau gau': 'qiujiu',
    'cow gow': 'qiujiu',
    'q jiu': 'qiujiu',
    'chew jew': 'qiujiu',
    'kyoo jyoo': 'qiujiu',

    // Mandarin/Cantonese 救救 (jiu jiu - "save save") → "jiujiu"
    'jiu jiu': 'jiujiu',
    'jew jew': 'jiujiu',
    'choo choo': 'jiujiu',
    'chu chu': 'jiujiu',
    'gau gau': 'jiujiu',
    'gow gow': 'jiujiu',
    'jyoo jyoo': 'jiujiu',

    // Mandarin 救命 (jiu ming - "save life") → "jiuming"
    'jiu ming': 'jiuming',
    'chew ming': 'jiuming',
    'jew ming': 'jiuming',
    'joe ming': 'jiuming',
    'gau meng': 'jiuming',
    'gow ming': 'jiuming',

    // Mandarin/Cantonese 帮我 (bang wo - "help me") → "bangwo"
    'bang wo': 'bangwo',
    'bung wo': 'bangwo',
    'bong wo': 'bangwo',
    'pang wo': 'bangwo',
    'bong ngo': 'bangwo',
    'pong ngo': 'bangwo',
    'baan ngo': 'bangwo',

    // Cantonese 帮忙 (bang mang - "help"/"assist") → "bangmang"
    'bang mang': 'bangmang',
    'bong mong': 'bangmang',
    'pong mong': 'bangmang',
    'baan mong': 'bangmang',
    'bong maang': 'bangmang',
    'pong maang': 'bangmang',
    'baan maang': 'bangmang',

    // Chinese characters
    '救命': 'jiuming',
    '救': 'jiujiu',
    '帮我': 'bangwo',
    '救救': 'jiujiu',
    '帮': 'bangwo',
    '求救': 'qiujiu',
    '帮忙': 'bangmang',

    // English (keep as-is)
    'help': 'help',
    'please': 'please',
    'emergency': 'emergency',
    'danger': 'danger',

    // Malay (canonical)
    'tolong': 'tolong',
    'bantu': 'bantu',
    'selamatkan': 'selamatkan',
    'bahaya': 'bahaya',

    // Chinese (canonical)
    'qiujiu': 'qiujiu',
    'jiujiu': 'jiujiu',
    'jiuming': 'jiuming',
    'bangwo': 'bangwo',
    'bangmang': 'bangmang',
  };

  /// Normalize a detected keyword for Gemini (e.g., "sauce" → "SOS")
  static String normalizeKeyword(String keyword) {
    return KEYWORD_NORMALIZATION[keyword.toLowerCase()] ?? keyword;
  }

  /// Normalize entire transcript for Gemini (replace all phonetic variations)
  static String normalizeTranscript(String transcript) {
    String normalized = transcript.toLowerCase();

    // Replace each phonetic variation with its canonical form
    KEYWORD_NORMALIZATION.forEach((phonetic, canonical) {
      if (normalized.contains(phonetic)) {
        normalized = normalized.replaceAll(phonetic, canonical);
      }
    });

    return normalized;
  }

  Stream<String> get transcriptStream =>
      _transcriptController?.stream ?? const Stream.empty();
  Stream<String> get keywordStream =>
      _keywordController?.stream ?? const Stream.empty();

  // This function ensures the recorder is ready right before we need it.
  void _ensureRecorderInitialized() {
    if (_audioRecorder == null) {
      debugPrint(
        "[MicrophoneService] Initializing AudioRecorder for the first time.",
      );
      _audioRecorder = AudioRecorder();
    }
  }

  Future<bool> hasPermission() async {
    _ensureRecorderInitialized();
    debugPrint("[MicrophoneService] Checking for permission.");
    return await _audioRecorder!.hasPermission();
  }

  Future<void> startRecording(String filePath) async {
    _ensureRecorderInitialized();
    if (await _audioRecorder!.hasPermission()) {
      debugPrint("[MicrophoneService] Starting recording to path: $filePath");
      await _audioRecorder!.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: filePath,
      );
    } else {
      debugPrint(
        "[MicrophoneService] ERROR: Microphone permission not granted.",
      );
    }
  }

  Future<String?> stopRecording() async {
    debugPrint("[MicrophoneService] Attempting to stop recording.");
    if (await _audioRecorder?.isRecording() ?? false) {
      final path = await _audioRecorder!.stop();
      debugPrint("[MicrophoneService] Recording stopped. File saved at: $path");
      return path;
    }
    debugPrint("[MicrophoneService] No active recording to stop.");
    return null;
  }

  /// Initialize speech-to-text service
  Future<bool> initializeSpeechToText() async {
    _speechToText ??= SpeechToText();
    _transcriptController ??= StreamController<String>.broadcast();
    _keywordController ??= StreamController<String>.broadcast();

    final available = await _speechToText!.initialize();
    debugPrint("[MicrophoneService] Speech-to-text initialized: $available");
    return available;
  }

  /// Start continuous keyword detection
  /// Load custom keywords from SharedPreferences for the current language
  Future<void> _loadCustomKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    // Load from combined storage (all keywords are stored in 'en' now)
    _customKeywords = prefs.getStringList('custom_keywords_en') ?? [];
    debugPrint(
      '[MicrophoneService] 🎯 Loaded ${_customKeywords.length} custom keywords (all languages combined): $_customKeywords',
    );
  }

  Future<void> startKeywordDetection({String preferredLanguage = 'en'}) async {
    // Check if language has changed - if so, restart
    final languageChanged = _preferredLanguage != preferredLanguage;

    if (_shouldKeepListening && !languageChanged) {
      debugPrint(
        "[MicrophoneService] Already in listening mode with same language, skipping...",
      );
      return;
    }

    if (languageChanged && _shouldKeepListening) {
      debugPrint(
        "[MicrophoneService] Language changed from $_preferredLanguage to $preferredLanguage, restarting...",
      );
      await stopKeywordDetection(); // Stop existing session
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Wait for cleanup
    }

    if (_speechToText == null) {
      final initialized = await initializeSpeechToText();
      if (!initialized) {
        debugPrint("[MicrophoneService] Failed to initialize speech-to-text");
        return;
      }
    }

    _preferredLanguage = preferredLanguage;

    // Load custom keywords for this language
    await _loadCustomKeywords();
    final languageName = preferredLanguage == 'en'
        ? 'English'
        : preferredLanguage == 'ms'
        ? 'Malay (Bahasa Melayu)'
        : preferredLanguage == 'zh'
        ? 'Chinese (Traditional)'
        : 'Smart Mode (Auto-detect)';
    debugPrint(
      "[MicrophoneService] 🌍 Preferred language set to: $languageName",
    );

    if (preferredLanguage == 'smart') {
      debugPrint("[MicrophoneService] 🤖 SMART MODE ACTIVATED");
      debugPrint(
        "[MicrophoneService] 🔥 MULTI-ANALYSIS: Each phrase analyzed by 3 languages",
      );
      debugPrint(
        "[MicrophoneService] 🌍 Analysis: English → Malay → Mandarin (sequential)",
      );
      debugPrint("[MicrophoneService] 💡 Instant detection in any language!");
    }

    _shouldKeepListening = true;
    _startListening();
  }

  /// Internal method to start a listening session
  void _startListening() async {
    if (!_shouldKeepListening || _isListening) return;

    _isListening = true;
    debugPrint("[MicrophoneService] 🎤 Starting listening session");

    try {
      // Try to get available locales
      final locales = await _speechToText!.locales();
      String? selectedLocale;

      // Debug: Log all available locales
      if (locales.isNotEmpty) {
        final allLocales = locales.map((l) => l.localeId).toList();
        debugPrint(
          "[MicrophoneService] 📋 Total available locales: ${allLocales.length}",
        );
        debugPrint(
          "[MicrophoneService] 📋 All locales: ${allLocales.join(', ')}",
        );

        // Check for specific language availability
        final hasEnglish = allLocales.any((id) => id.startsWith('en'));
        final hasMalay = allLocales.any((id) => id.startsWith('ms'));
        final hasMandarin = allLocales.any(
          (id) => id.startsWith('zh') || id.startsWith('cmn'),
        );

        debugPrint("[MicrophoneService] ✓ English available: $hasEnglish");
        debugPrint("[MicrophoneService] ✓ Malay available: $hasMalay");
        debugPrint("[MicrophoneService] ✓ Mandarin available: $hasMandarin");
      }

      if (locales.isNotEmpty) {
        // Smart Mode: Always use English for initial listening (best phonetic coverage)
        // Then we'll re-analyze with other languages if needed
        String effectiveLanguage = _preferredLanguage == 'smart'
            ? 'en'
            : _preferredLanguage;

        if (effectiveLanguage == 'en') {
          // English mode: Best for phonetic matching across languages
          selectedLocale = locales
              .firstWhere(
                (locale) =>
                    locale.localeId == 'en-US' || locale.localeId == 'en_US',
                orElse: () => locales.firstWhere(
                  (locale) =>
                      locale.localeId == 'en-SG' || locale.localeId == 'en_SG',
                  orElse: () => locales.firstWhere(
                    (locale) => locale.localeId.startsWith('en'),
                    orElse: () => locales.first,
                  ),
                ),
              )
              .localeId;

          debugPrint(
            "[MicrophoneService] 🌍 ENGLISH MODE: Best for phonetic matching",
          );
          debugPrint("[MicrophoneService] 📋 Using locale: $selectedLocale");
          debugPrint(
            "[MicrophoneService] 💡 Detects: English (native) + Chinese (phonetic)",
          );
        } else if (effectiveLanguage == 'ms') {
          // Malay mode: Bahasa Melayu (Malaysia)
          try {
            final malayLocale = locales.firstWhere(
              (locale) =>
                  locale.localeId == 'ms-MY' ||
                  locale.localeId == 'ms_MY' ||
                  locale.localeId == 'ms-BN' ||
                  locale.localeId == 'ms_BN' ||
                  locale.localeId.startsWith('ms'),
            );
            selectedLocale = malayLocale.localeId;

            debugPrint("[MicrophoneService] 🌍 MALAY MODE: Bahasa Melayu");
            debugPrint("[MicrophoneService] 📋 Using locale: $selectedLocale");
            debugPrint(
              "[MicrophoneService] 💡 Detects: Malay (native) + English keywords",
            );
          } catch (e) {
            // Malay not available - use first available locale
            selectedLocale = locales.first.localeId;

            debugPrint(
              "[MicrophoneService] ⚠️ MALAY MODE: ms-MY locale NOT FOUND on device",
            );
            debugPrint(
              "[MicrophoneService] ⚠️ Falling back to: $selectedLocale",
            );
            debugPrint(
              "[MicrophoneService] 💡 NOTE: Android only shows language packs matching your system language",
            );
            debugPrint(
              "[MicrophoneService] 💡 To use Malay: Add 'Bahasa Melayu' to phone languages in Settings → System → Languages",
            );
            debugPrint(
              "[MicrophoneService] 📝 Current mode will still detect 'tolong' and other keywords phonetically",
            );
          }
        } else {
          // Mandarin mode: Traditional Chinese (Taiwan)
          selectedLocale = locales
              .firstWhere(
                (locale) =>
                    locale.localeId == 'zh-TW' ||
                    locale.localeId == 'zh_TW' ||
                    locale.localeId == 'cmn-Hant-TW' ||
                    locale.localeId == 'zh-CN' ||
                    locale.localeId == 'zh_CN' ||
                    locale.localeId == 'cmn-Hans-CN' ||
                    locale.localeId.startsWith('zh') ||
                    locale.localeId.startsWith('cmn'),
                orElse: () => locales.first,
              )
              .localeId;

          debugPrint(
            "[MicrophoneService] 🌍 MANDARIN MODE: Traditional Chinese (Taiwan)",
          );
          debugPrint("[MicrophoneService] 📋 Using locale: $selectedLocale");
          debugPrint(
            "[MicrophoneService] 💡 Detects: Mandarin (native) + English keywords",
          );
        }
      }

      // Start listening - this is NON-BLOCKING
      _speechToText!.listen(
        onResult: (result) {
          final transcript = result.recognizedWords.toLowerCase();
          final isFinal = result.finalResult;

          // Always send transcript, even if empty
          if (transcript.isNotEmpty) {
            debugPrint(
              "[MicrophoneService] 📝 RAW TRANSCRIPT: '$transcript' (${isFinal ? 'FINAL' : 'partial'})",
            );
            debugPrint(
              "[MicrophoneService] 🔍 Checking against ${KEYWORDS.length} keywords...",
            );
            _transcriptController?.add(transcript);

            // Only add FINAL results to rolling buffer (avoid duplicates from partial results)
            if (isFinal && transcript.isNotEmpty) {
              _transcriptBuffer.add(transcript);
              if (_transcriptBuffer.length > MAX_BUFFER_SIZE) {
                _transcriptBuffer.removeAt(0); // Remove oldest
              }
              debugPrint(
                "[MicrophoneService] 💾 Stored final phrase in buffer (${_transcriptBuffer.length}/$MAX_BUFFER_SIZE)",
              );
            }

            // Check for keywords with detailed logging
            bool keywordFound = _checkForKeywords(transcript);

            // Smart Mode: If no keyword found AND final result, note it
            // (Currently Android STT doesn't support re-analyzing audio files)
            if (!keywordFound && isFinal && _preferredLanguage == 'smart') {
              debugPrint(
                "[MicrophoneService] 🤖 Smart Mode: No keywords in English phonetic transcription",
              );
            }
          }
        },
        listenFor: const Duration(minutes: 5), // 5 minutes per session
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        // Use the selected English locale for phonetic transcription
        localeId: selectedLocale,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        onDevice:
            false, // Use cloud recognition for better multilingual support
        onSoundLevelChange: (level) {
          // Only log significant sound
          if (level > 5) {
            debugPrint(
              "[MicrophoneService] 🔊 Sound: ${level.toStringAsFixed(1)} dB",
            );
          }
        },
      );

      debugPrint("[MicrophoneService] ✅ Session started");

      // Start monitoring to detect when listening stops
      _startMonitoring();
    } catch (e) {
      debugPrint("[MicrophoneService] ❌ Error starting listener: $e");
      _isListening = false;

      // Retry after error
      if (_shouldKeepListening) {
        Future.delayed(const Duration(seconds: 2), () {
          _startListening();
        });
      }
    }
  }

  /// Monitor the listening state and restart if it stops
  void _startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_shouldKeepListening) {
        timer.cancel();
        return;
      }

      // Check if speech recognition has stopped
      final isActuallyListening = _speechToText?.isListening ?? false;

      if (!isActuallyListening && _isListening) {
        // Listener has stopped unexpectedly
        debugPrint("[MicrophoneService] 🔄 Listener stopped, restarting...");
        _isListening = false;

        // Small delay before restart
        Future.delayed(const Duration(milliseconds: 500), () {
          _startListening();
        });

        timer.cancel();
      }
    });
  }

  /// Stop keyword detection
  Future<void> stopKeywordDetection() async {
    debugPrint("[MicrophoneService] 🛑 Stopping keyword detection");
    _shouldKeepListening = false;
    _isListening = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;

    if (_speechToText?.isListening ?? false) {
      await _speechToText!.stop();
    }
  }

  /// Pause listening temporarily (for audio recording)
  Future<void> pauseListening() async {
    debugPrint("[MicrophoneService] ⏸️ Pausing listening");
    _shouldKeepListening = false;
    _isListening = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;

    if (_speechToText?.isListening ?? false) {
      await _speechToText!.stop();
    }
  }

  /// Resume listening after pause
  Future<void> resumeListening() async {
    debugPrint("[MicrophoneService] ▶️ Resuming listening");
    _shouldKeepListening = true;
    _startListening();
  }

  /// Get pre-trigger context (last 10 transcripts before keyword detected)
  String getPreTriggerContext() {
    if (_transcriptBuffer.isEmpty) {
      return '';
    }
    // Join all buffered transcripts with periods
    return _transcriptBuffer.join('. ');
  }

  /// Clear the transcript buffer (call after trigger is handled)
  void clearPreTriggerContext() {
    _transcriptBuffer.clear();
    debugPrint("[MicrophoneService] 🗑️ Pre-trigger context cleared");
  }

  /// Get current transcript
  String getCurrentTranscript() {
    return _speechToText?.lastRecognizedWords ?? '';
  }

  void dispose() {
    debugPrint("[MicrophoneService] Disposing AudioRecorder and SpeechToText.");
    _shouldKeepListening = false;
    _isListening = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;

    _audioRecorder?.dispose();
    _audioRecorder = null;

    _speechToText?.stop();
    _speechToText = null;

    _transcriptController?.close();
    _keywordController?.close();
    _transcriptController = null;
    _keywordController = null;
  }

  /// Get all available locales from the device
  Future<List<dynamic>> getAvailableLocales() async {
    if (_speechToText == null) {
      await initializeSpeechToText();
    }

    if (_speechToText == null || !_speechToText!.isAvailable) {
      return [];
    }

    return await _speechToText!.locales();
  }

  /// Check if a language is available on the device
  Future<bool> isLanguageAvailable(String languageCode) async {
    if (_speechToText == null) {
      await initializeSpeechToText();
    }

    if (_speechToText == null || !_speechToText!.isAvailable) {
      return false;
    }

    final locales = await _speechToText!.locales();

    switch (languageCode) {
      case 'en':
        return locales.any((locale) => locale.localeId.startsWith('en'));
      case 'ms':
        return locales.any((locale) => locale.localeId.startsWith('ms'));
      case 'zh':
        return locales.any(
          (locale) =>
              locale.localeId.startsWith('zh') ||
              locale.localeId.startsWith('cmn'),
        );
      default:
        return false;
    }
  }

  /// Check transcript for keywords (both default and custom)
  bool _checkForKeywords(String transcript) {
    // Check default keywords first
    for (final keyword in KEYWORDS) {
      if (transcript.contains(keyword)) {
        // Normalize the keyword before sending (e.g., "sauce" → "SOS")
        final normalizedKeyword = normalizeKeyword(keyword);
        debugPrint(
          "[MicrophoneService] ✅✅✅ KEYWORD MATCH: '$keyword' → normalized to '$normalizedKeyword'",
        );
        debugPrint(
          "[MicrophoneService] 📤 Sending normalized keyword: '$normalizedKeyword'",
        );
        debugPrint(
          "[MicrophoneService] 📜 Pre-trigger context: ${getPreTriggerContext()}",
        );
        _keywordController?.add(normalizedKeyword);
        return true;
      }
    }

    // Check custom keywords
    for (final keyword in _customKeywords) {
      if (transcript.contains(keyword)) {
        debugPrint("[MicrophoneService] 🎯✅ CUSTOM KEYWORD MATCH: '$keyword'");
        debugPrint("[MicrophoneService] 📤 Sending custom keyword: '$keyword'");
        debugPrint(
          "[MicrophoneService] 📜 Pre-trigger context: ${getPreTriggerContext()}",
        );
        _keywordController?.add(keyword.toUpperCase());
        return true;
      }
    }

    debugPrint("[MicrophoneService] ❌ No keyword match in: '$transcript'");
    // Log individual words for debugging
    final words = transcript.split(' ');
    debugPrint("[MicrophoneService] 📋 Individual words: ${words.join(', ')}");
    return false;
  }
}
