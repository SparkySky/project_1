import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class MicrophoneCentre {
  static final MicrophoneCentre _instance = MicrophoneCentre._internal();
  factory MicrophoneCentre() => _instance;
  MicrophoneCentre._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  Future<bool> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/emergency_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        _recordingPath = filePath;
        return true;
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
    return false;
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
