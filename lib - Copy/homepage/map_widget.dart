import 'dart:async';
import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart' as hwLocation;
import 'package:url_launcher/url_launcher.dart';
import '../sensors/location_centre.dart';
import '../data/emergency_services.dart';

class MapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> incidents;
  final List<EmergencyService>? emergencyServices; // Emergency services markers
  final double? userLatitude;
  final double? userLongitude;
  final double radiusMeters;
  final Function(Function(Map<String, dynamic>))? onMapReady;
  final Function(Map<String, dynamic>)? onMarkerTap;

  const MapWidget({
    super.key,
    required this.incidents,
    this.emergencyServices,
    this.userLatitude,
    this.userLongitude,
    this.radiusMeters = 800.0,
    this.onMapReady,
    this.onMarkerTap,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget>
    with AutomaticKeepAliveClientMixin {
  HuaweiMapController? _mapController;
  final LocationServiceHelper _locationHelper = LocationServiceHelper();
  hwLocation.Location? _currentLocation;

  Set<Marker> _incidentMarkers = {};
  Set<Circle> _radiusCircles = {};
  Map<String, Map<String, dynamic>> _markerToIncident =
      {}; // Map marker ID to incident
  bool _isLoadingMarkers = true;
  bool _isLoadingLocation = true;
  bool _isDisposed = false;
  CameraPosition? _initialPosition;

  // For marker flashing animation
  String? _selectedMarkerId;
  Timer? _flashTimer;
  int _flashCount = 0;
  bool _isFlashVisible = true;

  @override
  bool get wantKeepAlive => true; // Keep map alive to prevent disposal issues

  static const CameraPosition _kFallbackPosition = CameraPosition(
    target: LatLng(5.3644, 100.4660),
    zoom: 9.0, // Zoomed out 2 levels from 11.0
  );

  @override
  void initState() {
    super.initState();
    HuaweiMapInitializer.initializeMap();
    // Delay initialization to avoid race conditions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _initializeMap();
      }
    });
  }

  Future<void> _initializeMap() async {
    if (_isDisposed) return;
    await _fetchInitialLocation();
    if (mounted && !_isDisposed) {
      _buildMarkersFromIncidents();
    }
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if incidents changed
    final bool incidentsChanged =
        widget.incidents.length != oldWidget.incidents.length ||
        widget.incidents != oldWidget.incidents;
    final bool servicesChanged =
        (widget.emergencyServices?.length ?? 0) !=
            (oldWidget.emergencyServices?.length ?? 0) ||
        widget.emergencyServices != oldWidget.emergencyServices;

    if (incidentsChanged || servicesChanged) {
      _buildMarkersFromIncidents();
    }

    if (widget.radiusMeters != oldWidget.radiusMeters ||
        widget.userLatitude != oldWidget.userLatitude ||
        widget.userLongitude != oldWidget.userLongitude) {
      _buildRadiusCircle();
    }
    // Removed camera adjustment - keep map static for performance
  }

  @override
  void activate() {
    super.activate();
    // Re-activate map when coming back from background
    _isDisposed = false;


    // Reinitialize map to prevent blank screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _initializeMap();
      }
    });
  }

  @override
  void deactivate() {
    // Mark as disposed early to prevent operations during navigation
    _isDisposed = true;

    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _flashTimer?.cancel(); // Cancel any active flash animation
    // Clear all map state before disposal
    _incidentMarkers.clear();
    _radiusCircles.clear();
    _markerToIncident.clear();
    _mapController = null;
    _currentLocation = null;
    super.dispose();
  }

  // Start flashing animation for selected marker
  void _startMarkerFlash(String markerId) {
    // Cancel any existing flash
    _flashTimer?.cancel();

    setState(() {
      _selectedMarkerId = markerId;
      _flashCount = 0;
      _isFlashVisible = true;
    });



    // Flash 2 times with longer intervals to reduce GPU load
    // 800ms per flash instead of 500ms
    _flashTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }

      setState(() {
        _isFlashVisible = !_isFlashVisible;
        if (!_isFlashVisible) {
          _flashCount++;
        }
      });

      // Stop after 2 complete flashes
      if (_flashCount >= 2) {
        timer.cancel();

        // Reset to normal
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_isDisposed) {
            setState(() {
              _selectedMarkerId = null;
              _isFlashVisible = true;
            });
            // Only rebuild markers once at the end
            _buildMarkersFromIncidents();
          }
        });
      } else {
        // Only rebuild markers during flash, not after completion
        _buildMarkersFromIncidents();
      }
    });
  }

  DateTime? _lastMarkerRebuild;
  bool _isFirstLoad = true;

  void _buildMarkersFromIncidents() {
    if (!mounted || _isDisposed) return;

    // Skip throttling on first load or when transitioning from empty to having incidents
    final bool hasIncidentsNow = widget.incidents.isNotEmpty;
    final bool hadNoMarkersBefore = _incidentMarkers.isEmpty;

    if (!_isFirstLoad && !(hadNoMarkersBefore && hasIncidentsNow)) {
      // Throttle marker rebuilds to prevent GPU overload
      final now = DateTime.now();
      if (_lastMarkerRebuild != null &&
          now.difference(_lastMarkerRebuild!).inMilliseconds < 300) {
        return;
      }
      _lastMarkerRebuild = now;
      // Show loading indicator on subsequent rebuilds
      setState(() => _isLoadingMarkers = true);
    } else {
      if (_isFirstLoad) {
        _isFirstLoad = false;

      } else {
      }
      // Show loading indicator on first load or when incidents just arrived
      setState(() => _isLoadingMarkers = true);
    }

    final Set<Marker> markers = {};
    final Map<String, Map<String, dynamic>> incidentMap = {};

    // Only log on first load or when debugging
    if (_isFirstLoad || widget.incidents.isEmpty) {
    }

    // Add incident markers
    for (final incident in widget.incidents) {
      final double? lat = incident['latitude'];
      final double? lon = incident['longitude'];
      final String title = incident['title'] ?? 'Incident';
      final String address = incident['location'] ?? 'Address not found';

      if (lat != null && lon != null) {
        final LatLng position = LatLng(lat, lon);
        final markerId = 'incident_${incident['id']}';

        double markerHue;

        // Check if this is the selected marker and apply flash effect
        final bool isSelected = _selectedMarkerId == markerId;
        final bool shouldFlash = isSelected && !_isFlashVisible;

        if (shouldFlash) {
          // Light orange for flash effect (30 = between red and yellow)
          markerHue = 30.0; // Light orange hue for flashing
        } else {
          // Normal color based on severity
          switch (incident['severity']?.toLowerCase()) {
            case 'high':
              markerHue = BitmapDescriptor.hueRed;
              break;
            case 'medium':
              markerHue = BitmapDescriptor.hueOrange;
              break;
            case 'low':
              markerHue = BitmapDescriptor.hueYellow;
              break;
            default:
              markerHue = BitmapDescriptor.hueAzure;
          }
        }

        markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(title: title, snippet: address),
            clickable: true,
            alpha: isSelected && !_isFlashVisible
                ? 0.5
                : 1.0, // Semi-transparent when flashing
            zIndex: isSelected ? 999.0 : 1.0, // Selected marker on top
            onClick: () {

              // Start flash animation for clicked marker
              _startMarkerFlash(markerId);
              // Notify parent widget
              if (widget.onMarkerTap != null) {
                widget.onMarkerTap!(incident);
              }
            },
          ),
        );

        // Store incident data for marker tap handling
        incidentMap[markerId] = incident;
      }
    }

    // Add emergency service markers
    if (widget.emergencyServices != null &&
        widget.emergencyServices!.isNotEmpty) {
      // Only log on first load
      if (_isFirstLoad || widget.emergencyServices!.isEmpty) {
      }

      int addedCount = 0;
      for (final service in widget.emergencyServices!) {
        try {
          // Remove verbose per-marker logging for performance

          final LatLng position = LatLng(service.lat, service.lng);
          final markerId =
              '${service.type}_${service.name}_${service.lat}_${service.lng}';

          double markerHue;
          switch (service.type) {
            case 'police':
              markerHue = BitmapDescriptor.hueBlue;
              break;
            case 'hospital':
              markerHue = BitmapDescriptor.hueGreen;
              break;
            case 'fire':
              markerHue = BitmapDescriptor.hueRose;
              break;
            default:
              markerHue = BitmapDescriptor.hueViolet;
          }

          final marker = Marker(
            markerId: MarkerId(markerId),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(
              title: '${service.emoji} ${service.name}',
              snippet: '📞 ${service.phone}',
            ),
            clickable: true,
            visible: true,
            alpha: 1.0,
            zIndex: 10.0, // Higher z-index to ensure visibility
            onClick: () {
              _showEmergencyServiceDialog(service);
            },
          );

          markers.add(marker);
          addedCount++;

          // Store service data as incident map (for compatibility)
          incidentMap[markerId] = {
            'id': markerId,
            'title': '${service.emoji} ${service.name}',
            'location': service.phone,
            'type': service.type,
            'latitude': service.lat,
            'longitude': service.lng,
            'phone': service.phone,
          };
        } catch (e) {

        }
      }
      // Only log summary on first load
      if (_isFirstLoad || addedCount == 0) {
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _incidentMarkers = markers;
        _markerToIncident = incidentMap;
        _isLoadingMarkers = false;
      });
    }
  }

  void _buildRadiusCircle() {
    if (!mounted || _isDisposed) return;

    final double? lat = widget.userLatitude;
    final double? lon = widget.userLongitude;

    if (lat == null || lon == null) return;

    setState(() {
      _radiusCircles = {
        Circle(
          circleId: CircleId('radius_circle'),
          center: LatLng(lat, lon),
          radius: widget.radiusMeters,
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue,
          strokeWidth: 2,
          clickable: false,
        ),
      };
    });
  }

  Future<void> _fetchInitialLocation() async {
    if (_isDisposed) return;
    hwLocation.Location? location = await _locationHelper.getCurrentLocation();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentLocation = location;
        if (location != null &&
            location.latitude != null &&
            location.longitude != null) {
          // Calculate offset to center user in visible area (between app bar and incident box)
          // At zoom 15.5 (zoomed out view), use minimal offset to keep user centered
          // Smaller offset needed for higher zoom levels
          final double latitudeOffset =
              0.0003; // Small offset for zoom 15.5 to keep user visible

          _initialPosition = CameraPosition(
            target: LatLng(
              location.latitude! -
                  latitudeOffset, // Shift camera south slightly
              location.longitude!,
            ),
            zoom: 15.5, // Zoomed out 2 levels from 17.5 to show wider area
          );
        } else {
          _initialPosition = _kFallbackPosition;

        }
        _isLoadingLocation = false;
      });
      _buildRadiusCircle();
    }
  }

  void _onMapCreated(HuaweiMapController controller) {
    if (_isDisposed) {
      return;
    }
    _mapController = controller;
    // Provide the focus callback to parent
    widget.onMapReady?.call(_focusOnIncident);
  }

  // Method to focus on a specific incident
  void _focusOnIncident(Map<String, dynamic> incident) {


    if (_isDisposed) {

      return;
    }

    if (_mapController == null) {

      return;
    }

    final double? lat = incident['latitude'];
    final double? lon = incident['longitude'];
    final String markerId = 'incident_${incident['id']}';



    if (lat != null && lon != null) {
      try {
        // Apply offset to position incident in visible area
        // At zoom 19.0 (high zoom), use very small offset to keep marker centered
        final double latitudeOffset = 0.0001; // Minimal offset for zoom 19.0
        final targetLat =
            lat + latitudeOffset; // Add to move camera north slightly
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              targetLat,
              lon,
            ), // Shift camera south to position marker in upper visible area
            19.0, // High zoom - balanced for performance and visibility
          ),
        );

        // Start flash animation after camera animation completes
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _startMarkerFlash(markerId);
          }
        });


      } catch (e) {

      }
    } else {

    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Safety check: Don't build if disposed
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    if (_isLoadingLocation || _initialPosition == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Fetching your location...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Calculate dynamic padding to push controls to top
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.7; // Map takes 70% of screen
    final bottomPadding =
        mapHeight * 0.5; // Use 50% of map height for bottom padding

    // Wrap HuaweiMap in error boundary
    return Stack(
      children: [
        if (!_isDisposed) // Only render map if not disposed
          RepaintBoundary(
            child: HuaweiMap(
              initialCameraPosition: _initialPosition!,
              onMapCreated: (controller) {
                if (!_isDisposed && mounted) {
                  try {
                    _onMapCreated(controller);
                  } catch (e) {

                  }
                }
              },
              mapType: MapType.normal,
              compassEnabled: true,
              zoomControlsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              buildingsEnabled: false, // Disable 3D buildings to reduce clutter
              trafficEnabled: false, // Disable traffic layer
              markers: _incidentMarkers,
              circles: _radiusCircles,
              padding: EdgeInsets.only(
                top: 0, // No top padding for controls at very top
                right: 16,
                bottom:
                    bottomPadding, // Dynamic bottom padding based on map height
                left: 16,
              ),
            ),
          ),
        // Loading indicator when markers are not placed yet
        // Show if: loading AND (no markers OR expecting incidents but have none)
        if (_isLoadingMarkers ||
            (_incidentMarkers.isEmpty && widget.incidents.isNotEmpty))
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading markers...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Show dialog for emergency service markers
  void _showEmergencyServiceDialog(EmergencyService service) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${service.emoji} ${service.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.phone,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.state,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _makePhoneCall(service.phone);
              },
              icon: const Icon(Icons.phone),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Make a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {

      }
    } catch (e) {

    }
  }
}
