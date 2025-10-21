import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple singleton state manager for the debug overlay.
class DebugState with ChangeNotifier {
  static final DebugState _instance = DebugState._internal();
  factory DebugState() => _instance;
  DebugState._internal();

  bool _showDebugOverlay = false;
  bool get showDebugOverlay => _showDebugOverlay;

  static const String _prefKey = 'debugOverlayEnabled';

  /// Loads the saved preference from SharedPreferences.
  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showDebugOverlay = prefs.getBool(_prefKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading debug state: $e");
      _showDebugOverlay = false;
    }
  }

  /// Updates the state and saves the preference to SharedPreferences.
  Future<void> setShowDebugOverlay(bool value) async {
    if (_showDebugOverlay == value) return; // No change
    _showDebugOverlay = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (e) {
      debugPrint("Error saving debug state: $e");
    }
  }
}