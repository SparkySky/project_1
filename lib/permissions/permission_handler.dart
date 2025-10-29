import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

Future<Map<Permission, PermissionStatus>> requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.locationAlways, // Crucial for background
    Permission.microphone,
    Permission.notification, // Added for push notifications
    // Permission.sensors, // Usually granted automatically or implicitly covered
    // Add other specific permissions if needed by plugins (e.g., storage for flutter_sound)
    Permission.storage, // Example if flutter_sound needs it
  ].request();

  if (statuses[Permission.locationAlways] != PermissionStatus.granted) {
    // Consider showing a dialog guiding the user to settings:
    // openAppSettings();
  }
  if (statuses[Permission.microphone] != PermissionStatus.granted) {
  }
  if (statuses[Permission.notification] != PermissionStatus.granted) {
  }


  // Check battery optimization status (important for background location)
  await checkBatteryOptimization();

  return statuses;
}

/// Check notification permission status
Future<bool> hasNotificationPermission() async {
  final status = await Permission.notification.status;
  return status.isGranted;
}

/// Request notification permission
Future<bool> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  return status.isGranted;
}

/// Check if battery optimization is disabled for reliable background updates
Future<void> checkBatteryOptimization() async {
  try {
    final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;

    if (!isIgnoring) {
      final status = await Permission.ignoreBatteryOptimizations.request();

      if (status.isGranted) {
      } else {
      }
    } else {
    }
  } catch (e) {

  }
}
