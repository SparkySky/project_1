import 'package:flutter/material.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:project_1/homepage/homepage.dart';
import 'package:project_1/signup_login/auth_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Start the process to check the current user and navigate.
    _checkCurrentUser();
  }

  // This method checks the user's login status and navigates accordingly.
  Future<void> _checkCurrentUser() async {
    // Wait for the splash animation and for services to initialize.
    await Future.delayed(const Duration(seconds: 3));

    // Check if the widget is still in the tree before proceeding.
    if (!mounted) return;

    final AGCUser? user = await AGCAuth.instance.currentUser;

    // Check mounted again before navigating to avoid errors.
    if (!mounted) return;

    if (user != null) {
      // User is already logged in, go to the homepage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // User is not logged in, go to the authentication screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen(isLogin: true)),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/mysafezone_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // App Name
              const Text(
                'MYSafeZone',
                style: TextStyle(
                  fontFamily: 'Goldman',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color:  Color.fromARGB(255, 77, 57, 22),
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              // Tagline
              Text(
                'Your Safety, Our Priority',
                style: TextStyle(
                  fontFamily: 'Goldman',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}