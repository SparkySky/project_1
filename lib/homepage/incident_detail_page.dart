import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:project_1/repository/user_repository.dart';
import 'package:project_1/repository/media_repository.dart';
import 'package:project_1/models/clouddb_model.dart';
import 'package:project_1/lodge/network_media_viewer_page.dart';
import 'package:project_1/homepage/live_location_tracking_page.dart';

class IncidentDetailPage extends StatefulWidget {
  final Map<String, dynamic> incident;

  const IncidentDetailPage({super.key, required this.incident});

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  // ignore: unused_field
  HuaweiMapController? _mapController;
  String _address = 'Loading address...';
  List<media> _mediaList = [];
  bool _isLoadingMedia = true;

  final UserRepository _userRepository = UserRepository();
  final MediaRepository _mediaRepository = MediaRepository();

  @override
  void initState() {
    super.initState();
    _loadIncidentDetails();
  }

  @override
  void dispose() {
    _userRepository.closeZone();
    _mediaRepository.closeZone();
    super.dispose();
  }

  Future<void> _loadIncidentDetails() async {
    await _fetchAddress();
    await _fetchMedia();
  }

  Future<void> _fetchAddress() async {
    try {
      final double? lat = widget.incident['latitude'];
      final double? lon = widget.incident['longitude'];

      if (lat == null || lon == null) {
        if (mounted) {
          setState(() {
            _address = 'Invalid coordinates';
          });
        }
        return;
      }

      // Use Huawei Site API for reverse geocoding
      final apiKey = dotenv.env['HUAWEI_SITE_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        if (mounted) {
          setState(() {
            _address = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
          });
        }
        return;
      }

      // API key must be in URL query parameter, not Authorization header
      final url = Uri.parse(
        'https://siteapi.cloud.huawei.com/mapApi/v1/siteService/reverseGeocode?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'location': {'lat': lat, 'lng': lon},
          'language': 'en',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['sites'] != null && data['sites'].isNotEmpty) {
          final site = data['sites'][0];
          final address = site['formatAddress'];

          if (mounted) {
            setState(() {
              _address =
                  address ??
                  '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _address = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _address = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
          });
        }
      }
    } catch (e) {
      final double? lat = widget.incident['latitude'];
      final double? lon = widget.incident['longitude'];
      if (mounted) {
        setState(() {
          _address = lat != null && lon != null
              ? '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}'
              : 'Failed to load address';
        });
      }
    }
  }

  Future<void> _fetchMedia() async {
    try {
      final String? mediaID = widget.incident['mediaID'];

      if (mediaID == null || mediaID.isEmpty) {
        if (mounted) {
          setState(() {
            _mediaList = [];
            _isLoadingMedia = false;
          });
        }
        return;
      }

      final mediaItems = await _mediaRepository.getMediaByMediaId(mediaID);

      // Sort by order field
      mediaItems.sort((a, b) => a.order.compareTo(b.order));

      if (mounted) {
        setState(() {
          _mediaList = mediaItems;
          _isLoadingMedia = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mediaList = [];
          _isLoadingMedia = false;
        });
      }
    }
  }

  void _openLiveLocationTracking() {
    final String? uid = widget.incident['uid'];
    final String? incidentId = widget.incident['iid'];
    final double? lat = widget.incident['latitude'];
    final double? lon = widget.incident['longitude'];

    if (uid == null || incidentId == null || lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load live location - missing data'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveLocationTrackingPage(
          uid: uid,
          incidentId: incidentId,
          initialLat: lat,
          initialLng: lon,
        ),
      ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final DateTime dt = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _openMediaViewer(media mediaItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetworkMediaViewerPage(
          mediaUrl: mediaItem.mediaURI,
          mediaType: mediaItem.mediaType,
          mediaName: 'Media ${mediaItem.order}',
        ),
      ),
    );
  }

  Widget _buildMediaItem(media mediaItem) {
    final mediaType = mediaItem.mediaType.toLowerCase();

    return GestureDetector(
      onTap: () => _openMediaViewer(mediaItem),
      child: () {
        if (mediaType.contains('image') ||
            mediaType.contains('jpg') ||
            mediaType.contains('jpeg') ||
            mediaType.contains('png') ||
            mediaType.contains('webp') ||
            mediaType.contains('gif')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              mediaItem.mediaURI,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 40),
                  ),
                );
              },
            ),
          );
        } else if (mediaType.contains('video') ||
            mediaType.contains('mp4') ||
            mediaType.contains('mov') ||
            mediaType.contains('avi')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.black87,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    size: 60,
                    color: Colors.white,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Video',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (mediaType.contains('audio') ||
            mediaType.contains('mp3') ||
            mediaType.contains('m4a') ||
            mediaType.contains('wav') ||
            mediaType.contains('aac') ||
            mediaType.contains('ogg')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.blue[50],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.audiotrack, size: 50, color: Colors.blue),
                    SizedBox(height: 8),
                    Text('Audio', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            ),
          );
        } else {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insert_drive_file, size: 50),
                    SizedBox(height: 8),
                    Text('Unknown file', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        }
      }(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAIGenerated = widget.incident['isAIGenerated'] == 'true';
    final incidentType = widget.incident['incidentType'] ?? 'general';
    final isThreat = incidentType.toLowerCase() == 'threat';
    final status = widget.incident['status'] ?? '';
    final isActive = status.toLowerCase() == 'active';

    final double? incidentLat = widget.incident['latitude'];
    final double? incidentLon = widget.incident['longitude'];

    // Parse description (title and desc separated by \n---\n)
    String title = '';
    String description = '';
    final String rawDesc = widget.incident['desc'] ?? '';

    if (rawDesc.contains('\n---\n')) {
      final parts = rawDesc.split('\n---\n');
      title = parts[0];
      description = parts.length > 1 ? parts[1] : '';
    } else {
      description = rawDesc;
      title = description.length > 50
          ? '${description.substring(0, 50)}...'
          : description;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isThreat ? Colors.red[700] : Colors.orange[700],
        automaticallyImplyLeading: false,
        title: const Text('MYSafeZone'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Section
            if (incidentLat != null && incidentLon != null)
              SizedBox(
                height: 300,
                child: HuaweiMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(incidentLat, incidentLon),
                    zoom: 16.0,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: {
                    // Incident marker
                    Marker(
                      markerId: const MarkerId('incident'),
                      position: LatLng(incidentLat, incidentLon),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        isThreat
                            ? BitmapDescriptor.hueRed
                            : BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: const InfoWindow(title: 'Incident Location'),
                    ),
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
              ),

            // Address Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: isThreat ? Colors.red : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Incident Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isAIGenerated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 14,
                                color: Colors.purple[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI Generated',
                                style: TextStyle(
                                  color: Colors.purple[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Incident Type
                  _buildInfoRow(
                    Icons.warning_amber,
                    'Type',
                    incidentType.toUpperCase(),
                    isThreat ? Colors.red : Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  // Date & Time
                  _buildInfoRow(
                    Icons.access_time,
                    'Reported',
                    _formatDateTime(widget.incident['datetime']),
                    Colors.grey[700]!,
                  ),

                  const SizedBox(height: 12),

                  // Status
                  _buildInfoRow(
                    Icons.info_outline,
                    'Status',
                    (widget.incident['status'] ?? 'Unknown').toUpperCase(),
                    Colors.green,
                  ),

                  const SizedBox(height: 12),

                  // Incident ID
                  _buildInfoRow(
                    Icons.tag,
                    'Incident ID',
                    widget.incident['iid'] ?? 'N/A',
                    Colors.grey[600]!,
                  ),
                ],
              ),
            ),

            // View Live Location Button (Active incidents only)
            if (isActive) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openLiveLocationTracking,
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    label: const Text(
                      'View Live Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Media Evidence
            if (_mediaList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Media Evidence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: _mediaList.length,
                      itemBuilder: (context, index) {
                        return _buildMediaItem(_mediaList[index]);
                      },
                    ),
                  ],
                ),
              ),
            ] else if (_isLoadingMedia) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                color: Colors.white,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
