import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Screen showing the AI analysis result (True Positive or False Positive)
class AnalysisResultScreen extends StatefulWidget {
  final bool isIncident;
  final String description;
  final String triggerSource;
  final String transcript;
  final VoidCallback? onDismiss; // Called when user dismisses the screen

  const AnalysisResultScreen({
    super.key,
    required this.isIncident,
    required this.description,
    required this.triggerSource,
    this.transcript = '',
    this.onDismiss,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isIncident
          ? AppTheme.alertRed.withOpacity(0.95)
          : Colors.green.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40), // Add top padding
                    // Animated Icon
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isIncident
                                  ? Icons.shield
                                  : Icons.check_circle,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Result Text
                    AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                widget.isIncident
                                    ? 'INCIDENT DETECTED'
                                    : 'FALSE POSITIVE',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 16),

                              // Trigger source
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Text(
                                  'Trigger: ${widget.triggerSource}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Transcript from Gemini (if available)
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
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '"${widget.transcript}"',
                                    style: const TextStyle(
                                      fontSize: 14,
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
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  widget.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Action indicator (only for true positive)
                              if (widget.isIncident)
                                Text(
                                  'Creating incident report...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24), // Bottom padding
                  ],
                ),
              ),
            ),

            // Fixed OK Button at bottom (only for false positive)
            if (!widget.isIncident)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismiss?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
