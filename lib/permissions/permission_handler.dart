import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
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
}