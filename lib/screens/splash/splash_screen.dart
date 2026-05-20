import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/screens/auth/auth_screen.dart';
import 'package:newson/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';

import '../../data/services/deep_link_service.dart';
import '../../data/services/user_service.dart';
import '../../providers/remote_config_provider.dart';
// Uncomment to use dynamic app icon:
// import '../../core/widgets/dynamic_app_icon.dart';

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

    // Share link cold start: skip swipe — go to login or article immediately.
    if (DeepLinkService.instance.hasPendingArticle) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _goNext();
      });
    }
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
      if (DeepLinkService.instance.hasPendingArticle) {
        DeepLinkService.instance.processPendingLink();
      }
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
                        child: config.splashAnimatedGif != null &&
                                config.splashAnimatedGif!.isNotEmpty
                            ? showImage(
                                config.splashAnimatedGif,
                                BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Icon(
                                    Icons.newspaper,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
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
                            LocalizationHelper.welcomeTo(context),
                            style: GoogleFonts.roboto(
                              fontSize: config.splashWelcomeFontSize,
                              fontWeight: config.splashWelcomeFontWeightValue,
                              color: theme.colorScheme.secondary,
                            ).copyWith(
                                letterSpacing:
                                    config.splashWelcomeLetterSpacing),
                            textAlign: TextAlign.center,
                          ),
                          giveHeight(6),
                          Text(
                            LocalizationHelper.appName(context),
                            style: GoogleFonts.roboto(
                              fontSize: config.splashAppNameFontSize,
                              fontWeight: config.splashAppNameFontWeightValue,
                              color: primaryColor,
                            ).copyWith(
                                letterSpacing:
                                    config.splashAppNameLetterSpacing),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  giveHeight(32),

                  /// 3️⃣ Bottom Swipe Button
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(horizontal: 12),
                  //   child: SwipeButton.expand(
                  //     thumb: const Icon(
                  //       Icons.chevron_right,
                  //       color: Colors.white,
                  //       size: 28,
                  //     ),
                  //     activeThumbColor: primaryColor,
                  //     activeTrackColor: const Color(0xFF4A4A4A),
                  //     onSwipe: _goNext,
                  //     child: Padding(
                  //       padding: const EdgeInsets.only(left: 24.0),
                  //       child: Text(
                  //         LocalizationHelper.swipeToGetStarted(context),
                  //         style: TextStyle(
                  //           color: Colors.white,
                  //           fontSize: 14,
                  //           fontWeight: config.splashSwipeFontWeightValue,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  giveHeight(12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _goNext(),
                        borderRadius: BorderRadius.circular(50),
                        splashColor: Colors.white24,
                        highlightColor: Colors.white12,
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  LocalizationHelper.getStarted(context),
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                        config.splashSwipeFontWeightValue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

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
