import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../../core/constants/app_constants.dart';

/// User Service - Manages user session data and authentication token
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  String? _token;
  Map<String, dynamic>? _userData;
  bool _guestBrowse = false;

  /// Initialize user service - Load from storage
  Future<void> initialize() async {
    try {
      _token = StorageService.getSetting(AppConstants.userTokenKey) as String?;
      final userDataFromStorage = StorageService.getSetting(
        AppConstants.userDataKey,
      );

      if (userDataFromStorage != null) {
        // Handle different storage formats
        if (userDataFromStorage is Map) {
          _userData = Map<String, dynamic>.from(userDataFromStorage);
        } else if (userDataFromStorage is String) {
          // Parse JSON string
          try {
            final decoded =
                jsonDecode(userDataFromStorage) as Map<String, dynamic>;
            _userData = decoded;
          } catch (e) {
            debugPrint('⚠️ Error parsing user data JSON: $e');
          }
        }
      }

      final guestRaw =
          StorageService.getSetting(AppConstants.guestBrowseKey);
      _guestBrowse = guestRaw == true || guestRaw == 'true';

      if (_token != null && _token!.isNotEmpty) {
        // Real session wins over guest browse.
        if (_guestBrowse) {
          _guestBrowse = false;
          await StorageService.saveSetting(AppConstants.guestBrowseKey, false);
        }
        debugPrint('✅ User session loaded from storage');
        debugPrint('   User: ${_userData?['nickName'] ?? _userData?['email']}');
      } else if (_guestBrowse && Platform.isIOS) {
        debugPrint('✅ iOS guest browse mode restored');
      }
    } catch (e) {
      debugPrint('❌ Error initializing UserService: $e');
    }
  }

  /// Save user data and token after sign-up/sign-in
  Future<void> saveUserData({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await clearGuestBrowse();
      _token = token;
      // Preserve auth provider across profile refreshes.
      // Priority:
      // 1) explicit userData['authProvider']
      // 2) temp account (from sign-in screen, used during onboarding)
      // 3) previously saved setting
      final explicitProvider = userData['authProvider'] as String?;
      final tempProvider = getTempGoogleAccount()?['authProvider'] as String?;
      final storedProvider = StorageService.getAuthProvider();
      final provider = (explicitProvider?.isNotEmpty == true)
          ? explicitProvider
          : (tempProvider?.isNotEmpty == true)
              ? tempProvider
              : storedProvider;

      if (provider != null && provider.isNotEmpty) {
        userData = Map<String, dynamic>.from(userData);
        userData['authProvider'] = provider;
        await StorageService.saveAuthProvider(provider);
      }

      _userData = userData;

      // Save to local storage
      await StorageService.saveSetting(AppConstants.userTokenKey, token);
      // Store as JSON string for better compatibility
      await StorageService.saveSetting(
        AppConstants.userDataKey,
        jsonEncode(userData),
      );

      debugPrint('✅ User data and token saved');
      debugPrint('   NickName: ${userData['nickName']}');
      debugPrint('   Email: ${userData['email']}');
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
    }
  }

  /// Get authentication token.
  /// Never logs the token value (security).
  String? getToken() {
    final t = _token;
    debugPrint('🔐 Auth token present=${t != null && t.isNotEmpty}');
    return t;
  }

  /// Get user data
  Map<String, dynamic>? getUserData() {
    return _userData;
  }

  /// Get user nickname
  String? getNickName() {
    return _userData?['nickName'] as String?;
  }

  /// Get user email
  String? getEmail() {
    return _userData?['email'] as String?;
  }

  /// Get user firstName
  String? getFirstName() {
    return _userData?['firstName'] as String?;
  }

  /// Get user ID
  String? getUserId() {
    return _userData?['_id'] as String?;
  }

  /// Check if user is logged in
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// iOS-only guest browse (no account). Android always false.
  bool get isGuestBrowse =>
      Platform.isIOS && !isLoggedIn && _guestBrowse;

  /// Allow Home / news without login on iOS (App Store Guideline 5.1.1(v)).
  bool get canBrowseWithoutAccount => isLoggedIn || isGuestBrowse;

  /// Persist guest browse for iOS only. No-op on Android.
  Future<void> enableGuestBrowse() async {
    if (!Platform.isIOS) return;
    _guestBrowse = true;
    await StorageService.saveSetting(AppConstants.guestBrowseKey, true);
    debugPrint('✅ iOS guest browse enabled');
  }

  Future<void> clearGuestBrowse() async {
    if (!_guestBrowse) {
      await StorageService.saveSetting(AppConstants.guestBrowseKey, false);
      return;
    }
    _guestBrowse = false;
    await StorageService.saveSetting(AppConstants.guestBrowseKey, false);
    debugPrint('🗑️ iOS guest browse cleared');
  }

  /// Clear user data and token (logout)
  Future<void> clearUserData() async {
    _token = null;
    _userData = null;

    await StorageService.saveSetting(AppConstants.userTokenKey, null);
    await StorageService.saveSetting(AppConstants.userDataKey, null);
    await StorageService.saveAuthProvider(null);
    // Keep guest flag cleared on logout so Auth still shows; user can Skip again on iOS.
    await clearGuestBrowse();

    debugPrint('🗑️ User data cleared');
  }

  /// Get persisted auth provider ('google' | 'apple')
  String? getAuthProvider() {
    final provider = _userData?['authProvider'] as String? ??
        StorageService.getAuthProvider();
    return provider != null && provider.isNotEmpty ? provider : null;
  }

  /// Save temporary Google account data (before sign-up)
  Future<void> saveTempGoogleAccount(
    Map<String, dynamic> googleAccountData,
  ) async {
    try {
      await StorageService.saveSetting(
        AppConstants.tempGoogleAccountKey,
        jsonEncode(googleAccountData),
      );
      debugPrint('✅ Temporary Google account data saved');
    } catch (e) {
      debugPrint('❌ Error saving temporary Google account: $e');
    }
  }

  /// Get temporary Google account data
  Map<String, dynamic>? getTempGoogleAccount() {
    try {
      final data = StorageService.getSetting(AppConstants.tempGoogleAccountKey);
      if (data == null) return null;

      if (data is String) {
        return jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting temporary Google account: $e');
      return null;
    }
  }

  /// Clear temporary Google account data
  Future<void> clearTempGoogleAccount() async {
    await StorageService.saveSetting(AppConstants.tempGoogleAccountKey, null);
    debugPrint('🗑️ Temporary Google account data cleared');
  }
}
