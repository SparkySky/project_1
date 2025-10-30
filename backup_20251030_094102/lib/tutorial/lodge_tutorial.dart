import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lodge Tutorial Overlay Widget
class LodgeTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  final ScrollController? pageScrollController;

  const LodgeTutorial({
    super.key,
    required this.onComplete,
    this.pageScrollController,
  });

  @override
  State<LodgeTutorial> createState() => _LodgeTutorialState();
}

class _LodgeTutorialState extends State<LodgeTutorial>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final bool _isHidden = false;
  late AnimationController _arrowAnimationController;

  List<TutorialStep> get _steps {
    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom; // System navigation bar
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    return [
      TutorialStep(
        title: "Report an Incident",
        description: "Learn how to quickly report incidents you witness.",
        highlightArea: null,
        position: TutorialPosition.center,
        scrollToPosition: 0,
      ),
      TutorialStep(
        title: "Location",
        description:
            "Auto-filled with your current location. Tap the map to change it.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 80 - 6,
          height: 470,
        ),
        position: TutorialPosition.bottom,
        scrollToPosition: 50,
      ),
      TutorialStep(
        title: "Incident Type",
        description: "General = routine incidents\nThreat = emergencies",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 310 - 12,
          height: 170,
        ),
        position: TutorialPosition.top,
        scrollToPosition: 290,
      ),
      TutorialStep(
        title: "Description",
        description:
            "Describe what happened. Be specific to help others stay safe.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 440 - 18,
          height: 260,
        ),
        position: TutorialPosition.top,
        scrollToPosition: 320,
      ),
      TutorialStep(
        title: "AI Title Generator",
        description:
            "Write description first, then tap ✨ to auto-generate a title.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 560 - 24,
          height: 145,
        ),
        position: TutorialPosition.center,
        scrollToPosition: 450,
      ),
      TutorialStep(
        title: "Attach Media",
        description: "Add photos, videos, or audio to support your report.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 400 - 30,
          height: 280,
        ),
        position: TutorialPosition.top,
        scrollToPosition: 750,
      ),
      TutorialStep(
        title: "Submit Report",
        description:
            "Tap Submit to share your incident. It will appear on the Homepage for others to see.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 590 - 36,
          height: 120,
        ),
        position: TutorialPosition.center,
        scrollToPosition: 850,
      ),
      // Auto-lodge explanation
      TutorialStep(
        title: "AI Auto-Lodge",
        description:
            "If AI detects emergency sounds (screams, breaking glass) or sudden phone impact, we auto-report it.\n\n"
            "Here's how it works:",
        highlightArea: null,
        position: TutorialPosition.center,
        scrollToPosition: 0,
        screenshots: [
          'assets/images/AI_lodge1.jpg',
          'assets/images/AI_lodge2.jpg',
          'assets/images/AI_lodge3.jpg',
          'assets/images/AI_lodge4.jpg',
        ],
      ),
      // Guide to Profile page
      TutorialStep(
        title: "Great Job! 🎉",
        description:
            "Next, explore your Profile settings. Tap 'Profile' below to continue.",
        highlightArea: HighlightArea(
          top: screenHeight - bottomPadding - 126,
          height: 65,
          left: screenWidth / 4 * 3 + 10, // Fourth button (index 3)
          width: screenWidth / 4 - 15,
        ),
        position: TutorialPosition.top,
        scrollToPosition: 0,
        requireUserTap: true,
        interactionType: InteractionType.navigateToProfile,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Auto-scroll to current step's position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToCurrentStep();
    });
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  void _animateToCurrentStep() {
    // Scroll to the current step's position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentStep();
    });
  }

  void _scrollToCurrentStep() {
    if (widget.pageScrollController != null && _currentStep < _steps.length) {
      final step = _steps[_currentStep];
      if (step.scrollToPosition > 0) {
        widget.pageScrollController!.animateTo(
          step.scrollToPosition,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animateToCurrentStep();
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animateToCurrentStep();
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lodge_tutorial_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_isHidden) {
      return const SizedBox.shrink();
    }

    final currentStep = _steps[_currentStep];

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

          // Animated arrow outside the button (for last step)
          if (currentStep.requireUserTap && currentStep.highlightArea != null)
            Positioned(
              left: (currentStep.highlightArea!.left ?? 0) + 10,
              top:
                  currentStep.highlightArea!.top -
                  90, // Position above the button
              child: IgnorePointer(
                ignoring: true, // Arrow should never block pointer events
                child: AnimatedBuilder(
                  animation: _arrowAnimationController,
                  builder: (context, child) {
                    // Calculate animation offset (move down toward button)
                    double animationOffset =
                        _arrowAnimationController.value * 10;

                    return Transform.translate(
                      offset: Offset(0, animationOffset),
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
                          // Animated arrow - point down to button
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
                  // User tapped the profile button
                  _completeTutorial();
                },
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

          // Tutorial card
          _buildTutorialCard(currentStep),
        ],
      ),
    );
  }

  // Helper method to build individual screenshot
  Widget _buildScreenshot(
    String imagePath,
    int stepNumber,
    String description,
  ) {
    return Column(
      children: [
        Container(
          width: 160,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(imagePath, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Text(
            'Step $stepNumber',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 160,
          child: Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialCard(TutorialStep step) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final bottomPadding = mediaQuery.padding.bottom;

    Widget card = Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03, // 3% of screen width
        vertical: 8,
      ),
      padding: EdgeInsets.all(screenWidth * 0.04), // 4% of screen width
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75, // Use 75% of screen height
        maxWidth: screenWidth * 0.94, // Use 94% of screen width
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
          // Scrollable content area
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator
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
                    textAlign: TextAlign.center,
                  ),

                  // Screenshots (if any) - 2x2 Grid
                  if (step.screenshots != null &&
                      step.screenshots!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image 1 - Top Left
                        _buildScreenshot(
                          step.screenshots![0],
                          1,
                          'AI detects potential emergency',
                        ),
                        const SizedBox(width: 12),
                        // Image 2 - Top Right
                        _buildScreenshot(
                          step.screenshots![1],
                          2,
                          '15s countdown - tap False Alarm to cancel',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bottom row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image 3 - Bottom Left
                        _buildScreenshot(
                          step.screenshots![2],
                          3,
                          'AI lodges & submits incident report automatically',
                        ),
                        const SizedBox(width: 12),
                        // Image 4 - Bottom Right
                        _buildScreenshot(
                          step.screenshots![3],
                          4,
                          'Emergency mode activated',
                        ),
                      ],
                    ),
                  ],

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
                            Text(
                              'Tap the highlighted button to continue',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600,
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

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button
              TextButton(
                onPressed: _skipTutorial,
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),

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

// Tutorial step model
class TutorialStep {
  final String title;
  final String description;
  final HighlightArea? highlightArea;
  final TutorialPosition position;
  final double scrollToPosition;
  final bool requireUserTap;
  final InteractionType? interactionType;
  final List<String>? screenshots;

  TutorialStep({
    required this.title,
    required this.description,
    this.highlightArea,
    required this.position,
    this.scrollToPosition = 0,
    this.requireUserTap = false,
    this.interactionType,
    this.screenshots,
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

// Interaction types
enum InteractionType { navigateToProfile }

// Tutorial Manager for Lodge Page
class LodgeTutorialManager {
  static const String _tutorialKey = 'lodge_tutorial_completed';

  // Check if user has completed tutorial
  static Future<bool> hasCompletedTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialKey) ?? false;
  }

  // Reset tutorial (for replay)
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, false);
  }

  // Show tutorial if not completed
  static Future<void> showTutorialIfNeeded(BuildContext context) async {
    final completed = await hasCompletedTutorial();
    if (!completed && context.mounted) {
      showTutorial(context);
    }
  }

  // Force show tutorial (for replay)
  static void showTutorial(
    BuildContext context, {
    ScrollController? pageScrollController,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => LodgeTutorial(
        onComplete: () {
          Navigator.of(context).pop();
        },
        pageScrollController: pageScrollController,
      ),
    );
  }
}
