import 'dart:async';
import 'package:flutter/services.dart';
import 'package:huawei_location/huawei_location.dart' as huawei_loc;
import 'package:permission_handler/permission_handler.dart';
import '../repository/user_repository.dart';
import '../models/users.dart';

class LocationServiceHelper {
  // --- Singleton Pattern ---
  LocationServiceHelper._privateConstructor();
  static final LocationServiceHelper _instance =
      LocationServiceHelper._privateConstructor();
  factory LocationServiceHelper() {
    return _instance;
  }
  // --- End Singleton Pattern ---

  final huawei_loc.FusedLocationProviderClient _locationService =
      huawei_loc.FusedLocationProviderClient();

  StreamController<huawei_loc.Location>? _locationStreamController;
  int? _streamCallbackId;

  // Location update service
  Timer? _locationUpdateTimer;
  final UserRepository _userRepository = UserRepository();
  String? _currentUserId;

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

      return null;
    }
  }

  /// Get current location with fast fallback to last known location
  /// Tries cached location first (instant), then fresh location with shorter timeout
  Future<huawei_loc.Location?> getCurrentLocation({
    bool fastMode = true,
  }) async {
    if (!await hasLocationPermission()) {
      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {

        return null;
      }
    }

    // Fast mode: Try cached location first (instant!)
    if (fastMode) {
      final lastLoc = await getLastLocation();
      if (lastLoc != null) {
        // Check if cached location is recent (less than 2 minutes old)
        final age = DateTime.now().millisecondsSinceEpoch - (lastLoc.time ?? 0);
        if (age < 120000) {
          // 2 minutes = 120,000 ms
          return lastLoc;
        }
      }
    }

    final completer = Completer<huawei_loc.Location?>();
    int? callbackId;

    // Reduced timeout: 5 seconds instead of 10
    final timeoutDuration = fastMode
        ? const Duration(seconds: 5)
        : const Duration(seconds: 10);

    final timer = Timer(timeoutDuration, () async {
      if (!completer.isCompleted) {
        if (callbackId != null) {
          try {
            _locationService.removeLocationUpdates(callbackId);
          } on PlatformException {
          }
        }
        // Fallback to last known location
        final fallbackLoc = await getLastLocation();
        completer.complete(fallbackLoc);
      }
    });

    try {
      callbackId = await _locationService.requestLocationUpdatesCb(
        huawei_loc.LocationRequest()
          // Use BALANCED mode for faster fix (1-3 seconds vs 5-10 seconds)
          ..priority = fastMode
              ? huawei_loc.LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY
              : huawei_loc.LocationRequest.PRIORITY_HIGH_ACCURACY
          ..numUpdates = 1
          ..fastestInterval = 1000, // Get result as fast as possible
        huawei_loc.LocationCallback(
          onLocationResult: (locationResult) async {
            if (!completer.isCompleted) {
              timer.cancel();

              completer.complete(locationResult.lastLocation);
              if (callbackId != null) {
                try {
                  await _locationService.removeLocationUpdates(callbackId);
                } on PlatformException {
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

      if (!completer.isCompleted) {
        timer.cancel();
        // Fallback to last known location on error
        final fallbackLoc = await getLastLocation();
        completer.complete(fallbackLoc);
      }
    }
    return completer.future;
  }

  Stream<huawei_loc.Location> getLocationStream() {
    _locationStreamController ??=
        StreamController<huawei_loc.Location>.broadcast(
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

      _locationStreamController?.addError(e);
    }
  }

  void _stopLocationStream() {
    if (_streamCallbackId != null) {
      try {
        _locationService.removeLocationUpdates(_streamCallbackId!);

      } on PlatformException {
        // This can happen if the widget is disposed before the platform responds.
        // It's safe to ignore as the update removal will likely still succeed.
      }
      _streamCallbackId = null;
    }
  }

  /// Start automatic location updates to CloudDB every minute
  Future<void> startLocationUpdates(String userId) async {
    _currentUserId = userId;

    if (_locationUpdateTimer != null) {

      return;
    }



    // Update immediately
    await _updateLocationToCloudDB();

    // Then update every minute
    _locationUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateLocationToCloudDB(),
    );
  }

  /// Stop automatic location updates
  void stopLocationUpdates() {

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _currentUserId = null;
  }

  /// Update current location to CloudDB
  Future<void> _updateLocationToCloudDB() async {
    if (_currentUserId == null) return;

    try {
      final location = await getCurrentLocation();
      if (location == null) {

        return;
      }

      // Get existing user data
      await _userRepository.openZone();
      final existingUser = await _userRepository.getUserById(_currentUserId!);

      if (existingUser != null) {
        // Update only location fields
        final updatedUser = Users(
          uid: existingUser.uid,
          username: existingUser.username,
          district: existingUser.district,
          postcode: existingUser.postcode,
          state: existingUser.state,
          phoneNo: existingUser.phoneNo,
          latitude: location.latitude,
          longitude: location.longitude,
          locUpdateTime: DateTime.now(),
          allowDiscoverable: existingUser.allowDiscoverable,
          allowEmergencyAlert: existingUser.allowEmergencyAlert,
        );

        await _userRepository.upsertUser(updatedUser);
      } else {
      }
    } catch (e) {

    }
  }

  void dispose() {
    _stopLocationStream();
    _locationStreamController?.close();
    stopLocationUpdates();
  }
}
