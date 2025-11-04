import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  /// Sign in with Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    final GoogleSignIn signIn = GoogleSignIn.instance;
    unawaited(
      signIn.initialize(clientId: "", serverClientId: "").then((_) {
        signIn.authenticationEvents
            .listen(_handleAuthenticationEvent)
            .onError(_handleAuthenticationError);

        /// This example always uses the stream-based approach to determining
        /// which UI state to show, rather than using the future returned here,
        /// if any, to conditionally skip directly to the signed-in state.
        signIn.attemptLightweightAuthentication();
      }),
    );
    try {
      print('🔐 Starting Google Sign-In...');
      await GoogleSignIn.instance.authenticate();
    } catch (error) {
      print('❌ Google Sign-In error: $error');
      return null;
    }
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    // #docregion CheckAuthorization
    final GoogleSignInAccount? user = // ...
    // #enddocregion CheckAuthorization
    switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    // Check for existing authorization.
    // #docregion CheckAuthorization
    final GoogleSignInClientAuthorization? authorization = await user
        ?.authorizationClient
        .authorizationForScopes([]);
    // #enddocregion CheckAuthorization

    // If the user has already granted access to the required scopes, call the
    // REST API.
    if (user != null && authorization != null) {
      // unawaited(_handleGetContact(user));
    }
  }

  Future<void> _handleAuthenticationError(Object e) async {
    // setState(() {
    //   _currentUser = null;
    //   _isAuthorized = false;
    //   _errorMessage =
    //       e is GoogleSignInException
    //           ? _errorMessageFromSignInException(e)
    //           : 'Unknown error: $e';
    // });
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      print('✅ Google Sign-Out successful');
    } catch (error) {
      print('❌ Google Sign-Out error: $error');
    }
  }

  /// Check if user is currently signed in

  /// Get current user

  /// Silent sign-in (if user previously signed in)
}
