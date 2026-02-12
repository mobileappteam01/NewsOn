import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:provider/provider.dart';

import '../../providers/remote_config_provider.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/apple_auth_service.dart';
import '../../data/services/user_service.dart';
import '../../widgets/google_signin_button.dart';
import '../../widgets/apple_signin_button.dart';
import '../onboarding/onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final AppleAuthService _appleAuthService = AppleAuthService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  late String _loadingMessage;
  late AnimationController _loadingAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadingMessage = ''; // Will be set when context is available
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = LocalizationHelper.connectingToGoogle(context);
    });

    try {
      await _googleAuthService.googleSignOut();
      // Step 1: Google Sign-In
      final account = await _googleAuthService.signInWithGoogle();

      // Check if user cancelled or if account is null
      if (account == null) {
        // User cancelled sign-in - this is normal, just dismiss loading
        if (mounted) {
          setState(() => _isLoading = false);
          // Don't show error message for cancellation - it's user's choice
        }
        return;
      }

      // Step 2: Store Google account data temporarily (for sign-up later)
      final googleAccountData = {
        'displayName': account.displayName ?? '',
        'email': account.email,
        'id': account.id,
        'photoUrl': account.photoUrl,
      };
      await _userService.saveTempGoogleAccount(googleAccountData);

      if (mounted) {
        setState(() => _loadingMessage = LocalizationHelper.welcome(context));

        // Small delay to show "Welcome!" message
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to onboarding screen (sign-up will happen after category selection)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      // Only show error for actual errors, not cancellations
      if (mounted) {
        setState(() => _isLoading = false);

        // Check if it's a cancellation error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('cancel') ||
            errorString.contains('cancelled') ||
            errorString.contains('sign_in_canceled')) {
          // User cancelled - don't show error
          return;
        }

        // Show error for actual failures
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${LocalizationHelper.signInFailed(context, e.toString())}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Connecting to Apple...';
    });

    try {
      // Step 1: Apple Sign-In
      final credential = await _appleAuthService.signInWithApple();

      // Check if user cancelled or if credential is null
      if (credential == null) {
        // User cancelled sign-in - this is normal, just dismiss loading
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Step 2: Extract user data from Apple credential
      final appleUserData = _appleAuthService.extractUserData(credential);

      // Step 3: Store Apple account data temporarily (for sign-up later)
      // Note: Apple only provides email/name on FIRST sign-in
      // We need to handle the case where email might be null on subsequent logins
      final accountData = {
        'displayName': appleUserData['displayName'] ?? 
                       appleUserData['givenName'] ?? 
                       'Apple User',
        'email': appleUserData['email'] ?? 
                 '${credential.userIdentifier}@privaterelay.appleid.com',
        'id': credential.userIdentifier,
        'photoUrl': null, // Apple doesn't provide photo
        'authProvider': 'apple',
        'identityToken': appleUserData['identityToken'],
        'authorizationCode': appleUserData['authorizationCode'],
      };
      await _userService.saveTempGoogleAccount(accountData);

      if (mounted) {
        setState(() => _loadingMessage = LocalizationHelper.welcome(context));

        // Small delay to show "Welcome!" message
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to onboarding screen (sign-up will happen after category selection)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      // Only show error for actual errors, not cancellations
      if (mounted) {
        setState(() => _isLoading = false);

        // Check if it's a cancellation error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('cancel') ||
            errorString.contains('cancelled')) {
          // User cancelled - don't show error
          return;
        }

        // Show error for actual failures
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Apple Sign-In failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);

        return Stack(
          children: [
            Scaffold(
              body: ListView(
                children: [
                  giveHeight(32),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    width: double.infinity,
                    child: showImage(config.splashAnimatedGif!, BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).size.height / 5.5,
                          ),
                          child: Text(
                            LocalizationHelper.signIn(context),
                            style: GoogleFonts.playfair(
                              fontSize: config.splashWelcomeFontSize,
                              fontWeight:
                                  config.splashWelcomeFontWeightValue,
                              color: config.primaryColorValue,
                              letterSpacing:
                                  config.splashWelcomeLetterSpacing,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        giveHeight(6),
                        Padding(
                          padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width / 3,
                          ),
                          child: Text(
                            LocalizationHelper.signInToYourAccount(context),
                            style: GoogleFonts.inriaSerif(
                              fontSize: 14,

                              color: theme.colorScheme.tertiary,
                              letterSpacing: config.splashAppNameLetterSpacing,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  giveHeight(12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoogleSignInButton(
                        onPressed: _handleGoogleSignIn,
                        isLoading: _isLoading,
                        backgroundColor: config.cardBackgroundColorValue,
                        textColor: Colors.black,
                      ),
                      // Show Apple Sign In button only on iOS
                      if (AppleSignInButton.shouldShow) ...[
                        giveHeight(12),
                        AppleSignInButton(
                          onPressed: _handleAppleSignIn,
                          isLoading: _isLoading,
                        ),
                      ],
                      giveHeight(16),
                      Text(
                        'By continuing, you agree to our Terms & Privacy Policy',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: theme.colorScheme.tertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  giveHeight(12),
                ],
              ),
            ),
            // Beautiful Loading Overlay with Animations
            if (_isLoading)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _loadingAnimationController,
                    builder: (context, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.scaffoldBackgroundColor,
                              theme.scaffoldBackgroundColor.withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: config.primaryColorValue.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: config.primaryColorValue.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: -5,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated Icon Container
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    config.primaryColorValue.withOpacity(0.2),
                                    config.primaryColorValue.withOpacity(0.05),
                                  ],
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pulsing ring
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: config.primaryColorValue
                                              .withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Progress indicator
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        config.primaryColorValue,
                                      ),
                                      strokeWidth: 4,
                                      backgroundColor: config.primaryColorValue
                                          .withOpacity(0.1),
                                    ),
                                  ),
                                  // Icon
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Icon(
                                      Icons.cloud_done_rounded,
                                      size: 32,
                                      color: config.primaryColorValue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Loading message with animation
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  _loadingMessage,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.secondary,
                                    letterSpacing: 0.5,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Subtitle
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  'Please wait while we set things up',
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.tertiary,
                                    letterSpacing: 0.3,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Animated dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return AnimatedBuilder(
                                  animation: _loadingAnimationController,
                                  builder: (context, child) {
                                    final delay = index * 0.2;
                                    final animationValue =
                                        (_loadingAnimationController.value +
                                            delay) %
                                        1.0;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: config.primaryColorValue
                                            .withOpacity(
                                              0.3 + (animationValue * 0.7),
                                            ),
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
