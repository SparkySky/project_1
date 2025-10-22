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
  bool _isLoadingLocation = true;
  CameraPosition? _initialPosition;

  // Default fallback position
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
      final String address = incident['location'] ?? 'Address not found';

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
              snippet: address,
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

    // 1. Check/Request Permission
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

    // 2. Fetch Location
    try {
      // First try to get last known location (fastest)
      print("Attempting to get last known location...");
      hwLocation.Location? location = await _locationService.getLastLocation();

      if (location != null && location.latitude != null && location.longitude != null) {
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
        return; // Exit early since we got the location
      }

      print("Last location is null or invalid. Requesting fresh location update...");

      // If last location is null, request a fresh update with timeout
      final Completer<void> locationCompleter = Completer<void>();
      int? callbackId;

      // Set a timeout to prevent infinite waiting
      Timer timeoutTimer = Timer(const Duration(seconds: 10), () {
        print("Location request TIMEOUT after 10 seconds.");
        if (!locationCompleter.isCompleted) {
          locationCompleter.complete();
          if (callbackId != null) {
            _locationService.removeLocationUpdates(callbackId);
          }
          if (mounted) {
            setState(() {
              _initialPosition = _kFallbackPosition;
              _isLoadingLocation = false;
            });
          }
        }
      });

      callbackId = await _locationService.requestLocationUpdatesCb(
        hwLocation.LocationRequest()
          ..priority = hwLocation.LocationRequest.PRIORITY_HIGH_ACCURACY
          ..numUpdates = 1,
        hwLocation.LocationCallback(
          onLocationResult: (locationResult) {
            print("Location callback triggered!");
            if (!locationCompleter.isCompleted &&
                locationResult.lastLocation != null &&
                locationResult.lastLocation!.latitude != null &&
                locationResult.lastLocation!.longitude != null) {
              print("SUCCESS! Got fresh location: ${locationResult.lastLocation!.latitude}, ${locationResult.lastLocation!.longitude}");
              timeoutTimer.cancel();
              locationCompleter.complete();

              if (mounted) {
                setState(() {
                  _currentLocation = locationResult.lastLocation;
                  _initialPosition = CameraPosition(
                    target: LatLng(
                      locationResult.lastLocation!.latitude!,
                      locationResult.lastLocation!.longitude!,
                    ),
                    zoom: 15.0,
                  );
                  _isLoadingLocation = false;
                });
              }
            }
            if (callbackId != null) {
              _locationService.removeLocationUpdates(callbackId);
            }
          },
          onLocationAvailability: (availability) {
            print("Location availability: ${availability?.isLocationAvailable}");
          },
        ),
      );

      await locationCompleter.future;
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