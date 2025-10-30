import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../app_theme.dart';

/// Screen shown for 15 seconds after TRUE POSITIVE to allow user to cancel
class IncidentConfirmationScreen extends StatefulWidget {
  final String description;
  final String transcript;
  final VoidCallback onConfirm; // Called after 15 seconds if not cancelled
  final VoidCallback onCancel; // Called if user clicks FALSE ALARM

  const IncidentConfirmationScreen({
    super.key,
    required this.description,
    required this.transcript,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<IncidentConfirmationScreen> createState() =>
      _IncidentConfirmationScreenState();
}

class _IncidentConfirmationScreenState extends State<IncidentConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  Timer? _countdownTimer;
  Timer? _vibrationTimer;
  int _secondsRemaining = 15;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Start countdown
    _animationController.forward();
    _startCountdown();
    
    // Start continuous vibration
    _startVibration();
  }

  void _startVibration() {
    // Vibrate immediately
    HapticFeedback.vibrate();
    
    // Continue vibrating every 500ms
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      HapticFeedback.vibrate();
    });
  }

  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        _stopVibration(); // Stop vibration when countdown completes
        // Auto-confirm and navigate to lodge page
        widget.onConfirm();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopVibration(); // Stop vibration when widget is disposed
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.alertRed.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Warning Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'INCIDENT DETECTED',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Countdown
                    Text(
                      'Auto-reporting in $_secondsRemaining seconds',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Progress Bar
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return SizedBox(
                          width: double.infinity,
                          height: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progressAnimation.value,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Transcript (if available)
                    if (widget.transcript.isNotEmpty) ...[
                      const Text(
                        'TRANSCRIPT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '"${widget.transcript}"',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.3,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Description (fully scrollable with content)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI ANALYSIS:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.description,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed FALSE ALARM Button at bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 70,
                    child: ElevatedButton(
                      onPressed: () {
                        _countdownTimer?.cancel();
                        _stopVibration(); // Stop vibration when user cancels
                        _animationController.stop();
                        widget.onCancel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.alertRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, size: 36),
                          SizedBox(width: 12),
                          Text(
                            'FALSE ALARM',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap FALSE ALARM if this is not an emergency',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
