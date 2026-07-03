import 'package:flutter/material.dart';

import '../../data/services/deep_link_service.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';

/// Routes the user after OAuth sign-up/sign-in based on [isNewUser].
void navigateAfterOAuthAuth(
  BuildContext context, {
  required bool isNewUser,
}) {
  if (isNewUser) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => const HomeScreen(selectedCategories: []),
    ),
  );

  if (DeepLinkService.instance.hasPendingArticle) {
    DeepLinkService.instance.processPendingLink();
  }
}
