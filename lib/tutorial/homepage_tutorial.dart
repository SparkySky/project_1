import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// HomePage Tutorial Overlay Widget
class HomePageTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  
  const HomePageTutorial({
    super.key,
    required this.onComplete,
  });

  @override
  State<HomePageTutorial> createState() => _HomePageTutorialState();
}

class _HomePageTutorialState extends State<HomePageTutorial> {
  int _currentStep = 0;
  
  // Changed from final field to getter so we can access context
  List<TutorialStep> get _steps {
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomNavHeight = 56.0;
    
    return [
      TutorialStep(
        title: "Welcome to MYSafeZone!",
        description: "Let's take a quick tour to help you get started with our app.",
        highlightArea: null,
        position: TutorialPosition.center,
      ),
      TutorialStep(
        title: "This is MYSafeZone Home Page",
        description: "The main hub for monitoring safety in your area. Here you can view the live map, nearby incidents, and turn on / off the sound detector.",
        highlightArea: null,
        position: TutorialPosition.center,
      ),
      TutorialStep(
        title: "Live Safety Map",
        description: "This map shows your current location (blue marker) and nearby incidents (red markers).",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight,
          height: 250,
        ),
        position: TutorialPosition.bottom,
      ),
      TutorialStep(
        title: "Sound Detector",
        description: "Turn this ON to actively monitor sounds around you. The app uses AI to detect potential threats like screams, gunshots, or breaking glass and sends incident alerts to people nearby.",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 250,
          height: 120,
        ),
        position: TutorialPosition.center,
        // Note: We can't highlight just the right 1/4 with current HighlightArea structure
        // The CustomPaint uses full width. You'd need to modify HighlightArea and SpotlightPainter
        // to support left/width parameters if you want partial width highlighting
      ),
      TutorialStep(
        title: "Nearby Incidents List",
        description: "Scroll through recent incidents reported in your postcode area. Each incident shows:\n• Type of incident\n• Time it occurred\n• Exact location",
        highlightArea: HighlightArea(
          top: appBarHeight + statusBarHeight + 250 + 80,
          height: screenHeight - 
                  (appBarHeight + statusBarHeight) - // Top bar
                  250 - // Map height
                  80 - // Header section with "Nearby Incidents"
                  bottomNavHeight, // Bottom navigation
        ),
        position: TutorialPosition.top,
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

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('homepage_tutorial_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
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
                  0,
                  currentStep.highlightArea!.top,
                  MediaQuery.of(context).size.width,
                  currentStep.highlightArea!.height,
                ),
              ),
              size: Size.infinite,
            )
          else
            Container(color: Colors.black54),
          
          // Tutorial card
          _buildTutorialCard(currentStep, screenHeight),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(TutorialStep step, double screenHeight) {
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
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              
              // Back button
              if (_currentStep > 0)
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
              
              // Next/Done button
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
              ),
            ],
          ),
        ],
      ),
    );

    // Position the card based on highlighted area
    if (step.position == TutorialPosition.center) {
      return Center(child: card);
    } else if (step.position == TutorialPosition.top) {
      return Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: card,
      );
    } else {
      // Bottom position
      return Positioned(
        bottom: 100,
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
      ..addRRect(RRect.fromRectAndRadius(
        highlightRect,
        const Radius.circular(12),
      ))
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(path, paint);
    
    // Draw border around highlighted area
    final borderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        highlightRect,
        const Radius.circular(12),
      ),
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

  TutorialStep({
    required this.title,
    required this.description,
    this.highlightArea,
    required this.position,
  });
}

class HighlightArea {
  final double top;
  final double height;

  HighlightArea({required this.top, required this.height});
}

enum TutorialPosition {
  top,
  bottom,
  center,
}

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
  static Future<void> showTutorialIfNeeded(BuildContext context) async {
    final completed = await hasCompletedTutorial();
    if (!completed && context.mounted) {
      showTutorial(context);
    }
  }

  // Force show tutorial (for replay)
  static void showTutorial(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => HomePageTutorial(
        onComplete: () {
          Navigator.of(context).pop();
        },
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
            // Then show tutorial
            HomePageTutorialManager.showTutorial(context);
          }
        },
      ),
    );
  }
}