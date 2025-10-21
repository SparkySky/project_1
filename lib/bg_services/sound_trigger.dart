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
//endregion

class SoundTriggerService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  Function(String keyword, String fullSentence)? _onKeywordDetected;
  final DebugState _debugState = DebugState();

  /// Initializes the speech-to-text service.
  Future<bool> initialize({
    Function(String keyword, String fullSentence)? onKeywordDetected,
  }) async {
    _onKeywordDetected = onKeywordDetected;
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
    if ((status == 'notListening' || status == 'done') && _isListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
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
    if (!_isInitialized || _speech.isListening) {
      if (!_isInitialized) {
        _debugState.updateSoundServiceStatus("Cannot listen: Not initialized");
      }
      return;
    }

    _isListening = true;
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      partialResults: true,
      onSoundLevelChange: (level) {
        _debugState.updateSoundLevel(level);
      },
    );
    _debugState.updateSoundServiceStatus("Listening...");
  }

  /// Stops listening.
  void stopListening() {
    _isListening = false; // This signals the INTENT to stop.
    if (_speech.isListening) {
      _speech.stop();
    }
    _debugState.updateSoundServiceStatus("Stopped");
  }

  /// Callback for speech recognition results.
  void _onSpeechResult(result) {
    final recognizedWords = result.recognizedWords.toLowerCase();
    _debugState.updateRecognizedWords(recognizedWords);

    if (result.finalResult && recognizedWords.isNotEmpty) {
      for (var keyword in EMERGENCY_KEYWORDS) {
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
        if (regex.hasMatch(recognizedWords)) {
          if (kDebugMode) {
            print(
                '[SoundTriggerService] Keyword "$keyword" detected in final sentence: "$recognizedWords"');
          }
          _debugState.updateKeywordDetected(keyword);
          _onKeywordDetected?.call(keyword, recognizedWords);

          // DO NOT stop here. Let the SensorsAnalysisService decide when to pause/resume.
          // The listener will automatically restart via the onStatus callback.
          return;
        }
      }
    }
  }

  bool get isListening => _isListening;

  void dispose() {
    stopListening();
  }
}
