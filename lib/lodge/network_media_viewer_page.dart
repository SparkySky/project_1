import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../app_theme.dart';

class NetworkMediaViewerPage extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String mediaName;

  const NetworkMediaViewerPage({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.mediaName = '',
  });

  @override
  _NetworkMediaViewerPageState createState() => _NetworkMediaViewerPageState();
}

class _NetworkMediaViewerPageState extends State<NetworkMediaViewerPage> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isInitializing = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDisposed = false;

  bool get _isVideo =>
      widget.mediaType.contains('video') || widget.mediaType.contains('mp4');
  bool get _isAudio =>
      widget.mediaType.contains('audio') ||
      widget.mediaType.contains('m4a') ||
      widget.mediaType.contains('wav') ||
      widget.mediaType.contains('mp3');
  bool get _isImage =>
      widget.mediaType.contains('image') ||
      widget.mediaType.contains('jpg') ||
      widget.mediaType.contains('jpeg') ||
      widget.mediaType.contains('png');

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    try {
      if (_isVideo) {
        await _initializeVideo();
      } else if (_isAudio) {
        await _initializeAudio();
      } else if (_isImage) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load media: $e';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaUrl),
      );

      _videoController!.addListener(() {
        if (_isDisposed || !mounted) return;

        if (_videoController!.value.hasError) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Video playback error: ${_videoController!.value.errorDescription}';
            _isInitializing = false;
          });
          return;
        }

        setState(() {
          _isPlaying = _videoController!.value.isPlaying;
          _position = _videoController!.value.position;
          _duration = _videoController!.value.duration;
        });
      });

      await _videoController!.initialize();

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
          _duration = _videoController!.value.duration;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to play this video format';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initializeAudio() async {
    try {
      _audioPlayer = AudioPlayer();

      _audioPlayer!.onDurationChanged.listen((duration) {
        if (mounted && !_isDisposed) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted && !_isDisposed) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer!.onPlayerComplete.listen((event) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('Error initializing audio: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to play this audio format';
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.dispose();
      _videoController = null;
    }

    if (_audioPlayer != null) {
      _audioPlayer!.stop();
      _audioPlayer!.dispose();
      _audioPlayer = null;
    }

    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_isAudio && _audioPlayer != null) {
      await _audioPlayer!.stop();
    }

    if (_isVideo && _videoController != null) {
      _videoController!.pause();
    }

    return true;
  }

  void _togglePlayPause() {
    if (_isDisposed) return;

    try {
      if (_isVideo && _videoController != null) {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      } else if (_isAudio && _audioPlayer != null) {
        if (_isPlaying) {
          _audioPlayer!.pause();
        } else {
          _audioPlayer!.play(UrlSource(widget.mediaUrl));
        }
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _seekTo(double value) {
    if (_isDisposed) return;

    try {
      final position = Duration(milliseconds: value.toInt());
      if (_isVideo && _videoController != null) {
        _videoController!.seekTo(position);
      } else if (_isAudio && _audioPlayer != null) {
        _audioPlayer!.seek(position);
      }
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        widget.mediaUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              color: AppTheme.primaryOrange,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (_isInitializing ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryOrange),
            SizedBox(height: 16),
            Text('Loading video...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black87,
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    _formatDuration(_position),
                    style: const TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: _position.inMilliseconds.toDouble().clamp(
                        0,
                        _duration.inMilliseconds.toDouble(),
                      ),
                      max: _duration.inMilliseconds.toDouble() > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1.0,
                      activeColor: AppTheme.primaryOrange,
                      inactiveColor: Colors.grey,
                      onChanged: _seekTo,
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      final newPosition =
                          _position - const Duration(seconds: 10);
                      if (newPosition.isNegative) {
                        _videoController!.seekTo(Duration.zero);
                      } else {
                        _videoController!.seekTo(newPosition);
                      }
                    },
                    icon: const Icon(
                      Icons.replay_10,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: AppTheme.primaryOrange,
                      size: 64,
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      final newPosition =
                          _position + const Duration(seconds: 10);
                      if (newPosition > _duration) {
                        _videoController!.seekTo(_duration);
                      } else {
                        _videoController!.seekTo(newPosition);
                      }
                    },
                    icon: const Icon(
                      Icons.forward_10,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.audiotrack : Icons.music_note,
              size: 100,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            widget.mediaName.isNotEmpty ? widget.mediaName : 'Audio Recording',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: _position.inMilliseconds.toDouble().clamp(
                    0,
                    _duration.inMilliseconds.toDouble(),
                  ),
                  max: _duration.inMilliseconds > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                  activeColor: AppTheme.primaryOrange,
                  inactiveColor: Colors.grey,
                  onChanged: _seekTo,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  final newPosition = _position - const Duration(seconds: 10);
                  if (!newPosition.isNegative) {
                    _audioPlayer!.seek(newPosition);
                  } else {
                    _audioPlayer!.seek(Duration.zero);
                  }
                },
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 30),
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: AppTheme.primaryOrange,
                  size: 72,
                ),
              ),
              const SizedBox(width: 30),
              IconButton(
                onPressed: () {
                  final newPosition = _position + const Duration(seconds: 10);
                  if (newPosition <= _duration) {
                    _audioPlayer!.seek(newPosition);
                  } else {
                    _audioPlayer!.seek(_duration);
                  }
                },
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.mediaName.isNotEmpty ? widget.mediaName : 'Media',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: _isVideo
              ? _buildVideoPlayer()
              : _isAudio
              ? _buildAudioPlayer()
              : _buildImageViewer(),
        ),
      ),
    );
  }
}

