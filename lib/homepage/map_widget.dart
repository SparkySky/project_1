import 'dart:async';
import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart' as hwLocation;
import '../sensors/location_centre.dart';

class MapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> incidents;

  const MapWidget({
    super.key,
    required this.incidents,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  HuaweiMapController? _mapController;
  final LocationServiceHelper _locationHelper = LocationServiceHelper();
  hwLocation.Location? _currentLocation;

  Set<Marker> _incidentMarkers = {};
  bool _isLoadingMarkers = true;
  bool _isLoadingLocation = true;
  CameraPosition? _initialPosition;

  static const CameraPosition _kFallbackPosition = CameraPosition(
    target: LatLng(5.3644, 100.4660),
    zoom: 11.0,
  );

  @override
  void initState() {
    super.initState();
    HuaweiMapInitializer.initializeMap();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _fetchInitialLocation();
    if (mounted) {
      _buildMarkersFromIncidents();
    }
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.incidents != oldWidget.incidents) {
      _buildMarkersFromIncidents();
    }
  }

  void _buildMarkersFromIncidents() {
    if (!mounted) return;

    setState(() => _isLoadingMarkers = true);

    final Set<Marker> markers = {};
    for (final incident in widget.incidents) {
      final double? lat = incident['latitude'];
      final double? lon = incident['longitude'];
      final String title = incident['title'] ?? 'Incident';
      final String address = incident['location'] ?? 'Address not found';

      if (lat != null && lon != null) {
        final LatLng position = LatLng(lat, lon);
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
            markerId: MarkerId('incident_${incident['id']}'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(
              title: title,
              snippet: address,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _incidentMarkers = markers;
        _isLoadingMarkers = false;
      });
    }
  }

  Future<void> _fetchInitialLocation() async {
    print("=== Fetching initial location using LocationServiceHelper ===");
    hwLocation.Location? location = await _locationHelper.getCurrentLocation();

    if (mounted) {
      setState(() {
        _currentLocation = location;
        if (location != null && location.latitude != null && location.longitude != null) {
          _initialPosition = CameraPosition(
            target: LatLng(location.latitude!, location.longitude!),
            zoom: 15.0,
          );
          print("SUCCESS! Got location: ${location.latitude}, ${location.longitude}");
        } else {
          _initialPosition = _kFallbackPosition;
          print("Failed to get location, using fallback.");
        }
        _isLoadingLocation = false;
      });
    }
  }

  void _onMapCreated(HuaweiMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching your location...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        HuaweiMap(
          initialCameraPosition: _initialPosition!,
          onMapCreated: _onMapCreated,
          mapType: MapType.normal,
          compassEnabled: true,
          zoomControlsEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: _incidentMarkers,
        ),
        if (_isLoadingMarkers)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
