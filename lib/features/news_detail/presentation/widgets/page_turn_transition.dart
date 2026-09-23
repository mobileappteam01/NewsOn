import 'package:flutter/material.dart';

/// Lightweight horizontal page-turn style transition between articles.
class PageTurnPageRoute<T> extends PageRouteBuilder<T> {
  PageTurnPageRoute({
    required WidgetBuilder builder,
    bool enabled = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            if (!enabled || reduceMotion) {
              return FadeTransition(opacity: animation, child: child);
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.12, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
          transitionDuration: enabled
              ? const Duration(milliseconds: 280)
              : const Duration(milliseconds: 150),
        );
}
