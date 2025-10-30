import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color alertRed = Color(0xFFE74C3C);
  static const Color discussionBlue = Color(0xFF3498DB);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textGrey = Color(0xFF7F8C8D);
  static const Color backgroundLight = Color(0xFFF5F5F5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryOrange,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryOrange,
        unselectedItemColor: textGrey,
        backgroundColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
      ),
    );
  }
}