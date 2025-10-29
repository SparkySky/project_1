import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChatbotInteractionType { sendMessage }

class ChatbotTutorialStep {
  final String title;
  final String description;
  final HighlightArea? highlightArea;
  final TutorialPosition position;
  final bool requireUserTap;
  final ChatbotInteractionType? interactionType;
  final double? scrollToPosition;

  ChatbotTutorialStep({
    required this.title,
    required this.description,
    this.highlightArea,
    required this.position,
    this.requireUserTap = false,
    this.interactionType,
    this.scrollToPosition,
  });
}

class HighlightArea {
  final double top;
  final double left;
  final double width;
  final double height;

  HighlightArea({
    required this.top,
    required this.left,
    required this.width,
    required this.height,
  });
}

enum TutorialPosition { top, bottom, center }

class ChatbotTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  final ScrollController? pageScrollController;
  final Function(String)? onSendMessage;

  const ChatbotTutorial({
    super.key,
    required this.onComplete,
    this.pageScrollController,
    this.onSendMessage,
  });

  @override
  State<ChatbotTutorial> createState() => _ChatbotTutorialState();
}

class _ChatbotTutorialState extends State<ChatbotTutorial>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isHidden = false;
  late AnimationController _arrowAnimationController;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Trigger initial scroll if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentStep();
    });
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  void _scrollToCurrentStep() {
    final step = _steps[_currentStep];
    if (step.scrollToPosition != null && widget.pageScrollController != null) {
      widget.pageScrollController!.animateTo(
        step.scrollToPosition!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  List<ChatbotTutorialStep> get _steps {
    return [
      // Single comprehensive explanation
      ChatbotTutorialStep(
        title: "MYSafeZone Assistant",
        description:
            "You can ask the assistant to summarize recent incidents in your area. Let's try it!",
        position: TutorialPosition.center,
      ),
    ];
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      // Scroll to new step if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentStep();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentStep();
      });
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chatbot_tutorial_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_isHidden) return const SizedBox.shrink();

    final currentStep = _steps[_currentStep];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay
          Container(color: Colors.black54),

          // Tutorial card
          _buildTutorialCard(currentStep),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(ChatbotTutorialStep step) {
    final screenHeight = MediaQuery.of(context).size.height;

    double topPosition;
    switch (step.position) {
      case TutorialPosition.top:
        topPosition = screenHeight * 0.1;
        break;
      case TutorialPosition.bottom:
        topPosition = screenHeight * 0.65;
        break;
      case TutorialPosition.center:
        topPosition = screenHeight * 0.35;
        break;
    }

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
          // Title
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            step.description,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button
              TextButton(
                onPressed: _skipTutorial,
                child: const Text(
                  'Skip',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),

              // Next button
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Positioned(top: topPosition, left: 0, right: 0, child: card);
  }
}

class OverlayPainter extends CustomPainter {
  final HighlightArea? highlightArea;

  OverlayPainter({this.highlightArea});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Draw full screen overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Cut out highlight area
    if (highlightArea != null) {
      final highlightPaint = Paint()
        ..color = Colors.transparent
        ..blendMode = BlendMode.clear;

      final rect = Rect.fromLTWH(
        highlightArea!.left,
        highlightArea!.top,
        highlightArea!.width,
        highlightArea!.height,
      );

      canvas.drawRect(rect, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) {
    return oldDelegate.highlightArea != highlightArea;
  }
}

class ChatbotTutorialManager {
  static const String _tutorialKey = 'chatbot_tutorial_completed';

  static Future<bool> hasCompletedTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialKey) ?? false;
  }

  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, false);
  }

  static void showTutorial(
    BuildContext context, {
    ScrollController? pageScrollController,
    Function(String)? onSendMessage,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => ChatbotTutorial(
        onComplete: () {
          Navigator.of(context).pop();
        },
        pageScrollController: pageScrollController,
        onSendMessage: onSendMessage,
      ),
    );
  }

  static Future<void> showTutorialIfNeeded(
    BuildContext context, {
    ScrollController? pageScrollController,
    Function(String)? onSendMessage,
  }) async {
    final completed = await hasCompletedTutorial();
    if (!completed && context.mounted) {
      showTutorial(
        context,
        pageScrollController: pageScrollController,
        onSendMessage: onSendMessage,
      );
    }
  }
}
