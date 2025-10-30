import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

//   Tutorial Overlay Widget
class HomePageTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onFilterButtonTap;
  final VoidCallback? onNavigateToLodge;

  const HomePageTutorial({
    super.key,
    required this.onComplete,
    this.onFilterButtonTap,
    this.onNavigateToLodge,
  });

  @override
  State<HomePageTutorial> createState() => _HomePageTutorialState();
}

class _HomePageTutorialState extends State<HomePageTutorial>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isHidden = false; // To hide tutorial temporarily
  late AnimationController _arrowAnimationController;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  List<TutorialStep> get _steps {
    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = mediaQuery.padding.top;
    final bottomPadding =
        mediaQuery.padding.bottom; // System navigation bar height
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final bottomNavHeight = 56.0;

    // Calculate layout dimensions based on actual HomePage layout (responsive)
    final mapHeight = screenHeight * 0.41;
    final dragHandleHeight = 30.0;
    final safetyTriggerHeight = 100.0;

    // Manual tuning - adjust these values to fit your screen
    final filterButtonOffset =
        218; // Adjust this: 160-240 (190+13=203 was original)

    return [
      TutorialStep(
        title: "Welcome to MYSafeZone!",
        description:
            "Let's take a quick tour to show you how to stay safe with our app.",
        highlightArea: null,
        position: TutorialPosition.center,
      ),
      TutorialStep(
        title: "Permissions Needed",
        description:
            "For MYSafeZone to protect you 24/7, please grant:\n\n"
            "📍 Location (Always) - Share your location in emergencies and see nearby incidents\n\n"
            "🎤 Microphone (Always) - Detect emergency sounds like screams or breaking glass\n\n"
            "🔔 Notifications - Receive instant safety alerts\n\n"
            "⚡ Disable Battery Optimization - Keep protection running in the background\n\n"
            "Your privacy is protected. All data is kept secure.",
        highlightArea: null,
        position: TutorialPosition.center,
        isPermissionDialog: true,
      ),
      TutorialStep(
        title: "Your Safety Dashboard",
        description:
            "View the live map, see nearby incidents, and activate AI safety monitoring - all from this page.",
        highlightArea: null,
        position: TutorialPosition.center,
      ),
      TutorialStep(
        title: "Live Safety Map",
        description: "Blue marker = You\nRed markers = Nearby incidents",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight,
          height: mapHeight,
        ),
        position: TutorialPosition.bottom,
      ),
      TutorialStep(
        title: "AI Safety Monitor",
        description:
            "Tap ACTIVATE to enable safety monitoring. It detects threats like collisions, distress signals, and snatching, then alerts nearby users automatically.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + mapHeight + dragHandleHeight,
          height: safetyTriggerHeight,
        ),
        position: TutorialPosition.top,
      ),
      TutorialStep(
        title: "Incident Alerts",
        description:
            "Recent incidents in your area. Tap any card to see full details.",
        highlightArea: HighlightArea(
          top:
              appBarHeight +
              statusBarHeight +
              mapHeight +
              dragHandleHeight +
              safetyTriggerHeight,
          height:
              screenHeight -
              (appBarHeight + statusBarHeight) -
              mapHeight -
              dragHandleHeight -
              safetyTriggerHeight -
              bottomNavHeight -
              bottomPadding - // Account for system navigation
              60,
        ),
        position: TutorialPosition.top,
      ),
      // Explain filter BEFORE asking user to tap
      TutorialStep(
        title: "Filter & Sort",
        description:
            "Filter by status, distance, or type. Sort by time or distance.",
        highlightArea: HighlightArea(
          top:
              screenHeight -
              bottomNavHeight -
              bottomPadding -
              filterButtonOffset,
          height: 56,
          left: screenWidth - 72,
          width: 56,
        ),
        position: TutorialPosition.top,
        requireUserTap: true,
        interactionType: InteractionType.filter,
      ),
      // Final step - guide to Lodge page
      TutorialStep(
        title: "Great Job! 🎉",
        description:
            "Next, learn how to report incidents. Tap 'Lodge' below to continue.",
        highlightArea: HighlightArea(
          top: screenHeight - bottomNavHeight - bottomPadding - 94 - 35 + 60,
          height: bottomNavHeight + 10,
          left: screenWidth / 4 * 1, // Second button (Lodge - index 1)
          width: screenWidth / 4,
        ),
        position: TutorialPosition.top,
        requireUserTap: true,
        interactionType: InteractionType.navigateToLodge,
      ),
    ];
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  void _handleInteraction(InteractionType? type) {
    if (type == null) return;

    // Hide tutorial temporarily
    setState(() {
      _isHidden = true;
    });

    // Wait a moment then trigger the actual feature
    Future.delayed(const Duration(milliseconds: 100), () async {
      switch (type) {
        case InteractionType.filter:
          widget.onFilterButtonTap?.call();
          // Move to next step IMMEDIATELY - explanation will show with dialog open
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                _isHidden = false;
              });
              _nextStep();
            }
          });
          break;
        case InteractionType.navigateToLodge:
          // Complete tutorial - the onTutorialComplete callback will handle navigation

          _completeTutorial();
          break;
      }
    });
  }

  Future<void> _completeTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('homepage_tutorial_completed', true);
      widget.onComplete();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    // Don't render anything when hidden
    if (_isHidden) {
      return const SizedBox.shrink();
    }

    final currentStep = _steps[_currentStep];
    final screenHeight = MediaQuery.of(context).size.height;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay with cutout for highlighted area
          if (currentStep.highlightArea != null)
            CustomPaint(
              painter: SpotlightPainter(
                highlightRect: Rect.fromLTWH(
                  currentStep.highlightArea!.left ?? 0,
                  currentStep.highlightArea!.top,
                  currentStep.highlightArea!.width ??
                      MediaQuery.of(context).size.width,
                  currentStep.highlightArea!.height,
                ),
              ),
              size: Size.infinite,
            )
          else
            Container(color: Colors.black54),

          // Animated arrow outside the button (not blocking it)
          if (currentStep.requireUserTap && currentStep.highlightArea != null)
            Positioned(
              left: currentStep.interactionType == InteractionType.filter
                  ? (currentStep.highlightArea!.left ?? 0) -
                        10 // Position left of filter button
                  : (currentStep.highlightArea!.left ?? 0) +
                        10, // Position left for lodge button
              top: currentStep.interactionType == InteractionType.filter
                  ? currentStep.highlightArea!.top -
                        80 // Position higher above filter button
                  : currentStep.highlightArea!.top -
                        80, // Position above lodge button
              child: IgnorePointer(
                ignoring: true, // Arrow should never block pointer events
                child: AnimatedBuilder(
                  animation: _arrowAnimationController,
                  builder: (context, child) {
                    // Calculate animation offset
                    double animationOffset =
                        _arrowAnimationController.value * 10;

                    return Transform.translate(
                      offset: Offset(0, -animationOffset), // Move up
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tap here text with orange text color
                          Text(
                            'Tap here',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Animated arrow - points down to buttons
                          const Icon(
                            Icons.arrow_downward,
                            color: Colors.orange,
                            size: 40,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Transparent tap detector for interactive steps (on the actual button)
          if (currentStep.requireUserTap && currentStep.highlightArea != null)
            Positioned(
              left: currentStep.highlightArea!.left ?? 0,
              top: currentStep.highlightArea!.top,
              width:
                  currentStep.highlightArea!.width ??
                  MediaQuery.of(context).size.width,
              height: currentStep.highlightArea!.height,
              child: GestureDetector(
                onTap: () {
                  // User tapped the highlighted area, trigger real interaction
                  _handleInteraction(currentStep.interactionType);
                },
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

          // Tutorial card
          _buildTutorialCard(currentStep, screenHeight),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(TutorialStep step, double screenHeight) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    Widget card = Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05, // 5% of screen width
        vertical: 8,
      ),
      padding: EdgeInsets.all(screenWidth * 0.05), // 5% of screen width
      constraints: BoxConstraints(
        maxWidth: screenWidth * 0.9, // Max 90% of screen width
        maxHeight: screenHeight * 0.6, // Max 60% of screen height
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator (always visible at top)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _steps.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentStep
                      ? Colors.orange
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable content area
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    textAlign: step.isPermissionDialog
                        ? TextAlign.left
                        : TextAlign.center,
                  ),

                  // Special instruction for interactive steps
                  if (step.requireUserTap)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.touch_app,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Tap the highlighted button to continue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w600,
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
          ),

          const SizedBox(height: 20),

          // Navigation buttons (always visible at bottom)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button (hide on welcome step and permission dialog)
              if (_currentStep > 0 && !step.isPermissionDialog)
                TextButton(
                  onPressed: _skipTutorial,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                )
              else
                const SizedBox(width: 70), // Placeholder for alignment
              // Back button (hide for interactive steps)
              if (_currentStep > 0 && !step.requireUserTap)
                OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(color: Colors.orange),
                  ),
                )
              else
                const SizedBox(width: 70),

              // Next/Done button (only show for non-interactive steps)
              if (!step.requireUserTap)
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _currentStep < _steps.length - 1 ? 'Next' : 'Got it!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox(width: 70), // Placeholder for alignment
            ],
          ),
        ],
      ),
    );

    // Position the card based on highlighted area (responsive)
    if (step.position == TutorialPosition.center) {
      return Center(child: card);
    } else if (step.position == TutorialPosition.top) {
      return Positioned(
        top: screenHeight * 0.1, // 10% from top
        left: 0,
        right: 0,
        child: card,
      );
    } else {
      // Bottom position - account for system navigation
      return Positioned(
        bottom: bottomPadding + 100, // Above system nav + buffer
        left: 0,
        right: 0,
        child: card,
      );
    }
  }
}

// Custom painter for spotlight effect with cutout
class SpotlightPainter extends CustomPainter {
  final Rect highlightRect;

  SpotlightPainter({required this.highlightRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    // Create path with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(highlightRect, const Radius.circular(12)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw border around highlighted area
    final borderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect;
  }
}

// Interaction types
enum InteractionType { filter, navigateToLodge }

// Tutorial step model
class TutorialStep {
  final String title;
  final String description;
  final HighlightArea? highlightArea;
  final TutorialPosition position;
  final bool requireUserTap;
  final InteractionType? interactionType;
  final bool showAfterDialog;
  final bool isPermissionDialog;

  TutorialStep({
    required this.title,
    required this.description,
    this.highlightArea,
    required this.position,
    this.requireUserTap = false,
    this.interactionType,
    this.showAfterDialog = false,
    this.isPermissionDialog = false,
  });
}

class HighlightArea {
  final double top;
  final double height;
  final double? left;
  final double? width;

  HighlightArea({
    required this.top,
    required this.height,
    this.left,
    this.width,
  });
}

enum TutorialPosition { top, bottom, center }

// Tutorial Manager for HomePage
class HomePageTutorialManager {
  static const String _tutorialKey = 'homepage_tutorial_completed';

  // Check if user has completed tutorial
  static Future<bool> hasCompletedTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialKey) ?? false;
  }

  // Reset tutorial (for replay from profile)
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, false);
  }

  // Show tutorial if not completed
  static Future<void> showTutorialIfNeeded(
    BuildContext context, {
    VoidCallback? onFilterTap,
    VoidCallback? onNavigateToLodge,
    VoidCallback? onTutorialComplete,
  }) async {
    final completed = await hasCompletedTutorial();
    if (!completed && context.mounted) {
      showTutorial(
        context,
        onFilterTap: onFilterTap,
        onNavigateToLodge: onNavigateToLodge,
        onTutorialComplete: onTutorialComplete,
      );
    }
  }

  // Force show tutorial (for replay)
  static void showTutorial(
    BuildContext context, {
    VoidCallback? onFilterTap,
    VoidCallback? onNavigateToLodge,
    VoidCallback? onTutorialComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => HomePageTutorial(
        onComplete: () {
          Navigator.of(context).pop();
          // Call the tutorial complete callback

          onTutorialComplete?.call();
        },
        onFilterButtonTap: onFilterTap,
        onNavigateToLodge: onNavigateToLodge,
      ),
    );
  }
}

// Add this widget to ProfilePage for tutorial replay
class TutorialReplayButton extends StatelessWidget {
  const TutorialReplayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.help_outline, color: Colors.orange),
        ),
        title: const Text(
          'View Tutorial',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Replay the home page walkthrough'),
        trailing: const Icon(Icons.play_circle_outline, color: Colors.orange),
        onTap: () async {
          await HomePageTutorialManager.resetTutorial();
          if (context.mounted) {
            // Navigate to home first if not already there
            Navigator.of(context).popUntil((route) => route.isFirst);
            // Tutorial will be shown automatically on HomePage
          }
        },
      ),
    );
  }
}
