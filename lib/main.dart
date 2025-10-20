import 'dart:async';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:agconnect_core/agconnect_core.dart';
import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'bg_services/background_service.dart';
import 'permissions/permission_handler.dart';
import 'splashscreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // 3. Initialize AGConnect Core & CloudDB in the main isolate
  try {
    // Core initialization is handled natively by the agconnect plugin reading the json file.
    final cloudDB = AGConnectCloudDB.getInstance();
    await cloudDB.initialize();
    await cloudDB.createObjectType(); // Ensure models are created before service starts
    if (kDebugMode) {
      print("[MAIN] AGConnect and CloudDB Initialized in main isolate.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("[MAIN] CRITICAL Error during AGConnect/CloudDB init: $e");
    }
  }

  // CRITICAL: Longer delay for HMS Core to fully initialize and authenticate
  // This prevents 403 errors on first map load
  await Future.delayed(const Duration(milliseconds: 3000));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MYSafeZone',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false, // Debug: Remove the top right banner
      home: const SplashScreen(),
    );
  }
}
