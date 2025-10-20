import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart';
import 'package:permission_handler/permission_handler.dart';

class MapWidget extends StatefulWidget {
  final double height;
  final double initialZoom;

  const MapWidget({
    Key? key,
    this.height = 300,
    this.initialZoom = 15,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final GlobalKey _mapKey = GlobalKey();
  HuaweiMapController? _mapController;
  final FusedLocationProviderClient _locationService = FusedLocationProviderClient();
  LatLng? _currentLocation;
  bool _isLoading = true;
  final Set<Marker> _markers = {};
  bool _mapBuilt = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Request storage permission for tile database
      print('Requesting storage permission...');
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        print('Storage permission denied.');
        if (await Permission.storage.isPermanentlyDenied) {
          print('Storage permission permanently denied, directing to settings.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable storage permission in app settings.'),
                duration: Duration(seconds: 3),
              ),
            );
            await openAppSettings(); // Guide user to settings
          }
          if (mounted) setState(() => _isLoading = false);
          return; // Exit if storage permission is not granted
        }
      } else {
        print('Storage permission granted.');
      }

      // Request location permission
      print('Requesting location permission...');
      final locationStatus = await Permission.location.request();
      if (locationStatus.isGranted) {
        print('Location permission granted.');
        await _getUserLocation(); // Proceed to get location and initialize map
      } else {
        print('Location permission denied.');
        if (await Permission.location.isPermanentlyDenied) {
          print('Location permission permanently denied, directing to settings.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable location permission in app settings.'),
                duration: Duration(seconds: 3),
              ),
            );
            await openAppSettings();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to show the map.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error in _initializeLocation: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _getUserLocation() async {
    try {
      print('Getting last known location...');
      final location = await _locationService.getLastLocation();

      if (location != null &&
          location.latitude != null &&
          location.longitude != null) {
        print('Got location: ${location.latitude}, ${location.longitude}');
        _setLocation(location.latitude!, location.longitude!);
        return;
      }

      print('No last known location, requesting updates...');
      await _requestLocationUpdates();
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestLocationUpdates() async {
    try {
      final locationRequest = LocationRequest();
      locationRequest.interval = 1000;
      locationRequest.priority = LocationRequest.PRIORITY_HIGH_ACCURACY;

      await _locationService.requestLocationUpdates(locationRequest);

      // Wait for location to be available
      int attempts = 0;
      while (attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        final location = await _locationService.getLastLocation();
        
        if (location != null &&
            location.latitude != null &&
            location.longitude != null) {
          print('Got location after ${(attempts + 1) * 500}ms: ${location.latitude}, ${location.longitude}');
          _setLocation(location.latitude!, location.longitude!);
          return;
        }
        attempts++;
      }

      print('Unable to get location after retries');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error requesting location updates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setLocation(double lat, double lng) {
    final newLocation = LatLng(lat, lng);
    print('Setting location: $lat, $lng');

    if (!mounted) return;

    setState(() {
      _currentLocation = newLocation;
      _isLoading = false;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: newLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    });

    // Force map rebuild
    if (_mapBuilt && _mapController != null) {
      _animateToLocation(newLocation);
      // Trigger a rebuild to ensure map renders
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _animateToLocation(LatLng location) {
    if (_mapController == null) return;

    print('Animating to location: $location');
    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, widget.initialZoom),
      );
    } catch (e) {
      print('Error animating camera: $e');
    }
  }

  void _onMapCreated(HuaweiMapController controller) {
    print('Map created');
    _mapController = controller;
    _mapBuilt = true;

    // Animate if location is already available
    if (_currentLocation != null && !_isLoading) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _mapController != null && _currentLocation != null) {
          _animateToLocation(_currentLocation!);
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('MapWidget build - isLoading: $_isLoading, hasLocation: ${_currentLocation != null}');

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          HuaweiMap(
            key: _mapKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(0.0, 0.0), // Fallback to default
              zoom: widget.initialZoom,
            ),
            myLocationEnabled: _currentLocation != null, // Enable only when location is ready
            myLocationButtonEnabled: false,
            markers: _markers,
            compassEnabled: true,
            zoomControlsEnabled: true,
          ),
          if (_isLoading)
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Getting your location...'),
                  ],
                ),
              ),
            ),
          if (!_isLoading && _currentLocation == null)
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: Text('Unable to get location'),
              ),
            ),
        ],
      ),
    );
  }
}