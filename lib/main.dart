import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_theme.dart';
import 'splashscreen.dart';
import 'providers/user_provider.dart';
// import 'bg_services/safety_service.dart'; // No longer needed globally
import 'debug_overlay/debug_overlay.dart';
import 'debug_overlay/debug_state.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await DebugState().loadState(); 

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mysafezone_foreground',
    'MYSafeZone Monitoring',
    description: 'Background service for safety monitoring.',
    importance: Importance.low,
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          debugPrint("[main.dart] UserProvider created.");
          return UserProvider();
        }),
        // SafetyServiceProvider has been removed to prevent startup conflicts
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
        if (!_showDebugOverlay) return child!;
        return Stack(
          children: [
            ?child,
            const DebugOverlayWidget(),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
