import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
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
      final account = await _googleAuthService.signInWithGoogle();

      if (account != null && mounted) {
        // Sign-in successful
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Welcome, ${account.displayName ?? account.email}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // TODO: Navigate to home screen
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (_) => const HomeScreen()),
        // );
      } else if (mounted) {
        // Sign-in cancelled or failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Sign-in cancelled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
        final primaryColor = config.primaryColorValue;
        final textColor = config.textPrimaryColorValue;
        return Scaffold(
          backgroundColor: config.backgroundColorValue,
          body: Stack(
            children: [
              Align(
                alignment: const Alignment(0.8, 0.50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.authTitleText,
                      style: GoogleFonts.playfair(
                        fontSize: config.splashWelcomeFontSize,
                        fontWeight: config.splashWelcomeFontWeightValue,
                        color: textColor,
                        letterSpacing: config.splashWelcomeLetterSpacing,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    giveHeight(6),
                    Text(
                      config.authDescText,
                      style: GoogleFonts.playfair(
                        fontSize: config.splashAppNameFontSize,
                        fontWeight: config.splashAppNameFontWeightValue,
                        color: primaryColor,
                        letterSpacing: config.splashAppNameLetterSpacing,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
               Align(
                    alignment: const Alignment(0, 0.92),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GoogleSignInButton(
                          onPressed: _handleGoogleSignIn,
                          isLoading: _isLoading,
                          backgroundColor: config.cardBackgroundColorValue,
                          textColor: textColor,
                        ),
                        giveHeight(16),
                        Text(
                          'By continuing, you agree to our Terms & Privacy Policy',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: config.textSecondaryColorValue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
