import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],

    // ✔ Android client ID
    clientId:
        "127869269941-sjls3shqo436vt3oq9kqc4rlqimsb3rh.apps.googleusercontent.com",

    // ✔ Web client ID OPTIONAL (required for Firebase Auth)
    serverClientId:
        "127869269941-2p1d7r414luv6dolb09khq5b0af8fqvc.apps.googleusercontent.com",
  );
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      debugPrint("🔐 Starting Google Sign-In...");

      final account = await _googleSignIn.signIn();

      // If account is null, user cancelled - this is normal, not an error
      if (account == null) {
        debugPrint("ℹ️ User cancelled Google Sign-In");
        return null;
      }

      debugPrint("✅ Google Sign-In successful: ${account.email}");
      return account;
    } catch (e) {
      // Handle cancellation gracefully - don't treat it as an error
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('SIGN_IN_CANCELLED') ||
          e.toString().contains('canceled')) {
        debugPrint("ℹ️ Google Sign-In was cancelled by user");
        return null;
      }

      debugPrint("❌ Google Sign-In Error: $e");
      return null;
    }
  }

  googleSignOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint("✅ Google Sign-Out successful");
    } catch (e) {
      debugPrint("❌ Google Sign-Out Error: $e");
    }
  }
}
