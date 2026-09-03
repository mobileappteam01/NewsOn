import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/utils/shared_functions.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';
import '../auth/auth_screen.dart';
import '../home/home_screen.dart';

/// Cold-start splash for users who already have a valid session.
///
/// Logo is visible on the first frame (matches native launch), then a short
/// polish animation plays before routing to [HomeScreen].
class AuthenticatedLogoSplash extends StatefulWidget {
  const AuthenticatedLogoSplash({super.key});

  @override
  State<AuthenticatedLogoSplash> createState() =>
      _AuthenticatedLogoSplashState();
}

class _AuthenticatedLogoSplashState extends State<AuthenticatedLogoSplash>
    with SingleTickerProviderStateMixin {
  static const Duration _minDisplay = Duration(milliseconds: 850);
  static const Duration _maxWaitForBootstrap = Duration(seconds: 8);

  bool _didNavigate = false;
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    // Subtle in-place animation — never start at opacity 0 (that looked blank).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
      unawaited(_finishStartup());
    });
  }

  /// Session is already loaded in [main]; delay is visual only.
  Future<void> _finishStartup() async {
    final started = DateTime.now();

    if (DeepLinkService.instance.hasPendingArticle) {
      await AppBootstrap.waitForReady(timeout: _maxWaitForBootstrap);
    }

    final elapsed = DateTime.now().difference(started);
    final remaining = _minDisplay - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _resolveBrightness(context);
    final isDark = brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF121212) : Colors.white;
    final logoAsset = isDark ? kNewsOnDarkLogoAsset : kNewsOnLogoAsset;
    final overlay =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.08 * _glow.value),
                        blurRadius: 28 * _glow.value,
                        spreadRadius: 2 * _glow.value,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              logoAsset,
              width: 168,
              height: 168,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
