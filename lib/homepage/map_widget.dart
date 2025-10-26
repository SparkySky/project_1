import 'dart:async';
import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart' as hwLocation;
import '../sensors/location_centre.dart';

class MapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> incidents;
  final double? userLatitude;
  final double? userLongitude;
  final double radiusMeters;
  final Function(Function(Map<String, dynamic>))? onMapReady;
  final Function(Map<String, dynamic>)? onMarkerTap;

  const MapWidget({
    super.key,
    required this.incidents,
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

  @override
  bool get wantKeepAlive => true; // Keep map alive to prevent disposal issues

  static const CameraPosition _kFallbackPosition = CameraPosition(
    target: LatLng(5.3644, 100.4660),
    zoom: 11.0,
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
    if (widget.incidents != oldWidget.incidents) {
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
  void deactivate() {
    // Mark as disposed early to prevent operations during navigation
    _isDisposed = true;
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Clear all map state before disposal
    _incidentMarkers.clear();
    _radiusCircles.clear();
    _markerToIncident.clear();
    _mapController = null;
    _currentLocation = null;
    super.dispose();
  }

  void _buildMarkersFromIncidents() {
    if (!mounted || _isDisposed) return;

    setState(() => _isLoadingMarkers = true);

    final Set<Marker> markers = {};
    final Map<String, Map<String, dynamic>> incidentMap = {};

    for (final incident in widget.incidents) {
      final double? lat = incident['latitude'];
      final double? lon = incident['longitude'];
      final String title = incident['title'] ?? 'Incident';
      final String address = incident['location'] ?? 'Address not found';

      if (lat != null && lon != null) {
        final LatLng position = LatLng(lat, lon);
        final markerId = 'incident_${incident['id']}';

        double markerHue;
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

        markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(title: title, snippet: address),
            clickable: true,
          ),
        );

        // Store incident data for marker tap handling
        incidentMap[markerId] = incident;
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

    print("=== Fetching initial location using LocationServiceHelper ===");
    hwLocation.Location? location = await _locationHelper.getCurrentLocation();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentLocation = location;
        if (location != null &&
            location.latitude != null &&
            location.longitude != null) {
          // Calculate offset to center user in visible area (between app bar and incident box)
          // At zoom 15, approximately 0.003 degrees latitude = ~330 meters
          // Offset camera target south so user marker appears in upper visible area
          final double latitudeOffset =
              0.0025; // Offset south to center user in visible area

          _initialPosition = CameraPosition(
            target: LatLng(
              location.latitude! - latitudeOffset, // Shift camera south
              location.longitude!,
            ),
            zoom: 15.0,
          );
          print(
            "SUCCESS! Got location: ${location.latitude}, ${location.longitude}",
          );
          print(
            "Camera centered at: ${location.latitude! - latitudeOffset} (offset applied for visible centering)",
          );
        } else {
          _initialPosition = _kFallbackPosition;
          print("Failed to get location, using fallback.");
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
    debugPrint('[MapWidget] 🎯 Focus on incident requested');

    if (_isDisposed) {
      debugPrint('[MapWidget] ❌ Cannot focus - widget disposed');
      return;
    }

    if (_mapController == null) {
      debugPrint('[MapWidget] ❌ Cannot focus - map controller is null');
      return;
    }

    final double? lat = incident['latitude'];
    final double? lon = incident['longitude'];

    debugPrint('[MapWidget] Incident location: lat=$lat, lon=$lon');

    if (lat != null && lon != null) {
      try {
        // Apply offset to position incident in visible area
        // Adding offset moves camera north, making marker appear lower on screen
        final double latitudeOffset =
            0.001; // Adjust to center marker between app bar and incident box
        final targetLat = lat + latitudeOffset; // Add to move camera north

        debugPrint(
          '[MapWidget] 📍 Animating camera to: lat=$targetLat, lon=$lon, zoom=17.0',
        );

        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              targetLat,
              lon,
            ), // Shift camera south to position marker in upper visible area
            17.0,
          ),
        );

        debugPrint('[MapWidget] ✅ Camera animation started');
      } catch (e) {
        debugPrint('[MapWidget] ❌ Error animating camera: $e');
      }
    } else {
      debugPrint('[MapWidget] ❌ Invalid coordinates: lat=$lat, lon=$lon');
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
                    debugPrint('[MapWidget] Error in onMapCreated: $e');
                  }
                }
              },
              mapType: MapType.normal,
              compassEnabled: true,
              zoomControlsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _incidentMarkers,
              circles: _radiusCircles,
              padding: EdgeInsets.only(
                top: 0, // No top padding for controls at very top
                right: 16,
                bottom:
                    bottomPadding, // Dynamic bottom padding based on map height
                left: 16,
              ),
              // Note: Marker click will be handled by tapping the marker info window
              // which triggers the onMarkerTap callback set in _buildMarkersFromIncidents
            ),
          ),
        if (_isLoadingMarkers)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
