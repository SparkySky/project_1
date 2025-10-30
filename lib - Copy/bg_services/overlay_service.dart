import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import 'capture_window_overlay.dart';
import 'analyzing_screen.dart';
import 'analysis_result_screen.dart';
import 'incident_confirmation_screen.dart';

/// Service to show overlays and full-screen dialogs
class OverlayService {
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  // Track if we have an active route (no longer using OverlayEntry)
  bool _hasActiveRoute = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Check if app is in foreground by checking if navigatorKey has a valid context
  bool get isAppInForeground {
    final hasContext = navigatorKey.currentContext != null;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isResumed = lifecycleState == AppLifecycleState.resumed;
    final isInactive = lifecycleState == AppLifecycleState.inactive;
    // Consider both resumed and inactive as foreground (inactive = app is visible but not focused)
    return hasContext && (isResumed || isInactive);
  }

  /// Show the 8-second capture window overlay (foreground only)
  /// Shows notification if in background
  void showCaptureWindow() {
    hideCurrentOverlay();

    // Try to push as a route instead of using Overlay
    final navigator = navigatorKey.currentState;

    if (navigator != null && isAppInForeground) {


      try {
        _hasActiveRoute = true;
        navigator.push(
          MaterialPageRoute(
            builder: (context) => const CaptureWindowOverlay(),
            fullscreenDialog: true,
          ),
        );

      } catch (e) {


        _hasActiveRoute = false;
        _showCaptureNotification();
      }
    } else {
      _showCaptureNotification();
    }
  }

  /// Show notification when in background
  void _showCaptureNotification() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'mysafezone_safety_trigger',
          'Safety Trigger',
          channelDescription: '8-second data collection in progress',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          // icon: 'ic_launcher', // Removed - use default icon
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    _notificationsPlugin.show(
      9999, // Use a fixed ID for safety trigger
      '⚠️ Safety Trigger Activated',
      'Collecting 8 seconds of audio and sensor data...',
      details,
    );
  }

  /// Hide the capture notification
  void hideCaptureNotification() {
    _notificationsPlugin.cancel(9999);
  }

  /// Show the analyzing screen (Gemini verdict in progress)
  void showAnalyzingScreen() {
    hideCurrentOverlay();

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }



    _hasActiveRoute = true;
    navigator.push(
      MaterialPageRoute(
        builder: (context) => const AnalyzingScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show incident confirmation screen (15-second cancellation for TRUE POSITIVE)
  void showIncidentConfirmation({
    required String description,
    required String transcript,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    hideCurrentOverlay();

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }



    _hasActiveRoute = true;
    navigator.push(
      MaterialPageRoute(
        builder: (context) => IncidentConfirmationScreen(
          description: description,
          transcript: transcript,
          onConfirm: onConfirm,
          onCancel: onCancel,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show the analysis result screen
  void showAnalysisResult({
    required bool isIncident,
    required String description,
    required String triggerSource,
    String transcript = '',
    VoidCallback? onDismiss,
  }) {
    hideCurrentOverlay();

    final navigator = navigatorKey.currentState;
    if (navigator == null) {

      return;
    }
    _hasActiveRoute = true;
    navigator.push(
      MaterialPageRoute(
        builder: (context) => AnalysisResultScreen(
          isIncident: isIncident,
          description: description,
          triggerSource: triggerSource,
          transcript: transcript,
          onDismiss: onDismiss,
        ),
        fullscreenDialog: true,
      ),
    );

    // No auto-pop - user must click OK for false positives
    // True positive will navigate to lodge screen
  }

  /// Hide the current overlay (pop the route)
  void hideCurrentOverlay() {
    if (_hasActiveRoute) {

      try {
        final navigator = navigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      } catch (e) {

      }
      _hasActiveRoute = false;
    }

    // Also hide notification if active
    hideCaptureNotification();
  }
}
