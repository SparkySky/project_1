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
  HuaweiMapController? _mapController;
  final FusedLocationProviderClient _locationService = FusedLocationProviderClient();
  LatLng? _currentLocation;
  bool _isLoading = true;
  bool _hmsReady = false;
  bool _shouldShowMap = false;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeWithHMSCheck();
  }

  Future<void> _initializeWithHMSCheck() async {
    print('Starting HMS Core initialization check...');
    
    // Wait for widget to be fully built
    await WidgetsBinding.instance.endOfFrame;
    
    // CRITICAL: Give HMS Core extra time to authenticate on first launch
    // This prevents 403 errors when loading map tiles
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (!mounted) return;
    
    print('HMS Core ready, initializing location...');
    // Get location FIRST before marking HMS as ready
    await _initializeLocation();
    
    // Only mark HMS ready after we have location
    if (mounted && _currentLocation != null) {
      setState(() {
        _hmsReady = true;
      });
    }
  }

  Future<void> _initializeLocation() async {
    print('Requesting location permission...');
    final status = await Permission.location.request();

    if (status.isGranted) {
      print('Permission granted.');
      await _getUserLocation();
    } else {
      print('Permission denied.');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to show the map'),
            duration: Duration(seconds: 3),
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
        _updateLocationOnMap(location.latitude!, location.longitude!);
      } else {
        print('No last known location, requesting updates...');
        // Try to get current location
        await _requestLocationUpdates();
      }
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
      
      // Wait a bit for location update
      await Future.delayed(const Duration(seconds: 3));
      
      final location = await _locationService.getLastLocation();
      if (location != null &&
          location.latitude != null &&
          location.longitude != null) {
        _updateLocationOnMap(location.latitude!, location.longitude!);
      } else {
        print('Unable to get location after requesting updates');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error requesting location updates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateLocationOnMap(double lat, double lng) {
    final newLocation = LatLng(lat, lng);

    if (!mounted) return;

    print('Updating location on map: $lat, $lng');

    setState(() {
      _currentLocation = newLocation;
      _isLoading = false;
      _shouldShowMap = true;
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

    print('Location updated, map should show now');

    // Delay camera animation to ensure map is fully ready
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _mapController != null) {
        print('Animating camera to location');
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newLocation, widget.initialZoom),
        );
      }
    });
  }

  void _onMapCreated(HuaweiMapController controller) {
    print('Map created callback received.');
    if (!mounted) return;
    
    setState(() {
      _mapController = controller;
    });

    // Move camera to current location if available
    if (_currentLocation != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentLocation!, widget.initialZoom),
          );
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
    print('Building MapWidget - isLoading: $_isLoading, hmsReady: $_hmsReady, shouldShowMap: $_shouldShowMap, hasLocation: ${_currentLocation != null}');
    
    return Container(
      height: widget.height,
      child: _currentLocation == null || !_shouldShowMap
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Getting your location...'),
                ],
              ),
            )
          : HuaweiMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: widget.initialZoom,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _markers,
              compassEnabled: true,
              zoomControlsEnabled: true,
            ),
    );
  }
}