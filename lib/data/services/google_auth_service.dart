import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    final GoogleSignIn _googleSignIn = GoogleSignIn(
      scopes: ['email'],

      // ✔ Android client ID
      clientId:
          "127869269941-sjls3shqo436vt3oq9kqc4rlqimsb3rh.apps.googleusercontent.com",

      // ✔ Web client ID OPTIONAL (required for Firebase Auth)
      serverClientId:
          "127869269941-2p1d7r414luv6dolb09khq5b0af8fqvc.apps.googleusercontent.com",
    );

    try {
      print("🔐 Starting Google Sign-In...");

      final account = await _googleSignIn.signIn(); // ← WORKS PERFECTLY
      return account;
    } catch (e) {
      print("❌ Google Sign-In Error: $e");
      return null;
    }
  }
}
