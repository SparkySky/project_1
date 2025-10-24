import 'dart:async';
import 'package:flutter/services.dart';
import 'package:huawei_location/huawei_location.dart' as huawei_loc;
import 'package:permission_handler/permission_handler.dart';

class LocationServiceHelper {
  // --- Singleton Pattern ---
  LocationServiceHelper._privateConstructor();
  static final LocationServiceHelper _instance = LocationServiceHelper._privateConstructor();
  factory LocationServiceHelper() {
    return _instance;
  }
  // --- End Singleton Pattern ---

  final huawei_loc.FusedLocationProviderClient _locationService =
      huawei_loc.FusedLocationProviderClient();

  StreamController<huawei_loc.Location>? _locationStreamController;
  int? _streamCallbackId;

  Future<bool> hasLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<huawei_loc.Location?> getLastLocation() async {
    try {
      if (!await hasLocationPermission()) {
        await requestLocationPermission();
      }
      final location = await _locationService.getLastLocation();
      return location;
    } catch (e) {
      print('Error getting last location: $e');
      return null;
    }
  }

  Future<huawei_loc.Location?> getCurrentLocation() async {
    if (!await hasLocationPermission()) {
      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        print("Location permission not granted.");
        return null;
      }
    }

    final completer = Completer<huawei_loc.Location?>();
    int? callbackId;

    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        print("Location request timed out.");
        if (callbackId != null) {
          try {
            _locationService.removeLocationUpdates(callbackId);
          } on PlatformException catch (e) {
            print("Error removing location updates on timeout (ignorable): ${e.message}");
          }
        }
        completer.complete(null);
      }
    });

    try {
      callbackId = await _locationService.requestLocationUpdatesCb(
        huawei_loc.LocationRequest()
          ..priority = huawei_loc.LocationRequest.PRIORITY_HIGH_ACCURACY
          ..numUpdates = 1,
        huawei_loc.LocationCallback(
          onLocationResult: (locationResult) async {
            if (!completer.isCompleted) {
              timer.cancel();
              completer.complete(locationResult.lastLocation);
              if (callbackId != null) {
                try {
                  await _locationService.removeLocationUpdates(callbackId);
                } on PlatformException catch (e) {
                  print("Error removing location updates after success (ignorable): ${e.message}");
                }
              }
            }
          },
          onLocationAvailability: (availability) {
            // This is required, but we don't need to do anything with it.
          },
        ),
      );
    } catch (e) {
       print("Error requesting location updates: $e");
       if (!completer.isCompleted) {
         timer.cancel();
         completer.complete(null);
       }
    }
    return completer.future;
  }

  Stream<huawei_loc.Location> getLocationStream() {
    _locationStreamController ??= StreamController<huawei_loc.Location>.broadcast(
      onListen: _startLocationStream,
      onCancel: _stopLocationStream,
    );
    return _locationStreamController!.stream;
  }

  void _startLocationStream() async {
    if (_streamCallbackId != null) return; 

    if (!await hasLocationPermission()) {
       await requestLocationPermission();
    }

    huawei_loc.LocationRequest request = huawei_loc.LocationRequest()
      ..priority = huawei_loc.LocationRequest.PRIORITY_HIGH_ACCURACY
      ..interval = 2000;

    try {
       _streamCallbackId = await _locationService.requestLocationUpdatesCb(
        request,
        huawei_loc.LocationCallback(
          onLocationResult: (locationResult) {
            if (locationResult.lastLocation != null) {
              _locationStreamController?.add(locationResult.lastLocation!);
            }
          },
          onLocationAvailability: (availability) {},
        ),
      );
    } catch (e) {
      print("Error starting location stream: $e");
      _locationStreamController?.addError(e);
    }
  }

  void _stopLocationStream() {
     if (_streamCallbackId != null) {
      try {
        _locationService.removeLocationUpdates(_streamCallbackId!);
        print("Successfully requested to remove location stream updates.");
      } on PlatformException catch (e) {
        // This can happen if the widget is disposed before the platform responds.
        // It's safe to ignore as the update removal will likely still succeed.
        print("Error removing location stream updates (ignorable): ${e.message}");
      }
      _streamCallbackId = null;
    }
  }
  
  void dispose() {
    _stopLocationStream();
    _locationStreamController?.close();
  }
}
