import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';
import '../auth/auth_screen.dart';
import '../home/home_screen.dart';

/// Cold-start bridge for users who already have a valid session.
///
/// Session is loaded in [main] before [runApp]. This widget paints a solid
/// background matching the Android system splash (no second logo / animation),
/// then routes to [HomeScreen] on the first frame.
class AuthenticatedLogoSplash extends StatefulWidget {
  const AuthenticatedLogoSplash({super.key});

  @override
  State<AuthenticatedLogoSplash> createState() =>
      _AuthenticatedLogoSplashState();
}

class _AuthenticatedLogoSplashState extends State<AuthenticatedLogoSplash> {
  static const Duration _maxWaitForBootstrap = Duration(seconds: 8);

  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_finishStartup());
    });
  }

  /// Session is already loaded in [main]; no visual hold.
  Future<void> _finishStartup() async {
    if (DeepLinkService.instance.hasPendingArticle) {
      await AppBootstrap.waitForReady(timeout: _maxWaitForBootstrap);
    }

    if (!mounted || _didNavigate) return;
    _goHome();
  }

  void _goHome() {
    if (_didNavigate || !mounted) return;
    _didNavigate = true;

    if (!UserService().canBrowseWithoutAccount) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            const HomeScreen(selectedCategories: []),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );

    if (DeepLinkService.instance.hasPendingArticle) {
      DeepLinkService.instance.processPendingLink(navigationReady: true);
    }
  }

  Brightness _resolveBrightness(BuildContext context) {
    switch (StorageService.getThemeMode()) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      default:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _resolveBrightness(context);
    final isDark = brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF121212) : Colors.white;
    final overlay =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    // Solid color only — avoids a second Flutter logo after the system splash.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: const SizedBox.shrink(),
      ),
    );
  }
}
