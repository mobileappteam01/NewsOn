import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Service to handle Sign in with Apple authentication
class AppleAuthService {
  /// Check if Sign in with Apple is available on this device
  /// Returns true only on iOS/macOS platforms
  static bool get isAvailable => Platform.isIOS || Platform.isMacOS;

  /// Sign in with Apple
  /// Returns the Apple ID credential on success, null on cancellation
  Future<AuthorizationCredentialAppleID?> signInWithApple() async {
    try {
      debugPrint("🍎 Starting Sign in with Apple...");

      // Check if available
      if (!isAvailable) {
        debugPrint("⚠️ Sign in with Apple is not available on this platform");
        return null;
      }

      // Request Apple ID credential
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint("✅ Sign in with Apple successful");
      debugPrint("   User ID: ${credential.userIdentifier}");
      debugPrint("   Email: ${credential.email ?? 'Not provided'}");
      debugPrint("   Name: ${credential.givenName ?? ''} ${credential.familyName ?? ''}");

      return credential;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Handle specific Apple Sign In errors
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          debugPrint("ℹ️ Sign in with Apple was cancelled by user");
          return null;
        case AuthorizationErrorCode.failed:
          debugPrint("❌ Sign in with Apple failed: ${e.message}");
          rethrow;
        case AuthorizationErrorCode.invalidResponse:
          debugPrint("❌ Sign in with Apple invalid response: ${e.message}");
          rethrow;
        case AuthorizationErrorCode.notHandled:
          debugPrint("❌ Sign in with Apple not handled: ${e.message}");
          rethrow;
        case AuthorizationErrorCode.notInteractive:
          debugPrint("❌ Sign in with Apple not interactive: ${e.message}");
          rethrow;
        default:
          debugPrint("❌ Sign in with Apple unknown error: ${e.message}");
          rethrow;
      }
    } catch (e) {
      // Handle cancellation gracefully
      if (e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        debugPrint("ℹ️ Sign in with Apple was cancelled by user");
        return null;
      }

      debugPrint("❌ Sign in with Apple Error: $e");
      rethrow;
    }
  }

  /// Extract user data from Apple credential for backend signup
  /// Note: Apple only provides email and name on FIRST sign-in
  /// Subsequent sign-ins will have null email and name
  Map<String, dynamic> extractUserData(AuthorizationCredentialAppleID credential) {
    // Build display name from given name and family name
    String displayName = '';
    if (credential.givenName != null && credential.givenName!.isNotEmpty) {
      displayName = credential.givenName!;
      if (credential.familyName != null && credential.familyName!.isNotEmpty) {
        displayName += ' ${credential.familyName}';
      }
    }

    return {
      'appleUserId': credential.userIdentifier,
      'email': credential.email,
      'displayName': displayName.isNotEmpty ? displayName : null,
      'givenName': credential.givenName,
      'familyName': credential.familyName,
      'authorizationCode': credential.authorizationCode,
      'identityToken': credential.identityToken,
    };
  }
}
