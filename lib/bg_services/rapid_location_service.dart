import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:huawei_location/huawei_location.dart' as huawei_loc;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../sensors/location_centre.dart';
import '../repository/user_repository.dart';
import '../repository/incident_repository.dart';
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
  String? _incidentId;
  int? _locationCallbackId; // For continuous location updates

  final _userRepository = UserRepository();
  final _incidentRepository = IncidentRepository();
  final _locationService = LocationServiceHelper();
  final _fusedLocationClient = huawei_loc.FusedLocationProviderClient();
  final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int _notificationId =
      9999; // Unique ID for emergency notification

  bool get isRunning => _isRunning;
  int get updateCount => _updateCount;
  Duration get elapsed => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : const Duration();

  /// Start rapid location updates (every 10 seconds) - works in background
  Future<void> startRapidUpdates({String? incidentId}) async {
    if (_isRunning) return;

    print('[RapidLocation] 🚀 Starting rapid location updates...');
    _isRunning = true;
    _updateCount = 0;
    _startTime = DateTime.now();
    _incidentId = incidentId;
    notifyListeners();

    // Show persistent foreground notification to keep app alive
    await _showForegroundNotification();

    // Immediate first update using last known location
    await _updateLocation();

    // Start continuous location updates from Huawei Location Service
    // This works reliably in background unlike Timer.periodic
    try {
      final locationRequest = huawei_loc.LocationRequest()
        ..priority = huawei_loc.LocationRequest.PRIORITY_HIGH_ACCURACY
        ..interval =
            10000 // 10 seconds
        ..fastestInterval =
            5000 // Allow updates as fast as 5 seconds if available
        ..maxWaitTime =
            15000; // Maximum wait time before delivering batched updates

      _locationCallbackId = await _fusedLocationClient.requestLocationUpdatesCb(
        locationRequest,
        huawei_loc.LocationCallback(
          onLocationResult: (locationResult) async {
            if (locationResult.lastLocation != null) {
              await _updateLocationFromCallback(locationResult.lastLocation!);
            }
          },
          onLocationAvailability: (availability) {
            if (availability.isLocationAvailable) {
              debugPrint('[RapidLocation] ✅ Location available');
            } else {
              debugPrint('[RapidLocation] ⚠️ Location not available');
            }
          },
        ),
      );

      print(
        '[RapidLocation] ✅ Continuous location updates started (callback ID: $_locationCallbackId)',
      );
    } catch (e) {
      print('[RapidLocation] ❌ Failed to start continuous updates: $e');
      // Fallback to timer-based approach if continuous updates fail
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _updateLocation();
      });
      print('[RapidLocation] ⚠️ Using fallback timer-based updates');
    }

    // TODO: Start video recording timer (every 2 minutes)
    // _startVideoRecording();
  }

  /// Stop rapid location updates and set incident status to 'endedByBtn'
  Future<void> stopRapidUpdates() async {
    print('[RapidLocation] 🛑 Stopping rapid location updates...');
    _locationTimer?.cancel();
    _videoTimer?.cancel();

    // Hide foreground notification
    await _hideForegroundNotification();

    // Stop continuous location updates
    if (_locationCallbackId != null) {
      try {
        await _fusedLocationClient.removeLocationUpdates(_locationCallbackId!);
        print(
          '[RapidLocation] ✅ Removed location callback (ID: $_locationCallbackId)',
        );
      } on PlatformException catch (e) {
        print(
          '[RapidLocation] ⚠️ Error removing location updates (ignorable): ${e.message}',
        );
      } finally {
        _locationCallbackId = null;
      }
    }

    _isRunning = false;
    _startTime = null;

    // Update incident status to 'endedByBtn'
    if (_incidentId != null) {
      try {
        await _incidentRepository.openZone();
        final incident = await _incidentRepository.getIncidentById(
          _incidentId!,
        );

        if (incident != null) {
          incident.status = 'endedByBtn';
          await _incidentRepository.upsertIncident(incident);
          print('[RapidLocation] ✅ Incident status updated to "endedByBtn"');
        } else {
          print('[RapidLocation] ⚠️ Incident not found: $_incidentId');
        }

        await _incidentRepository.closeZone();
      } catch (e) {
        print('[RapidLocation] ❌ Error updating incident status: $e');
      }
    }

    _incidentId = null;

    // Close CloudDB zone now that rapid updates are stopped
    try {
      await _userRepository.closeZone();
      print('[RapidLocation] ✅ CloudDB zone closed');
    } catch (e) {
      print('[RapidLocation] ⚠️ Error closing CloudDB zone: $e');
    }

    notifyListeners();
  }

  /// Update user location to CloudDB (initial update using last known location)
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
        userData.locUpdateTime = DateTime.now(); // Update timestamp
        await _userRepository.upsertUser(userData);

        _updateCount++;
        notifyListeners();

        print(
          '[RapidLocation] ✅ Update #$_updateCount: ${location.latitude}, ${location.longitude} at ${userData.locUpdateTime}',
        );
      }
    } catch (e) {
      print('[RapidLocation] Error updating location: $e');
    }
  }

  /// Update location from continuous callback (works in background)
  Future<void> _updateLocationFromCallback(huawei_loc.Location location) async {
    if (!_isRunning) {
      debugPrint(
        '[RapidLocation] ⚠️ Received location but service not running',
      );
      return;
    }

    final startTime = DateTime.now();
    print(
      '[RapidLocation] 🔄 Background callback triggered at ${startTime.toIso8601String()}',
    );

    try {
      final user = await AGCAuth.instance.currentUser;
      if (user == null || user.uid == null) {
        print('[RapidLocation] ❌ No authenticated user');
        return;
      }

      if (location.latitude == null || location.longitude == null) {
        print('[RapidLocation] ❌ Invalid location data');
        return;
      }

      print(
        '[RapidLocation] 📍 Got location: ${location.latitude}, ${location.longitude}',
      );
      print('[RapidLocation] 💾 Opening CloudDB zone...');

      // Ensure CloudDB zone is open (may have been closed in background)
      await _userRepository.openZone();
      print('[RapidLocation] ✅ CloudDB zone opened');

      print('[RapidLocation] 🔍 Fetching user data for UID: ${user.uid}');
      final userData = await _userRepository.getUserById(user.uid!);

      if (userData != null) {
        print('[RapidLocation] ✅ User data found, updating location...');

        userData.latitude = location.latitude;
        userData.longitude = location.longitude;
        userData.locUpdateTime = DateTime.now(); // Update timestamp

        print('[RapidLocation] 💾 Upserting user data to CloudDB...');
        await _userRepository.upsertUser(userData);

        _updateCount++;
        notifyListeners();

        final timestamp = DateTime.now().toIso8601String();
        final duration = DateTime.now().difference(startTime).inMilliseconds;

        print(
          '[RapidLocation] ✅✅✅ SUCCESS! Update #$_updateCount completed in ${duration}ms',
        );
        print(
          '[RapidLocation] 📍 Location: ${location.latitude}, ${location.longitude}',
        );
        print('[RapidLocation] 🕐 Timestamp: $timestamp');

        // Update notification to show progress
        await _updateNotificationProgress();
      } else {
        print('[RapidLocation] ❌ User data not found in CloudDB');
      }

      // Keep zone open for next update (don't close)
      print('[RapidLocation] 💡 Keeping CloudDB zone open for next update');
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('[RapidLocation] ❌❌❌ FAILED after ${duration}ms: $e');
      print('[RapidLocation] Stack trace: $stackTrace');

      // Try to reopen zone on next update
      try {
        await _userRepository.closeZone();
      } catch (e2) {
        print('[RapidLocation] ⚠️ Error closing zone: $e2');
      }
    }
  }

  /// Show persistent foreground notification (keeps app alive in background)
  Future<void> _showForegroundNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'mysafezone_foreground',
        'MYSafeZone Monitoring',
        channelDescription: 'Emergency location tracking active',
        importance: Importance.high, // HIGH to keep app alive
        priority: Priority.high, // HIGH priority
        ongoing: true, // Persistent notification
        autoCancel: false,
        icon: '@mipmap/launcher_icon',
        showWhen: true,
        playSound: false, // Don't play sound for this notification
        enableVibration: false, // Don't vibrate
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
        // Use full screen intent to keep app running
        fullScreenIntent: true,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        _notificationId,
        '🚨 Emergency Mode Active',
        'Tracking your location every 10 seconds',
        notificationDetails,
      );

      print('[RapidLocation] ✅ Foreground notification shown (HIGH priority)');
    } catch (e) {
      print('[RapidLocation] ⚠️ Failed to show notification: $e');
    }
  }

  /// Update notification to show progress
  Future<void> _updateNotificationProgress() async {
    if (!_isRunning) return;

    try {
      final elapsed = this.elapsed;
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds % 60;
      final timeStr = '${minutes}m ${seconds}s';

      const androidDetails = AndroidNotificationDetails(
        'mysafezone_foreground',
        'MYSafeZone Monitoring',
        channelDescription: 'Emergency location tracking active',
        importance: Importance.high, // Keep HIGH
        priority: Priority.high, // Keep HIGH
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/launcher_icon',
        showWhen: true,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        _notificationId,
        '🚨 Emergency Mode Active',
        'Update #$_updateCount • Running $timeStr',
        notificationDetails,
      );
    } catch (e) {
      // Silently fail to not spam logs
      debugPrint('[RapidLocation] Failed to update notification: $e');
    }
  }

  /// Hide foreground notification
  Future<void> _hideForegroundNotification() async {
    try {
      await _notificationsPlugin.cancel(_notificationId);
      print('[RapidLocation] ✅ Foreground notification hidden');
    } catch (e) {
      print('[RapidLocation] ⚠️ Failed to hide notification: $e');
    }
  }

  void dispose() {
    _locationTimer?.cancel();
    _videoTimer?.cancel();

    // Remove location callback if still active
    if (_locationCallbackId != null) {
      try {
        _fusedLocationClient.removeLocationUpdates(_locationCallbackId!);
        print('[RapidLocation] 🧹 Cleaned up location callback on dispose');
      } catch (e) {
        print('[RapidLocation] Error cleaning up location callback: $e');
      }
      _locationCallbackId = null;
    }

    // Hide notification
    _hideForegroundNotification();

    _userRepository.closeZone();
    super.dispose();
  }
}
