import 'dart:async'; // Import async
import 'package:flutter/material.dart';
import 'package:huawei_location/huawei_location.dart' as hwLocation;
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart';
import 'package:permission_handler/permission_handler.dart';

class MapWidget extends StatefulWidget {
  // Accept incidents
  final List<Map<String, dynamic>> incidents;

  const MapWidget({
    super.key,
    required this.incidents, // Make incidents required
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  HuaweiMapController? _mapController;
  final hwLocation.FusedLocationProviderClient _locationService =
  hwLocation.FusedLocationProviderClient();
  hwLocation.Location? _currentLocation;

  // Geocoder and Markers State ---
  final hwLocation.GeocoderService _geocoderService = hwLocation.GeocoderService();
  Set<Marker> _incidentMarkers = {};
  bool _isLoadingMarkers = true; // Flag for loading state

  // Default camera position (e.g., center of Bukit Mertajam)
  // Adjusted initial position to be closer to the dummy data locations
  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(5.3644, 100.4660), // Bukit Mertajam Area
    zoom: 13.0, // Zoom in a bit more
  );

  @override
  void initState() {
    super.initState();
    HuaweiMapInitializer.initializeMap();
    _requestLocationPermissionAndFetch();
    _geocodeAndBuildMarkers();
  }

  // Handle incident list changes - Dynamic mapping
  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the incident list changes, rebuild the markers
    if (widget.incidents != oldWidget.incidents) {
      _geocodeAndBuildMarkers();
    }
  }

  // Geocode incidents and create markers ---
  Future<void> _geocodeAndBuildMarkers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMarkers = true;
      _incidentMarkers = {}; // Clear previous markers
    });

    final Set<Marker> markers = {};
    int markerIndex = 0;

    // --- FIX: Construct the locale using the NAMED 'language' parameter ---
    final hwLocation.Locale geocodingLocale = hwLocation.Locale(language: 'en'); // Use named parameter 'language'
    // ----------------------------------------------------------------------

    for (final incident in widget.incidents) {
      final String address = incident['location'] ?? '';
      final String title = incident['title'] ?? 'Incident';
      final String snippet = incident['timestamp'] ?? '';

      if (address.isNotEmpty) {
        try {
          final hwLocation.GetFromLocationNameRequest request =
          hwLocation.GetFromLocationNameRequest(locationName: address, maxResults: 1);

          final List<hwLocation.HWLocation> locations =
          await _geocoderService.getFromLocationName(request, geocodingLocale); // Pass the correctly constructed Locale

          if (locations.isNotEmpty) {
            final hwLocation.HWLocation hwLoc = locations.first;
            if (hwLoc.latitude != null && hwLoc.longitude != null) {
              final LatLng position = LatLng(hwLoc.latitude!, hwLoc.longitude!);

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
                  markerId: MarkerId('incident_${incident['id']}_$markerIndex'),
                  position: position,
                  icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                  infoWindow: InfoWindow(
                    title: title,
                    snippet: snippet,
                  ),
                ),
              );
              markerIndex++;
            } else {
              print('Geocoding result for "$address" missing coordinates.');
            }
          } else {
            print('Geocoding failed for address: $address (No results found)');
          }
        } catch (e) {
          print('Error during geocoding for "$address": $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _incidentMarkers = markers;
        _isLoadingMarkers = false;
      });
    }
  }

  Future<void> _requestLocationPermissionAndFetch() async {
    // 1. Check/Request Permission
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        // Handle permission denied - maybe show a message
        print("Location permission denied.");
        return;
      }
    }

    // 2. Fetch Location (if permission granted)
    try {
      // Ensure location service is enabled
      bool serviceEnabled = await _locationService.checkLocationSettings(
        hwLocation.LocationSettingsRequest(requests: [
          hwLocation.LocationRequest()..priority = hwLocation.LocationRequest.PRIORITY_HIGH_ACCURACY,
        ]),
      ).then((value) => value.hmsLocationUsable);

      if (!serviceEnabled) {
        print("Location services are disabled.");
        // Optionally prompt user to enable location services
        return;
      }

      hwLocation.Location? location = await _locationService.getLastLocation(); // Use prefix
      if (location != null && mounted) {
        setState(() {
          _currentLocation = location;
        });
        _animateToLocation(location);
      } else {
        // If last location is null, request a single update
        int? callbackId; // Store the ID to remove the callback later
        callbackId = await _locationService.requestLocationUpdatesCb(
          hwLocation.LocationRequest()..numUpdates = 1, // Request just one update
          hwLocation.LocationCallback( // Use prefix
            onLocationResult: (locationResult) {
              if (locationResult.lastLocation != null && mounted) {
                setState(() {
                  _currentLocation = locationResult.lastLocation;
                });
                _animateToLocation(locationResult.lastLocation!);
              }
              // Remove the callback once the update is received
              if (callbackId != null) {
                _locationService.removeLocationUpdates(callbackId);
              }
            },
            onLocationAvailability: (_) {},
          ),
        );
      }
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  void _onMapCreated(HuaweiMapController controller) {
    _mapController = controller;
    // Animate to current location if already fetched when map loads
    if (_currentLocation != null) {
      _animateToLocation(_currentLocation!);
    }
  }

  void _animateToLocation(hwLocation.Location location) { // Use prefix
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.latitude!, location.longitude!),
          zoom: 15.0, // Zoom in closer when location is known
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack( // Use Stack to show loading indicator
      children: [
        HuaweiMap(
          initialCameraPosition: _kInitialPosition,
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
        // Loading indicator while geocoding
        if (_isLoadingMarkers)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
