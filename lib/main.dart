import 'dart:async';
import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'bg_services/background_service.dart';
import 'permissions/permission_handler.dart';
import 'splashscreen.dart';

Future<void> main() async {
  // Ensures that plugin services (like HMS Core) are initialized before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Create Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mysafezone_foreground', // Must match ID used in background_service.dart
    'MYSafeZone Monitoring', // Channel name visible in Android settings
    description: 'Background service for safety monitoring.',
    importance: Importance.low, // Use low to avoid sound/vibration
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 1. Request needed permissions
  await requestPermissions();

  // 2. Initialize the Background Service configuration
  await initializeBackgroundService();

  // 3. Initialize AGConnect Core & CloudDB (only needs initialize now)
  // These might throw errors if agconnect-services.json is missing/invalid
  // or if native plugins fail.
  try {
    // Core initialization is handled natively by the agconnect plugin reading the json file.
    // We only need to initialize CloudDB service itself.
    //import 'package:agconnect_clouddb/agconnect_clouddb.dart'; // Add this import at the top
    //await AGConnectCloudDB.getInstance().initialize(); // This might belong inside background service? Let's keep it simple first.
    print("AGConnect should be initialized natively.");
  } catch (e) {
    print("Error during potential AGConnect/CloudDB init check: $e");
  }

  // CRITICAL: Longer delay for HMS Core to fully initialize and authenticate
  // This prevents 403 errors on first map load
  await Future.delayed(const Duration(milliseconds: 1500));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MYSafeZone',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false, // Debug: Remove the top right banner
      home: const SplashScreen(),
    );
  }
}