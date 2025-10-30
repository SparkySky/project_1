import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:huawei_location/huawei_location.dart' as huawei_loc;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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


    _isRunning = true;
    _updateCount = 0;
    _startTime = DateTime.now();
    _incidentId = incidentId;
    notifyListeners();

    // Start actual foreground service (prevents Android from killing the app)
    await _startForegroundService();

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

            } else {

            }
          },
        ),
      );
    } catch (e) {

      // Fallback to timer-based approach if continuous updates fail
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _updateLocation();
      });

    }

    // TODO: Start video recording timer (every 2 minutes)
    // _startVideoRecording();
  }

  /// Stop rapid location updates and set incident status to 'endedByBtn'
  Future<void> stopRapidUpdates() async {

    _locationTimer?.cancel();
    _videoTimer?.cancel();

    // Stop foreground service
    await _stopForegroundService();

    // Hide foreground notification
    await _hideForegroundNotification();

    // Stop continuous location updates
    if (_locationCallbackId != null) {
      try {
        await _fusedLocationClient.removeLocationUpdates(_locationCallbackId!);
      } on PlatformException {
        // Ignorable error when removing location updates
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

        } else {

        }

        await _incidentRepository.closeZone();
      } catch (e) {

      }
    }

    _incidentId = null;

    // Close CloudDB zone now that rapid updates are stopped
    try {
      await _userRepository.closeZone();

    } catch (e) {

    }

    notifyListeners();
  }

  /// Update user location to CloudDB (initial update using last known location)
  Future<void> _updateLocation() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      if (user == null || user.uid == null) {

        return;
      }

      final location = await _locationService.getLastLocation();
      if (location == null ||
          location.latitude == null ||
          location.longitude == null) {

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
      }
    } catch (e) {

    }
  }

  /// Update location from continuous callback (works in background)
  Future<void> _updateLocationFromCallback(huawei_loc.Location location) async {
    if (!_isRunning) {
      return;
    }

    final startTime = DateTime.now();
    try {
      final user = await AGCAuth.instance.currentUser;
      if (user == null || user.uid == null) {

        return;
      }

      if (location.latitude == null || location.longitude == null) {

        return;
      }
      // Ensure CloudDB zone is open (may have been closed in background)
      await _userRepository.openZone();



      final userData = await _userRepository.getUserById(user.uid!);

      if (userData != null) {
        userData.latitude = location.latitude;
        userData.longitude = location.longitude;
        userData.locUpdateTime = DateTime.now(); // Update timestamp

        await _userRepository.upsertUser(userData);

        _updateCount++;
        notifyListeners();

        // Update notification to show progress
        await _updateNotificationProgress();
      }

      // Keep zone open for next update (don't close)
    } catch (e) {



      // Try to reopen zone on next update
      try {
        await _userRepository.closeZone();
      } catch (e2) {

      }
    }
  }

  /// Start the actual Android foreground service
  Future<void> _startForegroundService() async {
    try {
      final service = FlutterBackgroundService();

      // Check if service is already running
      final isRunning = await service.isRunning();
      if (isRunning) {

        return;
      }

      // Configure the service
      await service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: (service) {},
          onBackground: (service) {
            return true;
          },
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: (service) {

          },
          isForegroundMode: true,
          autoStart: false,
          autoStartOnBoot: false,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
      );

      // Start the service
      await service.startService();
    } catch (e) {

      // Continue anyway - notification might still keep app alive
    }
  }

  /// Stop the Android foreground service
  Future<void> _stopForegroundService() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();

      if (isRunning) {
        service.invoke('stopService');

      }
    } catch (e) {

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
    } catch (e) {

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

    }
  }

  /// Hide foreground notification
  Future<void> _hideForegroundNotification() async {
    try {
      await _notificationsPlugin.cancel(_notificationId);

    } catch (e) {

    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _videoTimer?.cancel();

    // Stop foreground service
    _stopForegroundService();

    // Remove location callback if still active
    if (_locationCallbackId != null) {
      try {
        _fusedLocationClient.removeLocationUpdates(_locationCallbackId!);

      } catch (e) {

      }
      _locationCallbackId = null;
    }

    // Hide notification
    _hideForegroundNotification();

    _userRepository.closeZone();
    super.dispose();
  }
}
