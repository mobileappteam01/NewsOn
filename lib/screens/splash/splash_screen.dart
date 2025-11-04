import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/screens/auth/auth_screen.dart';
import 'package:provider/provider.dart';
import '../../data/models/remote_config_model.dart';
import '../../providers/remote_config_provider.dart';
import '../onboarding/onboarding_screen.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  void _goNext() {
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    // );
    Navigator.push(context, MaterialPageRoute(builder: (context)=> const AuthScreen()));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Navigate on a right-to-left swipe with some velocity
    if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
      _goNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final primaryColor = config.primaryColorValue;
        final textColor = config.textPrimaryColorValue;

        return Scaffold(
          backgroundColor: config.backgroundColorValue,
          body: SafeArea(
            child: GestureDetector(
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: Stack(
                children: [
                  // Debug: Refresh button (remove in production)

                  // Centered welcome text near the bottom like the mock
                  Align(
                    alignment: const Alignment(0.8, 0.50),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          config.splashWelcomeText,
                          style: GoogleFonts.playfair(
                            fontSize: config.splashWelcomeFontSize,
                            fontWeight: config.splashWelcomeFontWeightValue,
                            color: textColor,
                            letterSpacing: config.splashWelcomeLetterSpacing,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        giveHeight(6),
                        Text(
                          config.appName,
                          style: GoogleFonts.playfair(
                            fontSize: config.splashAppNameFontSize,
                            fontWeight: config.splashAppNameFontWeightValue,
                            color: primaryColor,
                            letterSpacing: config.splashAppNameLetterSpacing,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Bottom CTA pill
                  Align(
                    alignment: const Alignment(0, 0.92),
                    child: _SwipeCta(config: config, onTap: _goNext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SwipeCta extends StatelessWidget {
  final RemoteConfigModel config;
  final VoidCallback onTap;

  const _SwipeCta({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primaryColor = config.primaryColorValue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SwipeButton(
        thumb: Icon(Icons.double_arrow_rounded, color: Colors.white),
        activeThumbColor: Colors.red,
        activeTrackColor: const Color(0xFF4A4A4A),
        onSwipe: () {
          onTap();
        },
        height: config.splashButtonHeight,
         
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              config.splashSwipeText,
              style: TextStyle(
                color: Colors.white,
                fontSize: config.splashSwipeFontSize,
                fontWeight: config.splashSwipeFontWeightValue,
              ),
            ), 
            Row(
              children: [
                Icon(Icons.chevron_right, color: primaryColor),
                Icon(Icons.chevron_right, color: primaryColor),
                Icon(Icons.chevron_right, color: primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
