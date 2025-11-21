import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM (Firebase Cloud Messaging) Service
/// Handles FCM token retrieval and management
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _cachedToken;
  bool _isInitialized = false;

  /// Get FCM token with retry logic
  /// Returns cached token if available, otherwise fetches a new one
  /// Returns null if FCM is not available (e.g., emulator without Google Play Services)
  Future<String?> getToken({int maxRetries = 2}) async {
    try {
      // Return cached token if available
      if (_cachedToken != null) {
        debugPrint('✅ FCM Token (cached): $_cachedToken');
        return _cachedToken;
      }

      // Request notification permissions (required for iOS)
      // On Android, this is a no-op but doesn't hurt to call it
      try {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        // On iOS, check if permission was granted
        // On Android, this check is not critical
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint(
            '⚠️ FCM Permission denied: ${settings.authorizationStatus}',
          );
          // Still try to get token on Android (permissions work differently)
        }
      } catch (e) {
        // On Android, requestPermission might fail or not be needed
        // Continue to try getting token anyway
        debugPrint('ℹ️ Permission request skipped (may be Android): $e');
      }

      // Try to get token with retry logic
      String? token;
      int attempt = 0;

      while (attempt <= maxRetries) {
        try {
          token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _cachedToken = token;
            _isInitialized = true;
            debugPrint('✅ FCM Token fetched: $token');

            // Listen for token refresh (only set up once)
            if (!_isInitialized) {
              _firebaseMessaging.onTokenRefresh.listen((newToken) {
                _cachedToken = newToken;
                debugPrint('🔄 FCM Token refreshed: $newToken');
              });
            }

            return token;
          }
        } catch (e) {
          final errorString = e.toString();

          // Check for specific error types
          if (errorString.contains('SERVICE_NOT_AVAILABLE')) {
            debugPrint(
              '⚠️ FCM Service not available. '
              'This usually means:\n'
              '  - Google Play Services is not available/updated\n'
              '  - Running on emulator without Google Play Services\n'
              '  - Device is not connected to internet\n'
              '  - Firebase Messaging not properly configured\n'
              'The app will continue without FCM token.',
            );
            return null; // Don't retry for this error
          } else if (errorString.contains('NETWORK_ERROR') ||
              errorString.contains('TIMEOUT')) {
            // Retry for network errors
            attempt++;
            if (attempt <= maxRetries) {
              debugPrint(
                '⚠️ Network error getting FCM token. Retrying... (${attempt}/$maxRetries)',
              );
              await Future.delayed(Duration(seconds: attempt * 2));
              continue;
            }
          }

          // For other errors, log and return null
          debugPrint('❌ Error getting FCM token (attempt ${attempt + 1}): $e');
          if (attempt >= maxRetries) {
            return null;
          }
          attempt++;
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Unexpected error getting FCM token: $e');
      return null;
    }
  }

  /// Get FCM token (synchronous - returns cached token only)
  /// Returns null if token hasn't been fetched yet
  String? getCachedToken() {
    return _cachedToken;
  }

  /// Check if FCM is available and initialized
  bool get isAvailable => _isInitialized && _cachedToken != null;

  /// Clear cached token
  void clearToken() {
    _cachedToken = null;
    _isInitialized = false;
    debugPrint('🗑️ FCM Token cache cleared');
  }

  /// Delete FCM token (logout scenario)
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _cachedToken = null;
      _isInitialized = false;
      debugPrint('🗑️ FCM Token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
      // Clear cache even if delete fails
      _cachedToken = null;
      _isInitialized = false;
    }
  }
}
