import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Navigate on a right-to-left swipe with some velocity
    if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
      _goNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryRed = AppTheme.primaryRed;
    final textColor = Colors.black87;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Stack(
            children: [
              // Centered welcome text near the bottom like the mock
              Align(
                alignment: const Alignment(0, 0.45),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WELCOME TO',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'NEWSON',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: primaryRed,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Bottom CTA pill
              Align(
                alignment: const Alignment(0, 0.92),
                child: _SwipeCta(
                  primaryRed: primaryRed,
                  onTap: _goNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeCta extends StatelessWidget {
  final Color primaryRed;
  final VoidCallback onTap;

  const _SwipeCta({
    required this.primaryRed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          height: 64,
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A), // dark grey like mock
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // Left circular red button with chevron
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: primaryRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Swipe To Get Started',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Right triple chevrons
              Row(
                children: [
                  Icon(Icons.chevron_right, color: primaryRed),
                  Icon(Icons.chevron_right, color: primaryRed),
                  Icon(Icons.chevron_right, color: primaryRed),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
