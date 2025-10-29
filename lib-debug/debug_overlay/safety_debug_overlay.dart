import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/safety_service_provider.dart';
import '../app_theme.dart';
import 'debug_state.dart';

/// Debug overlay showing real-time safety trigger system status
class SafetyDebugOverlay extends StatefulWidget {
  const SafetyDebugOverlay({super.key});

  @override
  State<SafetyDebugOverlay> createState() => _SafetyDebugOverlayState();
}

class _SafetyDebugOverlayState extends State<SafetyDebugOverlay> {
  final DebugState _debugState = DebugState();

  @override
  Widget build(BuildContext context) {
    return Consumer<SafetyServiceProvider>(
      builder: (context, provider, child) {
        if (!provider.isEnabled) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 100,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.85),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: provider.isEnabled ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SAFETY MONITOR DEBUG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // Turn off debug overlay
                          _debugState.setShowDebugOverlay(false);
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),

                  // Current Transcript
                  StreamBuilder<String>(
                    stream: provider.transcriptDebugStream,
                    initialData: '',
                    builder: (context, snapshot) {
                      final transcript = snapshot.data ?? '';
                      return _buildSection(
                        'LIVE TRANSCRIPT',
                        transcript.isEmpty ? 'Listening...' : transcript,
                        Icons.mic,
                        Colors.blue,
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // IMU Status
                  StreamBuilder<double>(
                    stream: provider.magnitudeDebugStream,
                    initialData: 0.0,
                    builder: (context, snapshot) {
                      final magnitude = snapshot.data ?? 0.0;
                      final isHigh = magnitude > 12.0;
                      final isMedium = magnitude > 5.0;

                      return _buildSection(
                        'IMU MAGNITUDE',
                        magnitude.toStringAsFixed(2),
                        Icons.vibration,
                        isHigh
                            ? Colors.red
                            : (isMedium ? Colors.orange : Colors.green),
                        subtitle: isHigh
                            ? '🚨 TRIGGER!'
                            : (isMedium ? '⚠️ High' : 'Normal'),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Trigger Status
                  if (provider.lastTrigger != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryOrange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.primaryOrange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last Trigger: ${provider.lastTrigger}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Statistics
                  Row(
                    children: [
                      Expanded(child: _buildStat('Keywords', '7', Icons.key)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStat('Threshold', '12.0', Icons.speed),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStat(
                          'Status',
                          provider.isEnabled ? 'ON' : 'OFF',
                          Icons.power_settings_new,
                        ),
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

  Widget _buildSection(
    String title,
    String value,
    IconData icon,
    Color iconColor, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
