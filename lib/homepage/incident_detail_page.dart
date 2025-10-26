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

class IncidentDetailPage extends StatefulWidget {
  final Map<String, dynamic> incident;

  const IncidentDetailPage({Key? key, required this.incident})
    : super(key: key);

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  HuaweiMapController? _mapController;
  String _address = 'Loading address...';
  List<media> _mediaList = [];
  bool _isLoadingMedia = true;

  // For real-time victim location (Threat incidents only)
  Timer? _locationUpdateTimer;
  Map<String, dynamic>? _victimLocation;
  bool _isLoadingVictimLocation = false;

  final UserRepository _userRepository = UserRepository();
  final MediaRepository _mediaRepository = MediaRepository();

  @override
  void initState() {
    super.initState();
    _loadIncidentDetails();

    // Start real-time location tracking for Threat incidents
    if (widget.incident['incidentType'] == 'threat') {
      _startVictimLocationTracking();
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
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
        debugPrint('Huawei Site API key not found');
        if (mounted) {
          setState(() {
            _address = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
          });
        }
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
        debugPrint('Reverse geocode failed: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _address = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
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
      debugPrint('[IncidentDetail] Fetching media for mediaID: $mediaID');

      if (mediaID == null || mediaID.isEmpty) {
        debugPrint('[IncidentDetail] No mediaID, skipping media fetch');
        if (mounted) {
          setState(() {
            _mediaList = [];
            _isLoadingMedia = false;
          });
        }
        return;
      }

      final mediaItems = await _mediaRepository.getMediaByMediaId(mediaID);
      debugPrint('[IncidentDetail] Fetched ${mediaItems.length} media items');

      // Sort by order field
      mediaItems.sort((a, b) => a.order.compareTo(b.order));

      if (mounted) {
        setState(() {
          _mediaList = mediaItems;
          _isLoadingMedia = false;
        });
        debugPrint('[IncidentDetail] Media list updated in state');
      }
    } catch (e) {
      debugPrint('[IncidentDetail] Error fetching media: $e');
      if (mounted) {
        setState(() {
          _mediaList = [];
          _isLoadingMedia = false;
        });
      }
    }
  }

  void _startVictimLocationTracking() {
    _fetchVictimLocation(); // Initial fetch

    // Update every 10 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchVictimLocation();
    });
  }

  Future<void> _fetchVictimLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingVictimLocation = true;
    });

    try {
      final String? uid = widget.incident['uid'];

      if (uid == null || uid.isEmpty) {
        setState(() {
          _isLoadingVictimLocation = false;
        });
        return;
      }

      final user = await _userRepository.getUserById(uid);

      if (mounted && user != null) {
        setState(() {
          _victimLocation = {
            'latitude': user.latitude,
            'longitude': user.longitude,
            'locUpdateTime': user.locUpdateTime,
          };
          _isLoadingVictimLocation = false;
        });

        // Update map marker if location exists
        if (user.latitude != null && user.longitude != null) {
          _updateVictimMarker(user.latitude!, user.longitude!);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingVictimLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching victim location: $e');
      if (mounted) {
        setState(() {
          _isLoadingVictimLocation = false;
        });
      }
    }
  }

  void _updateVictimMarker(double lat, double lon) {
    // This will trigger a rebuild with updated victim location
    setState(() {});
  }

  int _getLocationUpdateElapsedSeconds() {
    if (_victimLocation?['locUpdateTime'] == null) return 0;

    try {
      final DateTime updateTime = DateTime.parse(
        _victimLocation!['locUpdateTime'],
      );
      final Duration elapsed = DateTime.now().difference(updateTime);
      return elapsed.inSeconds;
    } catch (e) {
      return 0;
    }
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

  String _formatElapsedTime(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds ago';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      return '$minutes minute${minutes > 1 ? 's' : ''} ago';
    } else {
      final hours = (seconds / 3600).floor();
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    }
  }

  Widget _buildMediaItem(media mediaItem) {
    final mediaType = mediaItem.mediaType.toLowerCase();

    if (mediaType.contains('image') ||
        mediaType.contains('jpg') ||
        mediaType.contains('jpeg') ||
        mediaType.contains('png')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mediaItem.mediaURI,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image, size: 40)),
            );
          },
        ),
      );
    } else if (mediaType.contains('video') || mediaType.contains('mp4')) {
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
        mediaType.contains('wav')) {
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
          child: const Center(child: Icon(Icons.insert_drive_file, size: 50)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[IncidentDetail] Building detail page');
    debugPrint('[IncidentDetail] Incident data: ${widget.incident}');

    final isAIGenerated = widget.incident['isAIGenerated'] == 'true';
    final incidentType = widget.incident['incidentType'] ?? 'general';
    final isThreat = incidentType.toLowerCase() == 'threat';

    final double? incidentLat = widget.incident['latitude'];
    final double? incidentLon = widget.incident['longitude'];

    // Parse description (title and desc separated by \n---\n)
    String title = '';
    String description = '';
    final String rawDesc = widget.incident['desc'] ?? '';

    debugPrint('[IncidentDetail] Raw description: $rawDesc');

    if (rawDesc.contains('\n---\n')) {
      final parts = rawDesc.split('\n---\n');
      title = parts[0];
      description = parts.length > 1 ? parts[1] : '';
      debugPrint('[IncidentDetail] Parsed - Title: $title, Desc: $description');
    } else {
      description = rawDesc;
      title = description.length > 50
          ? '${description.substring(0, 50)}...'
          : description;
      debugPrint('[IncidentDetail] No separator - Using desc as title: $title');
    }

    debugPrint('[IncidentDetail] Media list count: ${_mediaList.length}');
    debugPrint('[IncidentDetail] Is loading media: $_isLoadingMedia');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isThreat ? Colors.red[700] : Colors.orange[700],
        elevation: 0,
        title: Text(
          isThreat ? 'Threat Incident' : 'General Incident',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                      markerId: MarkerId('incident'),
                      position: LatLng(incidentLat, incidentLon),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        isThreat
                            ? BitmapDescriptor.hueRed
                            : BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: InfoWindow(title: 'Incident Location'),
                    ),
                    // Victim location marker (for Threat incidents only)
                    if (isThreat &&
                        _victimLocation?['latitude'] != null &&
                        _victimLocation?['longitude'] != null)
                      Marker(
                        markerId: MarkerId('victim'),
                        position: LatLng(
                          _victimLocation!['latitude'],
                          _victimLocation!['longitude'],
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                        infoWindow: InfoWindow(
                          title: 'Victim Location',
                          snippet: _formatElapsedTime(
                            _getLocationUpdateElapsedSeconds(),
                          ),
                        ),
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

            // Real-time Victim Location (Threat only)
            if (isThreat) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          color: Colors.red[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Victim Real-Time Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingVictimLocation)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red[700],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_victimLocation != null &&
                        _victimLocation!['latitude'] != null &&
                        _victimLocation!['longitude'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lat: ${_victimLocation!['latitude']?.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          Text(
                            'Lon: ${_victimLocation!['longitude']?.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Updated: ${_formatElapsedTime(_getLocationUpdateElapsedSeconds())}',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Location unavailable',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
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

            const SizedBox(height: 24),

            // Emergency Contact Button (Threat only)
            if (isThreat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement emergency contact functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Emergency contact feature coming soon',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text(
                      'Contact Emergency Services',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

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
