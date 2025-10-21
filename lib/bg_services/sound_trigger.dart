import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../util/debug_state.dart';

//region Adjustable Thresholds and Configuration
/// TODO: Fine-tune these values based on testing.

/// A list of emergency keywords to detect.
const List<String> EMERGENCY_KEYWORDS = [
  'help',
  'sos',
  'fire',
  'save me',
  'danger',
  'emergency'
];

/// Confidence threshold for keyword recognition (0.0 to 1.0).
const double KEYWORD_CONFIDENCE_THRESHOLD = 0.5;

/// Minimum sound level (dB) to start analyzing for keywords.
/// This helps in saving battery by not processing silence.
const double MIN_SOUND_LEVEL_DB = -40.0;

/// TODO: Integrate a model for this.
/// Threshold for detecting distress sounds (e.g., screams, glass breaking).
/// This would be a value from your custom sound classification model.
const double DISTRESS_SOUND_THRESHOLD = 0.85;

//endregion

class SoundTriggerService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  Function(String)? _onKeywordDetected;
  Function(String)? _onDistressSoundDetected;
  final DebugState _debugState = DebugState();

  /// Initializes the speech-to-text service.
  Future<bool> initialize({
    Function(String)? onKeywordDetected,
    Function(String)? onDistressSoundDetected,
  }) async {
    _onKeywordDetected = onKeywordDetected;
    _onDistressSoundDetected = onDistressSoundDetected;
    _debugState.updateSoundServiceStatus("Initializing...");

    _isInitialized = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );

    if (_isInitialized) {
      _debugState.updateSoundServiceStatus("Initialized & Ready");
    } else {
      _debugState.updateSoundServiceStatus("Initialization Failed");
    }
    return _isInitialized;
  }

  void _onStatus(String status) {
    _debugState.updateSoundServiceStatus("Status: $status");
    if (kDebugMode) {
      print('[SoundTriggerService] Status: $status');
    }

    // If the status is 'notListening' or 'done', and we still want to be listening,
    // it means the recognizer stopped (e.g., due to a timeout/no-match).
    // Let's restart it after a short delay.
    if ((status == 'notListening' || status == 'done') && _isListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // Double-check if we should still be listening before restarting.
        if (_isListening) {
          startListening();
        }
      });
    }
  }

  void _onError(stt.SpeechRecognitionError error) {
    _debugState.updateSoundServiceStatus("Error: ${error.errorMsg}");
    if (kDebugMode) {
      print('[SoundTriggerService] Error: $error');
    }
  }

  /// Starts listening for keywords and sounds.
  void startListening() {
    // Prevent starting a new listen session if one is already active.
    if (!_isInitialized || _speech.isListening) {
      if (!_isInitialized) {
        _debugState.updateSoundServiceStatus("Cannot listen: Not initialized");
      }
      return;
    }

    _isListening = true; // Set our intended state
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30), // Listen in shorter, looping bursts.
      partialResults: true,
      onSoundLevelChange: (level) {
        _debugState.updateSoundLevel(level);
      },
    );
    _debugState.updateSoundServiceStatus("Listening...");
  }

  /// Stops listening.
  void stopListening() {
    _isListening = false; // Set our intended state
    _speech.stop();
    _debugState.updateSoundServiceStatus("Stopped");
  }

  /// Callback for speech recognition results.
  void _onSpeechResult(result) {
    final recognizedWords = result.recognizedWords.toLowerCase();
    _debugState.updateRecognizedWords(recognizedWords);

    if (recognizedWords.isNotEmpty) {
      for (var keyword in EMERGENCY_KEYWORDS) {
        // Use a regular expression to match whole words.
        // This prevents "helping" from matching "help".
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
        if (regex.hasMatch(recognizedWords)) {
          if (kDebugMode) {
            print(
                '[SoundTriggerService] Keyword detected in partial result: $keyword');
          }
          _debugState.updateKeywordDetected(keyword);
          _onKeywordDetected?.call(keyword);

          // Stop listening immediately after a detection to prevent multiple triggers.
          // The auto-restart logic in _onStatus will then create a clean new session.
          stopListening();
          return; // Exit after first keyword match.
        }
      }
    }
  }

  bool get isListening => _isListening;

  void dispose() {
    stopListening();
  }
}
