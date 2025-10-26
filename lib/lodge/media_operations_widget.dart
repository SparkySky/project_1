import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import '../app_theme.dart';
import 'media_viewer_page.dart';

class MediaOperationsWidget extends StatefulWidget {
  final List<File> mediaFiles;
  final Function(List<File>) onMediaFilesChanged;
  final File? initialAudioFile;
  final Color accentColor;

  const MediaOperationsWidget({
    super.key,
    required this.mediaFiles,
    required this.onMediaFilesChanged,
    this.initialAudioFile,
    this.accentColor = AppTheme.primaryOrange,
  });

  @override
  State<MediaOperationsWidget> createState() => _MediaOperationsWidgetState();
}

class _MediaOperationsWidgetState extends State<MediaOperationsWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  final Map<String, String> _videoThumbnails = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialAudioFile != null) {
      widget.mediaFiles.add(widget.initialAudioFile!);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  void _addMediaFile(File file) {
    setState(() {
      widget.mediaFiles.add(file);
    });
    widget.onMediaFilesChanged(widget.mediaFiles);
  }

  void _removeMedia(int index) {
    setState(() {
      final filePath = widget.mediaFiles[index].path;
      _videoThumbnails.remove(filePath);
      widget.mediaFiles.removeAt(index);
    });
    widget.onMediaFilesChanged(widget.mediaFiles);
  }

  bool _isVideo(String path) {
    String ext = path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv');
  }

  bool _isAudio(String path) {
    String ext = path.toLowerCase();
    return ext.endsWith('.mp3') ||
        ext.endsWith('.wav') ||
        ext.endsWith('.m4a') ||
        ext.endsWith('.aac');
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Add Media',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            _buildMediaOption(
              context,
              icon: Icons.photo_camera,
              title: 'Take Photo',
              subtitle: 'Capture with camera',
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (photo != null) {
                  _addMediaFile(File(photo.path));
                }
              },
            ),
            _buildMediaOption(
              context,
              icon: Icons.photo_library,
              title: 'Choose Photo',
              subtitle: 'Select from gallery',
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  _addMediaFile(File(image.path));
                }
              },
            ),
            _buildMediaOption(
              context,
              icon: Icons.videocam,
              title: 'Record Video',
              subtitle: 'Capture video',
              onTap: () async {
                Navigator.pop(context);
                final XFile? video = await _imagePicker.pickVideo(
                  source: ImageSource.camera,
                );
                if (video != null) {
                  final videoFile = File(video.path);
                  _addMediaFile(videoFile);
                  await _generateVideoThumbnail(videoFile);
                }
              },
            ),
            _buildMediaOption(
              context,
              icon: Icons.video_library,
              title: 'Choose Video',
              subtitle: 'Select from gallery',
              onTap: () async {
                Navigator.pop(context);
                final XFile? video = await _imagePicker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (video != null) {
                  final videoFile = File(video.path);
                  _addMediaFile(videoFile);
                  await _generateVideoThumbnail(videoFile);
                }
              },
            ),
            _buildMediaOption(
              context,
              icon: Icons.mic,
              title: 'Record Audio',
              subtitle: 'Voice recording',
              onTap: () {
                Navigator.pop(context);
                _showRecordingDialog();
              },
            ),
            _buildMediaOption(
              context,
              icon: Icons.audiotrack,
              title: 'Choose Audio',
              subtitle: 'Select audio file',
              onTap: () async {
                Navigator.pop(context);
                await _pickAudioFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 3000),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: widget.accentColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Future<void> _generateVideoThumbnail(File videoFile) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 200,
        quality: 75,
      );

      if (thumbnail != null && mounted) {
        setState(() {
          _videoThumbnails[videoFile.path] = thumbnail;
        });
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
    }
  }

  Future<void> _showRecordingDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Record Audio', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      size: 64,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isRecording
                        ? 'Recording in progress...'
                        : 'Ready to record',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording
                        ? 'Tap stop when finished'
                        : 'Tap start to begin',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                if (!_isRecording)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 3000),
                    curve: Curves.easeInOut,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_isRecording) {
                        await _stopRecording();
                        Navigator.pop(dialogContext);
                        if (_recordingPath != null) {
                          _addMediaFile(File(_recordingPath!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Audio recorded successfully!',
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      } else {
                        final started = await _startRecording();
                        if (started) {
                          setDialogState(() {
                            _isRecording = true;
                          });
                          setState(() {
                            _isRecording = true;
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording
                          ? Colors.red
                          : widget.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _isRecording ? 'Stop' : 'Start',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission denied'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return false;
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File audioFile = File(result.files.single.path!);
        _addMediaFile(audioFile);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Audio file added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error picking audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting audio: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _openMediaViewer(File file, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerPage(
          file: file,
          isVideo: _isVideo(file.path),
          isAudio: _isAudio(file.path),
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(File file, int index) {
    final isImage =
        file.path.toLowerCase().endsWith('.jpg') ||
        file.path.toLowerCase().endsWith('.jpeg') ||
        file.path.toLowerCase().endsWith('.png');
    final isVideo = _isVideo(file.path);
    final isAudio = _isAudio(file.path);
    final videoThumbnail = _videoThumbnails[file.path];

    return GestureDetector(
      onTap: () => _openMediaViewer(file, index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: isAudio ? Colors.black : Colors.grey[200],
                child: isImage
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : isVideo && videoThumbnail != null
                    ? Stack(
                        children: [
                          Image.file(
                            File(videoThumbnail),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      )
                    : isAudio
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.insert_drive_file,
                          color: widget.accentColor,
                          size: 40,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeMedia(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 3000),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.photo_library,
                color: widget.accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Media Evidence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: _pickMedia,
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 3000),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.mediaFiles.isEmpty)
        SizedBox(
          width: double.infinity,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.photo_camera, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No media added yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap + to add photos, videos or audio',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: widget.mediaFiles.length,
            itemBuilder: (context, index) {
              final file = widget.mediaFiles[index];
              return _buildMediaThumbnail(file, index);
            },
          ),
      ],
    );
  }
}
