import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Profile Tutorial Overlay Widget
class ProfileTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  final ScrollController? pageScrollController;
  final VoidCallback? onCustomKeywordsTap;

  const ProfileTutorial({
    super.key,
    required this.onComplete,
    this.pageScrollController,
    this.onCustomKeywordsTap,
  });

  @override
  State<ProfileTutorial> createState() => _ProfileTutorialState();
}

class _ProfileTutorialState extends State<ProfileTutorial>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isHidden = false;
  late AnimationController _arrowAnimationController;

  List<TutorialStep> get _steps {
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return [
      TutorialStep(
        title: "Welcome to Your Profile!",
        description:
            "Let's explore your profile settings and learn how to customize your account.",
        highlightArea: null,
        position: TutorialPosition.center,
        scrollToPosition: 0,
      ),
      TutorialStep(
        title: "User Information",
        description:
            "Fill in your information including phone number and address. This information helps with location-based features.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 300,
          height: 400,
        ),
        position: TutorialPosition.top,
        scrollToPosition: 300,
      ),
      TutorialStep(
        title: "Voice Detection Language",
        description:
            "Select your preferred language for voice detection. This helps our AI better detect emergency sounds in your language.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 170,
          height: 420,
        ),
        position: TutorialPosition.bottom,
        scrollToPosition: 1000,
      ),
      TutorialStep(
        title: "Custom Emergency Keywords",
        description:
            "Tap 'Edit All Custom Keywords' to customize words that trigger the AI to detect emergency situations. This personalizes the safety detection for your needs.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 500,
          height: 80,
        ),
        position: TutorialPosition.top,
        scrollToPosition: 1080,
        requireUserTap: true,
        interactionType: InteractionType.customKeywords,
      ),
      TutorialStep(
        title: "Privacy & Alert Preferences",
        description:
            "Enable 'Allow Discoverable' to let other users find you in the app, and 'Allow Emergency Alerts' to receive notifications about nearby incidents.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 160,
          height: 200,
        ),
        position: TutorialPosition.bottom,
        scrollToPosition: 1500,
      ),
      TutorialStep(
        title: "Tutorial Replays",
        description:
            "Need to review the tutorials? Tap here to replay the tutorials anytime.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 280,
          height: 180,
        ),
        position: TutorialPosition.bottom,
        scrollToPosition: 2200,
      ),
      TutorialStep(
        title: "Legal Section",
        description:
            "Access Terms & Conditions and Privacy Policy. These are important for your account security.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 150,
          height: 300,
        ),
        position: TutorialPosition.bottom,
        scrollToPosition: 2500,
      ),
      TutorialStep(
        title: "Tutorial Complete! 🎉",
        description:
            "Congratulations! You've completed all the tutorials. You now know how to use MYSafeZone. \n\nRemember, you can always replay these tutorials from your profile. Stay safe!",
        highlightArea: null,
        position: TutorialPosition.center,
        scrollToPosition: 0,
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

  void _handleInteraction(InteractionType? type) {
    print('[ProfileTutorial] _handleInteraction called with type: $type');
    if (type == null) return;

    // Hide tutorial temporarily
    setState(() {
      _isHidden = true;
    });

    // Wait a moment then trigger the actual feature
    Future.delayed(const Duration(milliseconds: 100), () {
      if (type == InteractionType.customKeywords) {
        print('[ProfileTutorial] Calling onCustomKeywordsTap callback');
        widget.onCustomKeywordsTap?.call();
      }

      // Move to next step after opening the dialog
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _isHidden = false;
          });
          _nextStep();
        }
      });
    });
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_tutorial_completed', true);
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

          // Animated arrow for interactive steps
          if (currentStep.requireUserTap && currentStep.highlightArea != null)
            Positioned(
              left:
                  (currentStep.highlightArea!.left ?? 0) +
                  (MediaQuery.of(context).size.width / 2 - 60),
              top: currentStep.highlightArea!.top - 80,
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedBuilder(
                  animation: _arrowAnimationController,
                  builder: (context, child) {
                    double animationOffset =
                        _arrowAnimationController.value * 10;

                    return Transform.translate(
                      offset: Offset(0, animationOffset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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

          // Transparent tap detector for interactive steps
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
                  print('[ProfileTutorial] Tap detected on highlighted area');
                  print(
                    '[ProfileTutorial] Callback is null: ${widget.onCustomKeywordsTap == null}',
                  );
                  _handleInteraction(currentStep.interactionType);
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

  Widget _buildTutorialCard(TutorialStep step) {
    Widget card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.orange, size: 20),
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

    // Position the card based on highlighted area
    if (step.position == TutorialPosition.center) {
      return Center(child: card);
    } else if (step.position == TutorialPosition.top) {
      return Positioned(top: 80, left: 0, right: 0, child: card);
    } else {
      // Bottom position
      return Positioned(bottom: 100, left: 0, right: 0, child: card);
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

  TutorialStep({
    required this.title,
    required this.description,
    this.highlightArea,
    required this.position,
    this.scrollToPosition = 0,
    this.requireUserTap = false,
    this.interactionType,
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
enum InteractionType { customKeywords }

// Tutorial Manager for Profile Page
class ProfileTutorialManager {
  static const String _tutorialKey = 'profile_tutorial_completed';

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
    VoidCallback? onCustomKeywordsTap,
    VoidCallback? onTutorialComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => ProfileTutorial(
        onComplete: () {
          Navigator.of(context).pop();
          onTutorialComplete?.call();
        },
        pageScrollController: pageScrollController,
        onCustomKeywordsTap: onCustomKeywordsTap,
      ),
    );
  }

  // Show reminder to fill in user information
  static void showFillInfoReminder(
    BuildContext context, {
    ScrollController? scrollController,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Complete Your Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please go to the Profile page and fill in your information in the User Information section.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This helps with location-based features and emergency contacts.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Scroll to user information section
              if (scrollController != null) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  scrollController.animateTo(
                    200.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Got it!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
