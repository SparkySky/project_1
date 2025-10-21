import 'dart:async';
import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart' as hwLocation;
import 'package:permission_handler/permission_handler.dart';

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
  final hwLocation.FusedLocationProviderClient _locationService =
  hwLocation.FusedLocationProviderClient();
  hwLocation.Location? _currentLocation;

  Set<Marker> _incidentMarkers = {};
  bool _isLoadingMarkers = true;
  bool _isLoadingLocation = true; // New flag for location loading
  CameraPosition? _initialPosition; // Will be set after fetching location

  // Default fallback position
  static const CameraPosition _kFallbackPosition = CameraPosition(
    target: LatLng(5.3644, 100.4660), // Centered on Bukit Mertajam
    zoom: 11.0, // Zoom out a bit to see both BM and Ipoh initially
  );

  @override
  void initState() {
    super.initState();
    HuaweiMapInitializer.initializeMap();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _requestLocationPermissionAndFetch();
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

  void _buildMarkersFromIncidents() async {
    print("--- Building markers from pre-geocoded incident data ---");
    if (!mounted) {
      print("Widget not mounted, exiting marker build.");
      return;
    }

    setState(() {
      _isLoadingMarkers = true;
      _incidentMarkers = {};
    });

    final Set<Marker> markers = {};
    for (final incident in widget.incidents) {
      final double? lat = incident['latitude'];
      final double? lon = incident['longitude'];
      final String title = incident['title'] ?? 'Incident';
      final String address = incident['location'] ?? 'Address not found'; // Use the pre-geocoded address

      if (lat != null && lon != null) {
        final LatLng position = LatLng(lat, lon);
        print("Creating marker for '$title' at: $position (Address: $address)");

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
              snippet: address, // Use the fetched address here
            ),
          ),
        );
      } else {
        print("  Skipping incident '${incident['title']}' due to missing coordinates.");
      }
    }

    print("--- Finished building markers. Found ${markers.length} markers. Updating state. ---");
    if (mounted) {
      setState(() {
        _incidentMarkers = markers;
        _isLoadingMarkers = false;
      });
    }
  }

  Future<void> _requestLocationPermissionAndFetch() async {
    print("=== Starting location fetch ===");

    var status = await Permission.locationWhenInUse.status;
    print("Initial permission status: $status");

    if (!status.isGranted) {
      print("Requesting location permission...");
      status = await Permission.locationWhenInUse.request();
      print("Permission request result: $status");

      if (!status.isGranted) {
        print("Location permission DENIED by user.");
        if (mounted) {
          setState(() {
            _initialPosition = _kFallbackPosition;
            _isLoadingLocation = false;
          });
        }
        return;
      }
    }

    print("Permission GRANTED. Proceeding to fetch location...");

    try {
      print("Attempting to get last known location...");
      hwLocation.Location? location = await _locationService.getLastLocation();

      if (location.latitude != null && location.longitude != null) {
        print("SUCCESS! Got last location: ${location.latitude}, ${location.longitude}");
        if (mounted) {
          setState(() {
            _currentLocation = location;
            _initialPosition = CameraPosition(
              target: LatLng(location.latitude!, location.longitude!),
              zoom: 15.0,
            );
            _isLoadingLocation = false;
          });
        }
      } else {
        print("Last location is null. Using fallback position.");
        if (mounted) {
          setState(() {
            _initialPosition = _kFallbackPosition;
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print("ERROR fetching location: $e");
      print("StackTrace: $stackTrace");
      if (mounted) {
        setState(() {
          _initialPosition = _kFallbackPosition;
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onMapCreated(HuaweiMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    print("Building MapWidget with ${_incidentMarkers.length} markers.");

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

    return Stack(
      children: [
        HuaweiMap(
          initialCameraPosition: _initialPosition!,
          onMapCreated: _onMapCreated,
          mapType: MapType.normal,
          compassEnabled: true,
          zoomControlsEnabled: true,

          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          buildingsEnabled: true,
          trafficEnabled: false,
          markers: _incidentMarkers,
        ),
        if (_isLoadingMarkers)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}