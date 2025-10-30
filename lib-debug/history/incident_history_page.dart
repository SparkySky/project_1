import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../app_theme.dart';
import '../models/clouddb_model.dart';
import '../repository/incident_repository.dart';
import '../repository/media_repository.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class IncidentHistoryPage extends StatefulWidget {
  const IncidentHistoryPage({super.key});

  @override
  _IncidentHistoryPageState createState() => _IncidentHistoryPageState();
}

class _IncidentHistoryPageState extends State<IncidentHistoryPage> {
  final _incidentRepository = IncidentRepository();
  final _mediaRepository = MediaRepository();

  List<incidents> _incidents = [];
  final Map<String, List<media>> _mediaMap = {}; // mediaID -> List of media
  final Map<String, String> _addressMap = {}; // iid -> address
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  @override
  void dispose() {
    _incidentRepository.closeZone();
    _mediaRepository.closeZone();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Get current user ID
      final user = await AGCAuth.instance.currentUser;
      if (user == null || user.uid == null) {
        debugPrint('[IncidentHistory] No user logged in');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      _currentUserId = user.uid;

      // Open CloudDB zones
      await _incidentRepository.openZone();
      await _mediaRepository.openZone();

      // Fetch incidents for current user
      final incidents = await _incidentRepository.getIncidentsByUserId(
        _currentUserId!,
      );

      // Sort by datetime (newest first)
      incidents.sort((a, b) => b.datetime.compareTo(a.datetime));

      debugPrint('[IncidentHistory] Found ${incidents.length} incidents');

      // Fetch media for each incident
      for (var incident in incidents) {
        if (incident.mediaID != null) {
          final mediaList = await _mediaRepository.getMediaByMediaId(
            incident.mediaID!,
          );
          if (mediaList.isNotEmpty) {
            _mediaMap[incident.mediaID!] = mediaList;
          }
        }

        // Fetch address for each incident
        await _reverseGeocodeLocation(
          incident.iid,
          incident.latitude,
          incident.longitude,
        );
      }

      if (mounted) {
        setState(() {
          _incidents = incidents;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[IncidentHistory] Error loading incidents: $e');
      debugPrint('[IncidentHistory] Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reverseGeocodeLocation(
    String iid,
    double latitude,
    double longitude,
  ) async {
    try {
      final apiKey = dotenv.env['HUAWEI_SITE_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[IncidentHistory] API key not found');
        return;
      }

      final url = Uri.parse(
        'https://siteapi.cloud.huawei.com/mapApi/v1/siteService/reverseGeocode',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'location': {'lat': latitude, 'lng': longitude},
          'language': 'en',
          'returnPoi': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['sites'] != null && data['sites'].isNotEmpty) {
          final site = data['sites'][0];
          String fullAddress = site['formatAddress'] ?? 'Unknown Location';

          if (mounted) {
            setState(() {
              _addressMap[iid] = fullAddress;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[IncidentHistory] Error reverse geocoding: $e');
    }
  }

  Future<void> _markAsResolved(incidents incident, int index) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Resolved'),
        content: const Text(
          'Mark this incident as resolved? This will update the incident status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Mark Resolved',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _incidentRepository.openZone();

      // Update the incident status
      final updatedIncident = incidents(
        iid: incident.iid,
        uid: incident.uid,
        latitude: incident.latitude,
        longitude: incident.longitude,
        datetime: incident.datetime,
        desc: incident.desc,
        incidentType: incident.incidentType,
        mediaID: incident.mediaID,
        isAIGenerated: incident.isAIGenerated,
        status: 'resolved', // Update status to 'resolved'
      );

      final success = await _incidentRepository.upsertIncident(updatedIncident);

      if (success && mounted) {
        setState(() {
          _incidents[index] = updatedIncident;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Incident marked as resolved'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[IncidentHistory] Error marking as resolved: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as resolved: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteIncident(incidents incident, int index) async {
    // Only allow deletion for 'active' or 'endedByBtn' status
    if (incident.status != 'active' && incident.status != 'endedByBtn') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete incidents with status "${_getStatusLabel(incident.status)}"',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Incident'),
        content: const Text(
          'Are you sure you want to delete this incident? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _incidentRepository.openZone();
      final success = await _incidentRepository.deleteIncidentById(
        incident.iid,
      );

      if (success && mounted) {
        setState(() {
          _incidents.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Incident deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[IncidentHistory] Error deleting incident: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete incident: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'endedByBtn':
        return 'Button Ended';
      case 'resolved':
        return 'Resolved';
      case 'fPositive':
        return 'False Positive';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.red;
      case 'endedByBtn':
        return Colors.green;
      case 'resolved':
        return Colors.green;
      case 'fPositive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return FutureBuilder<String?>(
      future: VideoThumbnail.thumbnailFile(
        video: videoUrl,
        imageFormat: ImageFormat.PNG,
        maxWidth: 200,
        quality: 75,
      ),
      builder: (context, snapshot) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail image or loading
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data != null)
                  Image.file(
                    File(snapshot.data!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[800]);
                    },
                  )
                else
                  Container(
                    color: Colors.grey[800],
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                // Play button overlay
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playAudio(String audioUrl) {
    final player = AudioPlayer();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.audiotrack, color: AppTheme.primaryOrange),
            const SizedBox(width: 8),
            const Text('Audio Player'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 48),
                  color: AppTheme.primaryOrange,
                  onPressed: () async {
                    await player.play(UrlSource(audioUrl));
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.pause, size: 48),
                  color: Colors.grey[700],
                  onPressed: () async {
                    await player.pause();
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.stop, size: 48),
                  color: Colors.red,
                  onPressed: () async {
                    await player.stop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await player.stop();
              await player.dispose();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) {
      player.stop();
      player.dispose();
    });
  }

  void _playVideo(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: _VideoPlayerDialog(videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppTheme.primaryOrange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading incident history...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _incidents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No incident history',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your reported incidents will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadIncidents,
              color: AppTheme.primaryOrange,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _incidents.length,
                itemBuilder: (context, index) {
                  return _buildIncidentCard(_incidents[index], index);
                },
              ),
            ),
    );
  }

  Widget _buildIncidentCard(incidents incident, int index) {
    final mediaList = incident.mediaID != null
        ? _mediaMap[incident.mediaID]
        : null;
    final address = _addressMap[incident.iid] ?? 'Loading address...';

    // Parse title and description
    String? title;
    String description = incident.desc;

    if (incident.desc.contains('\n---\n')) {
      final parts = incident.desc.split('\n---\n');
      if (parts.length >= 2) {
        title = parts[0].trim();
        description = parts.sublist(1).join('\n---\n').trim();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, badges, and delete button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exclamation/Info icon at top left
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: incident.incidentType == 'threat'
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    incident.incidentType == 'threat'
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 32,
                    color: incident.incidentType == 'threat'
                        ? Colors.red[700]
                        : Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 12),
                // Badges column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Threat/General and Status badges in same row
                      Row(
                        children: [
                          // Incident type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: incident.incidentType == 'threat'
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: incident.incidentType == 'threat'
                                    ? Colors.red.withOpacity(0.3)
                                    : Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              incident.incidentType == 'threat'
                                  ? 'Threat'
                                  : 'General',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: incident.incidentType == 'threat'
                                    ? Colors.red[700]
                                    : Colors.amber[800],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                incident.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(
                                  incident.status,
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(incident.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(incident.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Lodged on datetime
                      Text(
                        'Lodged on ${DateFormat('MMM dd, yyyy • hh:mm a').format(incident.datetime)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // AI badge (if applicable)
            if (incident.isAIGenerated) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.purple[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Generated',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Title (if present)
            if (title != null && title.isNotEmpty) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Media preview
            if (mediaList != null && mediaList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey[300], thickness: 1),
              const SizedBox(height: 12),
              // Display all media types in a grid
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaList.length,
                  itemBuilder: (context, i) {
                    final mediaItem = mediaList[i];
                    final isImage =
                        mediaItem.mediaType == 'jpg' ||
                        mediaItem.mediaType == 'jpeg' ||
                        mediaItem.mediaType == 'png';
                    final isVideo =
                        mediaItem.mediaType == 'mp4' ||
                        mediaItem.mediaType == 'mov' ||
                        mediaItem.mediaType == 'avi';
                    final isAudio =
                        mediaItem.mediaType == 'mp3' ||
                        mediaItem.mediaType == 'wav' ||
                        mediaItem.mediaType == 'm4a';

                    Widget mediaWidget;

                    if (isImage) {
                      // Image widget
                      mediaWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          mediaItem.mediaURI,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    } else if (isVideo) {
                      // Video thumbnail - actual frame from video with play button overlay
                      mediaWidget = _buildVideoThumbnail(mediaItem.mediaURI);
                    } else {
                      // Audio - black with orange play button
                      mediaWidget = Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: AppTheme.primaryOrange,
                            size: 50,
                          ),
                        ),
                      );
                    }

                    return GestureDetector(
                      onTap: () {
                        if (isImage) {
                          _viewImage(mediaItem.mediaURI);
                        } else if (isVideo) {
                          _playVideo(mediaItem.mediaURI);
                        } else if (isAudio) {
                          _playAudio(mediaItem.mediaURI);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: mediaWidget,
                      ),
                    );
                  },
                ),
              ),
            ],

            // Action Buttons (at the bottom, based on status)
            if (incident.status == 'active' ||
                incident.status == 'endedByBtn') ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300], thickness: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Delete button (for active and endedByBtn)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteIncident(incident, index),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (incident.status == 'active') const SizedBox(width: 8),
                  // Mark as Resolved button (only for active status)
                  if (incident.status == 'active')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _markAsResolved(incident, index),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Mark Resolved',
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Video Player Dialog Widget
class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerDialog({required this.videoUrl});

  @override
  _VideoPlayerDialogState createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryOrange),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        if (_isInitialized)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 48,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
