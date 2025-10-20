import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'splashscreen.dart';

Future<void> main() async {
  // Ensures that plugin services are initialized before runApp
  WidgetsFlutterBinding.ensureInitialized();

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