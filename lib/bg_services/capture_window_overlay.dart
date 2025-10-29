import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/safety_service_provider.dart';
import '../app_theme.dart';
import 'safety_trigger_service.dart';

/// Overlay showing the 8-second capture window progress
class CaptureWindowOverlay extends StatefulWidget {
  const CaptureWindowOverlay({super.key});

  @override
  State<CaptureWindowOverlay> createState() => _CaptureWindowOverlayState();
}

class _CaptureWindowOverlayState extends State<CaptureWindowOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {




    return Consumer<SafetyServiceProvider>(
      builder: (context, provider, child) {
        return Material(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section (icon + title + progress)
                  Column(
                    children: [
                      // Warning icon (smaller, more compact)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 48,
                          color: AppTheme.primaryOrange,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title (smaller, more compact)
                      const Text(
                        'ANALYZING INCIDENT',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Trigger source (more compact)
                      if (provider.lastTrigger != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Trigger: ${provider.lastTrigger}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Progress bar (more compact)
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              LinearProgressIndicator(
                                value: _progressController.value,
                                backgroundColor: Colors.grey[800],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryOrange,
                                ),
                                minHeight: 6,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(_progressController.value * 8).toStringAsFixed(1)}s / 8.0s',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Status text (smaller)
                      const Text(
                        'Recording audio and collecting sensor data...',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  // Middle section (data displays) - flexible
                  Flexible(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // IMU Data display - collapsed when empty
                        if (provider.captureWindowData.isNotEmpty)
                          Flexible(
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'IMU READINGS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryOrange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // IMU Data Table
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: provider.captureWindowData.map((
                                          reading,
                                        ) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Time: ${reading.timestamp}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.primaryOrange,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Mag: ${_calculateMagnitude(reading).toStringAsFixed(1)}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildSensorData(
                                                        'Accel',
                                                        reading.accelX,
                                                        reading.accelY,
                                                        reading.accelZ,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: _buildSensorData(
                                                        'Gyro',
                                                        reading.gyroX,
                                                        reading.gyroY,
                                                        reading.gyroZ,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (provider.captureWindowData.isNotEmpty)
                          const SizedBox(height: 12),

                        // Audio Transcript Section (compact)
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 100),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'AUDIO TRANSCRIPT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryOrange,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        provider.captureTranscript.isEmpty
                                            ? '🎙️ Recording...\n(Gemini will transcribe)'
                                            : provider.captureTranscript,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: provider.captureTranscript.isEmpty
                                              ? Colors.grey[500]
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom section (Cancel button) - fixed at bottom
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Cancel the capture in the safety service
                            await provider.cancelCapture();

                            // Pop the overlay
                            Navigator.of(context).pop();

                            // Show notification to user
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Capture cancelled. System ready for next trigger.',
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 24),
                          label: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Info text
                      Text(
                        'Tap CANCEL to stop this capture immediately',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Calculate magnitude of acceleration vector
  double _calculateMagnitude(IMUReading reading) {
    return sqrt(
      reading.accelX * reading.accelX +
          reading.accelY * reading.accelY +
          reading.accelZ * reading.accelZ,
    );
  }

  /// Build sensor data display widget
  Widget _buildSensorData(String label, double x, double y, double z) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'X: ${x.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
        Text(
          'Y: ${y.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
        Text(
          'Z: ${z.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }
}
