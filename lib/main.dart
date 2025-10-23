import 'dart:async';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'bg_services/background_service.dart';
import 'bg_services/sensors_analysis.dart';
import 'permissions/permission_handler.dart';
import 'splashscreen.dart';
import 'util/debug_state.dart';
import 'util/debug_overlay.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Ensures that plugin services are initialized before runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the .env file
  await dotenv.load(fileName: ".env");

  await DebugState().loadState(); // Debug: Load debug state from storage


  // Create Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mysafezone_foreground', // Must match ID used in background_service.dart
    'MYSafeZone Monitoring', // Channel name visible in Android settings
    description: 'Background service for safety monitoring.',
    importance: Importance.low, // Use low to avoid sound/vibration
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 1. Request needed permissions
  await requestPermissions();

  // 2. Initialize AGConnect Core & Other Services in the main isolate
  //    This MUST be done before creating services that depend on it.
  try {
    // Core initialization is handled natively by the agconnect plugin reading the json file.
    
    // Initialize CloudDB
    final cloudDB = AGConnectCloudDB.getInstance();
    await cloudDB.initialize();
    await cloudDB.createObjectType(); // Ensure models are created before service starts

    if (kDebugMode) {
      print("[MAIN] AGConnect and CloudDB Initialized in main isolate.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("[MAIN] CRITICAL Error during AGConnect services init: $e");
    }
  }
  
  // 3. Initialize the Background Service configuration
  await initializeBackgroundService();

  // 4. Initialize the Sensors Analysis Service (after AGConnect is ready)
  final sensorsAnalysisService = SensorsAnalysisService(navigatorKey: navigatorKey);
  await sensorsAnalysisService.initialize();

  runApp(const MyApp());
}


// StatefulWidget to listen for DebugState changes
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DebugState _debugState = DebugState();
  bool _showDebugOverlay = false;

  @override
  void initState() {
    super.initState();
    // Set the initial state
    _showDebugOverlay = _debugState.showDebugOverlay;
    // Listen for future changes
    _debugState.addListener(_onDebugStateChanged);
  }

  @override
  void dispose() {
    _debugState.removeListener(_onDebugStateChanged);
    super.dispose();
  }

  void _onDebugStateChanged() {
    if (mounted) {
      setState(() {
        _showDebugOverlay = _debugState.showDebugOverlay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MYSafeZone',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false, // Debug: Remove the top right banner
      // MaterialApp.builder to stack the overlay
      builder: (context, child) {
        if (!_showDebugOverlay) {
          return child!; // Return the normal app
        }

        // If overlay is on, wrap the app in a Stack and add the overlay
        return Stack(
          children: [
            child!, // The normal app
            const DebugOverlayWidget(), // Our new overlay widget
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
