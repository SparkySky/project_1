import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project_1/bg_services/clouddb_service.dart';
import 'package:project_1/providers/safety_service_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_theme.dart';
import 'splashscreen.dart';
import 'providers/user_provider.dart';
// import 'bg_services/safety_service.dart'; // No longer needed globally
import 'debug_overlay/safety_debug_overlay.dart';
import 'debug_overlay/debug_state.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await DebugState().loadState();

  // Create notification channels
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel foregroundChannel =
      AndroidNotificationChannel(
        'mysafezone_foreground',
        'MYSafeZone Monitoring',
        description: 'Background service for safety monitoring.',
        importance: Importance.low,
      );

  const AndroidNotificationChannel safetyTriggerChannel =
      AndroidNotificationChannel(
        'mysafezone_safety_trigger',
        'Safety Trigger',
        description: '8-second data collection in progress',
        importance: Importance.high,
      );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(foregroundChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(safetyTriggerChannel);

  // 4. Initialize AGConnect Core & CloudDB in the main isolate
  try {
    await CloudDbService.initialize();
    await CloudDbService.createObjectType();
    print('[MAIN] Cloud DB initialized successfully');
  } catch (e) {
    print('[MAIN] Error initializing Cloud DB: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            debugPrint("[main.dart] UserProvider created.");
            return UserProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            debugPrint("[main.dart] SafetyServiceProvider created.");
            return SafetyServiceProvider();
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
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
        // Show debug overlay only if user has manually enabled it
        if (!_showDebugOverlay) return child!;
        return Stack(children: [child!, const SafetyDebugOverlay()]);
      },
      home: const SplashScreen(),
    );
  }
}
