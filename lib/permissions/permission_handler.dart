import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

Future<Map<Permission, PermissionStatus>> requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.locationAlways, // Crucial for background
    Permission.microphone,
    // Permission.sensors, // Usually granted automatically or implicitly covered
    // Add other specific permissions if needed by plugins (e.g., storage for flutter_sound)
    Permission.storage, // Example if flutter_sound needs it
  ].request();

  if (statuses[Permission.locationAlways] != PermissionStatus.granted) {
    print("WARNING: 'Always Allow' location permission not granted. Background location may fail.");
    // Consider showing a dialog guiding the user to settings:
    // openAppSettings();
  }
  if (statuses[Permission.microphone] != PermissionStatus.granted) {
    print("WARNING: Microphone permission not granted. Audio detection will fail.");
  }
  print("Permission statuses: $statuses");

  // Check battery optimization status (important for background location)
  await checkBatteryOptimization();

  return statuses;
}

/// Check if battery optimization is disabled for reliable background updates
Future<void> checkBatteryOptimization() async {
  try {
    final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
    
    if (!isIgnoring) {
      debugPrint(
        "[Permission] ⚠️ Battery optimization is ENABLED - background updates may be unreliable",
      );
      debugPrint(
        "[Permission] 💡 Requesting battery optimization exemption...",
      );
      
      final status = await Permission.ignoreBatteryOptimizations.request();
      
      if (status.isGranted) {
        debugPrint(
          "[Permission] ✅ Battery optimization disabled - background updates will work reliably",
        );
      } else {
        debugPrint(
          "[Permission] ❌ Battery optimization still enabled - user needs to disable manually in settings",
        );
        debugPrint(
          "[Permission] 📱 Guide user to: Settings > Apps > MYSafeZone > Battery > Unrestricted",
        );
      }
    } else {
      debugPrint(
        "[Permission] ✅ Battery optimization already disabled - background updates OK",
      );
    }
  } catch (e) {
    debugPrint("[Permission] ⚠️ Could not check battery optimization: $e");
  }
}