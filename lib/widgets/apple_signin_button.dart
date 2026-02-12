import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple Sign In Button Widget
/// Only displays on iOS/macOS platforms
class AppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
  });

  /// Check if Sign in with Apple should be shown
  /// Only available on iOS and macOS
  static bool get shouldShow => Platform.isIOS || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    // Don't show on non-Apple platforms
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SignInWithAppleButton(
        onPressed: isLoading ? () {} : onPressed,
        style: isDark
            ? SignInWithAppleButtonStyle.white
            : SignInWithAppleButtonStyle.black,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        height: 56,
        text: 'Sign in with Apple',
      ),
    );
  }
}

/// Custom styled Apple Sign In Button (alternative design)
/// Matches the Google Sign In button style
class CustomAppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomAppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
  });

  /// Check if Sign in with Apple should be shown
  static bool get shouldShow => Platform.isIOS || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    // Don't show on non-Apple platforms
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  )
                else ...[
                  Icon(
                    Icons.apple,
                    size: 24,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sign in with Apple',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
