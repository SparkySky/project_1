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
    debugPrint('[CaptureWindowOverlay] ═══════════════════════════');
    debugPrint('[CaptureWindowOverlay] 🎨 BUILD METHOD CALLED');
    debugPrint('[CaptureWindowOverlay] ═══════════════════════════');

    return Consumer<SafetyServiceProvider>(
      builder: (context, provider, child) {
        debugPrint('[CaptureWindowOverlay] 📦 Consumer builder called');
        debugPrint(
          '[CaptureWindowOverlay] lastTrigger: ${provider.lastTrigger}',
        );

        return Material(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Warning icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 80,
                        color: AppTheme.primaryOrange,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'ANALYZING INCIDENT',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Trigger source
                    if (provider.lastTrigger != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Trigger: ${provider.lastTrigger}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Progress bar
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
                              minHeight: 8,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_progressController.value * 8).toStringAsFixed(1)}s / 8.0s',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Status text
                    const Text(
                      'Recording audio and collecting sensor data...',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // IMU Data display
                    Container(
                      height: 200, // Fixed height with scroll
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IMU READINGS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // IMU Data Table
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: provider.captureWindowData.map((
                                  reading,
                                ) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(8),
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
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryOrange,
                                              ),
                                            ),
                                            Text(
                                              'Magnitude: ${_calculateMagnitude(reading).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
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
                                            const SizedBox(width: 8),
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

                    const SizedBox(height: 16),

                    // Audio Transcript Section
                    Container(
                      height: 120, // Fixed height with scroll
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AUDIO TRANSCRIPT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  provider.captureTranscript.isEmpty
                                      ? '🎙️ Recording audio...\n\n(Gemini will transcribe after 8 seconds)'
                                      : provider.captureTranscript,
                                  style: TextStyle(
                                    fontSize: 14,
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

                    const SizedBox(height: 24),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          debugPrint(
                            '[CaptureWindow] ❌ User cancelled capture',
                          );

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
                        icon: const Icon(Icons.cancel_outlined, size: 28),
                        label: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Info text
                    Text(
                      'Tap CANCEL to stop this capture immediately',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
