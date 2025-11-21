import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/screens/auth/auth_screen.dart';
import 'package:newson/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';

import '../../data/models/remote_config_model.dart';
import '../../data/services/user_service.dart';
import '../../providers/remote_config_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showGif = false;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    // Delay showing the GIF with animation
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showGif = true;
        });
        _controller.forward();
      }
    });

    // Slide-up animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // slightly below
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  void _goNext() {
    // Check if user has a valid token (is logged in)
    final userService = UserService();
    final token = userService.getToken();
    
    if (token != null && token.isNotEmpty) {
      // User is logged in - route to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(selectedCategories: []),
        ),
      );
    } else {
      // User is not logged in - route to AuthScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
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
        final theme = Theme.of(context);

        return Scaffold(
          body: SafeArea(
            child: GestureDetector(
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: ListView(
                children: [
                  /// 🖼️ 1️⃣ Top Image Section with fade + slide animation
                  AnimatedOpacity(
                    opacity: _showGif ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    child: SlideTransition(
                      position: _offsetAnimation,
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        width: double.infinity,
                        child: showImage(
                          config.splashAnimatedGif!,
                          BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  /// 2️⃣ Center Welcome Text
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 12.0,
                        top: MediaQuery.of(context).size.height / 5.2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            config.splashWelcomeText,
                            style: GoogleFonts.playfair(
                              fontSize: config.splashWelcomeFontSize,
                              fontWeight: config.splashWelcomeFontWeightValue,
                              color: theme.colorScheme.secondary,

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
                  ),

                  giveHeight(32),

                  /// 3️⃣ Bottom Swipe Button
                  _SwipeCta(config: config, onTap: _goNext),

                  giveHeight(32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        thumb: const Icon(Icons.double_arrow_rounded, color: Colors.white),
        activeThumbColor: primaryColor,
        activeTrackColor: const Color(0xFF4A4A4A),
        onSwipe: onTap,
        height: config.splashButtonHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0),
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
      ),
    );
  }
}
