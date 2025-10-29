import 'package:flutter/material.dart';
import '../main.dart';

class Snackbar {
  static void _show(String message, Color backgroundColor) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void success(String message) => _show(message, Colors.green);
  static void error(String message) => _show(message, Colors.red);
  static void warning(String message) => _show(message, Colors.orange);
  static void info(String message) => _show(message, Colors.blue);
}
