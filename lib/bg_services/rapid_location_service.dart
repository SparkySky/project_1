import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sensors/location_centre.dart';
import '../repository/user_repository.dart';
import 'package:agconnect_auth/agconnect_auth.dart';

class RapidLocationService extends ChangeNotifier {
  static final RapidLocationService _instance =
      RapidLocationService._internal();
  factory RapidLocationService() => _instance;
  RapidLocationService._internal();

  Timer? _locationTimer;
  Timer? _videoTimer;
  bool _isRunning = false;
  int _updateCount = 0;
  DateTime? _startTime;
  String? _incidentMediaId;

  final _userRepository = UserRepository();
  final _locationService = LocationServiceHelper();

  bool get isRunning => _isRunning;
  int get updateCount => _updateCount;
  Duration get elapsed => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : const Duration();

  /// Start rapid location updates (every 10 seconds)
  Future<void> startRapidUpdates({String? incidentMediaId}) async {
    if (_isRunning) return;

    print('[RapidLocation] Starting rapid location updates...');
    _isRunning = true;
    _updateCount = 0;
    _startTime = DateTime.now();
    _incidentMediaId = incidentMediaId;
    notifyListeners();

    // Immediate first update
    await _updateLocation();

    // Update location every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _updateLocation();
    });

    // TODO: Start video recording timer (every 2 minutes)
    // _startVideoRecording();
  }

  /// Stop rapid location updates
  Future<void> stopRapidUpdates() async {
    print('[RapidLocation] Stopping rapid location updates...');
    _locationTimer?.cancel();
    _videoTimer?.cancel();
    _isRunning = false;
    _startTime = null;
    _incidentMediaId = null;
    await _userRepository.closeZone();
    notifyListeners();
  }

  /// Update user location to CloudDB
  Future<void> _updateLocation() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      if (user == null || user.uid == null) {
        print('[RapidLocation] No authenticated user');
        return;
      }

      final location = await _locationService.getLastLocation();
      if (location == null ||
          location.latitude == null ||
          location.longitude == null) {
        print('[RapidLocation] No location available');
        return;
      }

      await _userRepository.openZone();
      final userData = await _userRepository.getUserById(user.uid!);

      if (userData != null) {
        userData.latitude = location.latitude;
        userData.longitude = location.longitude;
        await _userRepository.upsertUser(userData);

        _updateCount++;
        notifyListeners();

        print(
          '[RapidLocation] ✅ Update #$_updateCount: ${location.latitude}, ${location.longitude}',
        );
      }
    } catch (e) {
      print('[RapidLocation] Error updating location: $e');
    }
  }

  void dispose() {
    _locationTimer?.cancel();
    _videoTimer?.cancel();
    _userRepository.closeZone();
    super.dispose();
  }
}
