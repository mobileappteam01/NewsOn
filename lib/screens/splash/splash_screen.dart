import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:newson/screens/auth/auth_screen.dart';
import 'package:newson/screens/home/home_screen.dart';
import 'package:newson/screens/splash/authenticated_logo_splash.dart';
import 'package:provider/provider.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/user_service.dart';
import '../../providers/remote_config_provider.dart';

/// App cold-start entry.
///
/// - Logged in → [AuthenticatedLogoSplash] → Home
/// - Logged out / first install → existing Get Started splash → Auth
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Session is loaded in main() before runApp — decide once, no welcome flash.
    if (UserService().isLoggedIn) {
      return const AuthenticatedLogoSplash();
    }
    return const _LoggedOutSplashScreen();
  }
}

/// Existing first-install / signed-out splash (unchanged behavior).
class _LoggedOutSplashScreen extends StatefulWidget {
  const _LoggedOutSplashScreen();

  @override
  State<_LoggedOutSplashScreen> createState() => _LoggedOutSplashScreenState();
}

class _LoggedOutSplashScreenState extends State<_LoggedOutSplashScreen>
    with SingleTickerProviderStateMixin {
  bool _didNavigate = false;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Paint splash content on the first frame — do not wait a frame to start.
    _controller.value = 0.35;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });

    if (DeepLinkService.instance.hasPendingArticle) {
      unawaited(_goNextWhenReady());
    }
  }

  Future<void> _goNextWhenReady() async {
    await AppBootstrap.waitForReady(timeout: const Duration(seconds: 12));
    if (!mounted || _didNavigate) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || _didNavigate) return;
    _goNext();
  }

  void _goNext() {
    if (_didNavigate || !mounted) return;
    _didNavigate = true;

    final token = UserService().getToken();

    if (token != null && token.isNotEmpty) {
      // Defensive: session appeared after this screen opened.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(selectedCategories: []),
        ),
      );
      if (DeepLinkService.instance.hasPendingArticle) {
        DeepLinkService.instance.processPendingLink(navigationReady: true);
      }
    } else {
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
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: GestureDetector(
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: ListView(
                children: [
                  SlideTransition(
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
                          : ColoredBox(
                              color: theme.scaffoldBackgroundColor,
                              child: Center(
                                child: Image.asset(
                                  kNewsOnLogoAsset,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                    ),
                  ),
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
                              letterSpacing: config.splashWelcomeLetterSpacing,
                            ),
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
                              letterSpacing: config.splashAppNameLetterSpacing,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  giveHeight(44),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goNext,
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
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                                const Icon(
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
