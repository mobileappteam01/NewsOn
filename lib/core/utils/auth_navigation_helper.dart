import 'package:flutter/material.dart';

import '../../data/services/deep_link_service.dart';
import '../../data/services/user_service.dart';
import '../../core/navigation/app_navigator.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';

/// Routes the user after OAuth sign-up/sign-in based on [isNewUser].
void navigateAfterOAuthAuth(
  BuildContext context, {
  required bool isNewUser,
}) {
  final Widget next = isNewUser
      ? const OnboardingScreen()
      : const HomeScreen(selectedCategories: []);

  // Clear guest Home / Auth stack so a single session root remains.
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => next),
    (route) => false,
  );

  if (!isNewUser && DeepLinkService.instance.hasPendingArticle) {
    DeepLinkService.instance.processPendingLink(navigationReady: true);
  }
}

/// iOS guest browse: open Home without an account (Guideline 5.1.1(v)).
Future<void> navigateAsGuestBrowse(BuildContext context) async {
  await UserService().enableGuestBrowse();
  if (!context.mounted) return;

  // If Auth was pushed on top of Home (guest tapped Save / Saved / Settings),
  // just dismiss Auth and keep browsing.
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => const HomeScreen(selectedCategories: []),
    ),
  );

  if (DeepLinkService.instance.hasPendingArticle) {
    DeepLinkService.instance.processPendingLink(navigationReady: true);
  }
}

/// Account features (bookmarks, account settings) require a real session.
/// Returns `true` if the user is logged in; otherwise opens Auth and returns `false`.
bool ensureLoggedInForAccountFeature(BuildContext context) {
  if (UserService().isLoggedIn) return true;
  navigateToLoginForAccountFeature(context);
  return false;
}

/// Opens Auth on top of the current screen so guests can go back to browsing.
void navigateToLoginForAccountFeature(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
  );
}

/// Same as [navigateToLoginForAccountFeature] using the global navigator
/// (for providers outside the widget tree).
void navigateToLoginForAccountFeatureGlobal() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
  );
}
