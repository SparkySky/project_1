import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'bg_services/background_service.dart';
import 'bg_services/clouddb_service.dart';
import 'permissions/permission_handler.dart';
import 'providers/user_provider.dart';
import 'util/debug_state.dart';
import 'util/debug_overlay.dart';
import 'splashscreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DebugState().loadState(); // Debug: Load debug state from storage

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
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // 1. Request needed permissions
  await requestPermissions();

  // 2. Initialize the Background Service configuration
  await initializeBackgroundService();

  // 3. Initialize AGConnect Core & CloudDB in the main isolate
  try {
    await CloudDbService.initialize();
    await CloudDbService.createObjectType();
    print('[MAIN] Cloud DB initialized successfully');
  } catch (e) {
    print('[MAIN] Error initializing Cloud DB: $e');
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const MyApp(),
    ),
  );
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
