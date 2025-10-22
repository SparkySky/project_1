// lib/bg_services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'; // Needed for WidgetsFlutterBinding
import 'package:flutter_background_service/flutter_background_service.dart';
import 'safety_service_manager.dart';

// --- Service Initialization ---
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'mysafezone_foreground',
      initialNotificationTitle: "MYSafeZone Active",
      initialNotificationContent: "Initializing...",
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

// --- Main Background Entry Point ---
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure plugins are registered in this isolate
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final safetyManager = SafetyServiceManager(service);

  // Start the safety monitoring
  await safetyManager.start();

  // Listen for UI commands
  service.on('stopService').listen((event) {
    safetyManager.stop();
    service.stopSelf();
  });
}
