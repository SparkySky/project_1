import 'package:record/record.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class MicrophoneService {
  AudioRecorder? _audioRecorder;

  // This function ensures the recorder is ready right before we need it.
  void _ensureRecorderInitialized() {
    if (_audioRecorder == null) {
      debugPrint("[MicrophoneService] Initializing AudioRecorder for the first time.");
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
      debugPrint("[MicrophoneService] ERROR: Microphone permission not granted.");
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

  void dispose() {
    debugPrint("[MicrophoneService] Disposing AudioRecorder.");
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
