import 'dart:async';
import 'package:huawei_location/huawei_location.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationCentre {
  static final LocationCentre _instance = LocationCentre._internal();
  factory LocationCentre() => _instance;

  LocationCentre._internal();

  late FusedLocationProviderClient _locationService;
  int? _callbackId;
  Location? _currentLocation;
  final StreamController<Location?> _locationController = StreamController<Location?>.broadcast();
  
  ValueNotifier<Location?> currentLocationNotifier = ValueNotifier(null);

  Stream<Location?> get locationStream => _locationController.stream;

  Future<void> init() async {
    _locationService = FusedLocationProviderClient();
    
    // Use the permission_handler package to request permissions
    await [
      Permission.location,
      Permission.locationAlways,
    ].request();
  }

  Future<void> startLocationUpdates() async {
    // Stop previous updates if any
    if (_callbackId != null) {
      await stopLocationUpdates();
    }

    final locationRequest = LocationRequest();
    locationRequest.priority = LocationRequest.PRIORITY_HIGH_ACCURACY;
    locationRequest.interval = 5000;
    
    try {
      // Create a LocationCallback object and pass the function to its onLocationResult parameter.
      final locationCallback = LocationCallback(
        onLocationResult: (locationResult) {
          if (locationResult.lastLocation != null) {
            _currentLocation = locationResult.lastLocation;
            currentLocationNotifier.value = _currentLocation;
            _locationController.add(_currentLocation);
          }
        },
        onLocationAvailability: (locationAvailability) {
          // You can handle location availability changes here if needed.
        },
      );
      
      _callbackId = await _locationService.requestLocationUpdatesCb(locationRequest, locationCallback);

    } catch (e) {
      print('Error starting location updates: $e');
    }
  }

  Future<void> stopLocationUpdates() async {
    if (_callbackId != null) {
      try {
        // Use removeLocationUpdatesCb since we are using a callback.
        await _locationService.removeLocationUpdatesCb(_callbackId!);
        _callbackId = null;
      } catch (e) {
        print('Error stopping location updates: $e');
      }
    }
  }

  Future<Location?> getCurrentLocation() async {
    if (_currentLocation != null) {
      return _currentLocation;
    }
    // Fallback to get current location once
    try {
      return await _locationService.getLastLocation();
    } catch (e) {
      print("Error getting last known location: $e");
      return null;
    }
  }

  void dispose() {
    stopLocationUpdates();
    _locationController.close();
  }
}
