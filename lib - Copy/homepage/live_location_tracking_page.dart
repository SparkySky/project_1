import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:project_1/repository/user_repository.dart';

class LiveLocationTrackingPage extends StatefulWidget {
  final String uid; // Victim's UID
  final String incidentId;
  final double initialLat;
  final double initialLng;

  const LiveLocationTrackingPage({
    super.key,
    required this.uid,
    required this.incidentId,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LiveLocationTrackingPage> createState() =>
      _LiveLocationTrackingPageState();
}

class _LiveLocationTrackingPageState extends State<LiveLocationTrackingPage> {
  HuaweiMapController? _mapController;
  Timer? _locationUpdateTimer;

  double? _currentLat;
  double? _currentLng;
  DateTime? _lastUpdateTime;
  String _placeName = '';
  bool _isLoading = false;
  int _updateCount = 0;

  final UserRepository _userRepository = UserRepository();
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
    _startLiveTracking();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _userRepository.closeZone();
    super.dispose();
  }

  void _startLiveTracking() {
    // Fetch immediately
    _fetchVictimLocation();

    // Then fetch every 10 seconds
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchVictimLocation(),
    );
  }

  Future<void> _fetchVictimLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {


      await _userRepository.openZone();
      final user = await _userRepository.getUserById(widget.uid);

      if (mounted && user != null) {
        final newLat = user.latitude;
        final newLng = user.longitude;
        final updateTime = user.locUpdateTime;

        if (newLat != null && newLng != null) {
          setState(() {
            _currentLat = newLat;
            _currentLng = newLng;
            _lastUpdateTime = updateTime;
            _updateCount++;
          });

          // Update markers
          _updateMarkers(newLat, newLng);

          // Move camera to new location
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(LatLng(newLat, newLng)),
            );
          }
          // Fetch place name for new location
          _fetchPlaceName(newLat, newLng);
        } else {

        }
      } else {

      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {



      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Fetch place name using reverse geocoding (with fallback)
  Future<void> _fetchPlaceName(double lat, double lng) async {
    try {


      // Try geocoding package first (more reliable)
      try {

        final placemarks = await placemarkFromCoordinates(lat, lng);

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          // Build detailed address
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }

          final address = addressParts.join(', ');

          if (address.isNotEmpty && mounted) {
            setState(() {
              _placeName = address;
            });

            return; // Success! Exit early
          }
        }
      } catch (geocodingError) {

        // Continue to Huawei API fallback
      }

      // Fallback to Huawei Site API
      final apiKey = dotenv.env['HUAWEI_SITE_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {

        if (mounted) {
          setState(() {
            _placeName = ''; // Empty if unavailable
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
          'location': {'lat': lat, 'lng': lng},
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
              _placeName = address ?? '';
            });

          }
        } else {
          if (mounted) {
            setState(() {
              _placeName = '';
            });
          }
        }
      } else {

        if (mounted) {
          setState(() {
            _placeName = '';
          });
        }
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _placeName = '';
        });
      }
    }
  }

  void _updateMarkers(double lat, double lng) {
    setState(() {
      _markers.clear();

      // Add victim marker (current location) - RED
      _markers.add(
        Marker(
          markerId: const MarkerId('victim_current'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🚨 Victim Current Location',
            snippet: _getLastUpdateText(),
          ),
        ),
      );

      // Add incident origin marker (where it started) - ORANGE
      _markers.add(
        Marker(
          markerId: const MarkerId('incident_origin'),
          position: LatLng(widget.initialLat, widget.initialLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(
            title: '📍 Incident Origin',
            snippet: 'Where incident started',
          ),
        ),
      );
    });
  }

  String _getLastUpdateText() {
    if (_lastUpdateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[700],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 Live Location Tracking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Update #$_updateCount • ${_getLastUpdateText()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          // Full-screen map
          HuaweiMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLat ?? 0, _currentLng ?? 0),
              zoom: 16.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLat != null && _currentLng != null) {
                _updateMarkers(_currentLat!, _currentLng!);
              }
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),

          // Marker Legend (top)
          Positioned(
            left: 16,
            top: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Victim', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Origin', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Location info card (bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_pin_circle,
                            color: Colors.red[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Victim Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Only show address if available
                              if (_placeName.isNotEmpty) ...[
                                Text(
                                  _placeName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                _currentLat != null && _currentLng != null
                                    ? '${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}'
                                    : 'Waiting for location...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (_isLoading)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue[700],
                                ),
                              )
                            else
                              Icon(
                                Icons.update,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            const SizedBox(width: 4),
                            Text(
                              'Last update: ${_getLastUpdateText()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.sync,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-refresh: 10s',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
