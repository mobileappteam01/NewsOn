import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/screens/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';

import '../../providers/remote_config_provider.dart';
import '../../data/services/google_auth_service.dart';
import '../../widgets/google_signin_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // final account = await _googleAuthService.signInWithGoogle();

      // if (account != null && mounted) {
      //   // Sign-in successful
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text(
      //         '✅ Welcome, ${account.displayName ?? account.email}!',
      //       ),
      //       backgroundColor: Colors.green,
      //       duration: const Duration(seconds: 3),
      //     ),
      //   );

      //   // TODO: Navigate to home screen
      //   // Navigator.pushReplacement(
      //   //   context,
      //   //   MaterialPageRoute(builder: (_) => const HomeScreen()),
      //   // );
      // } else if (mounted) {
      //   // Sign-in cancelled or failed
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('❌ Sign-in cancelled'),
      //       backgroundColor: Colors.orange,
      //       duration: Duration(seconds: 2),
      //     ),
      //   );
      // }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sign-in failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);

        return Scaffold(
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
                              fontWeight: config.splashWelcomeFontWeightValue,
                              color: theme.colorScheme.secondary,
                              letterSpacing: config.splashWelcomeLetterSpacing,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            config.authTitleText.substring(4),
                            style: GoogleFonts.playfair(
                              fontSize: config.splashWelcomeFontSize,
                              fontWeight: config.splashWelcomeFontWeightValue,
                              color: config.primaryColorValue,
                              letterSpacing: config.splashWelcomeLetterSpacing,
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
        );
      },
    );
  }
}
