import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'splashscreen.dart';

Future<void> main() async {
  // Ensures that plugin services (like HMS Core) are initialized before runApp
  WidgetsFlutterBinding.ensureInitialized();

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
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}