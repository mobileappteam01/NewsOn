import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';

import '../../providers/remote_config_provider.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/user_service.dart';
import '../../widgets/google_signin_button.dart';
import '../onboarding/onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  String _loadingMessage = 'Connecting...';

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Connecting to Google...';
    });

    try {
      // Step 1: Google Sign-In
      final account = await _googleAuthService.signInWithGoogle();

      if (account == null) {
        // User cancelled sign-in
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Sign-in cancelled'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
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
        setState(() => _loadingMessage = 'Welcome!');

        // Navigate to onboarding screen (sign-up will happen after category selection)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sign-in failed: ${e.toString()}'),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                config.authTitleText.replaceRange(4, 7, ""),
                                style: GoogleFonts.playfair(
                                  fontSize: config.splashWelcomeFontSize,
                                  fontWeight:
                                      config.splashWelcomeFontWeightValue,
                                  color: theme.colorScheme.secondary,
                                  letterSpacing:
                                      config.splashWelcomeLetterSpacing,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                config.authTitleText.substring(4),
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
                            ],
                          ),
                        ),
                        giveHeight(6),
                        Padding(
                          padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width / 3,
                          ),
                          child: Text(
                            config.authDescText,
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
            // Beautiful Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            config.primaryColorValue,
                          ),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _loadingMessage,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait...',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
