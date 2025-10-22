import 'dart:async';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'bg_services/background_service.dart';
import 'collection_in_progress_page.dart';
import 'lodge_incident_page.dart';
import 'permissions/permission_handler.dart';
import 'splashscreen.dart';
import 'util/debug_state.dart';
import 'util/debug_overlay.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DebugState().loadState();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mysafezone_foreground',
    'MYSafeZone Monitoring',
    description: 'Background service for safety monitoring.',
    importance: Importance.low,
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await requestPermissions();
  await initializeBackgroundService();

  try {
    final cloudDB = AGConnectCloudDB.getInstance();
    await cloudDB.initialize();
    await cloudDB.createObjectType();
    if (kDebugMode) print("[MAIN] AGConnect and CloudDB Initialized.");
  } catch (e) {
    if (kDebugMode) print("[MAIN] CRITICAL Error during AGConnect/CloudDB init: $e");
  }
  runApp(const MyApp());
}

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
    _showDebugOverlay = _debugState.showDebugOverlay;
    _debugState.addListener(_onDebugStateChanged);

    // Listen for events from the background service to handle navigation
    final service = FlutterBackgroundService();
    service.on('showCollectionScreen').listen((event) {
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (context) => CollectionInProgressPage(initialData: event),
      ));
    });

    service.on('closeCollectionScreen').listen((event) {
      // Pop the collection screen if it's open
      navigatorKey.currentState?.pop();
    });

    service.on('showLodgeScreen').listen((event) {
      // Replace the collection screen with the lodge screen
      navigatorKey.currentState?.pushReplacement(MaterialPageRoute(
        builder: (context) => LodgeIncidentPage(incidentData: event),
      ));
    });
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
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return !_showDebugOverlay ? child! : Stack(children: [child!, const DebugOverlayWidget()]);
      },
      home: const SplashScreen(),
    );
  }
}
