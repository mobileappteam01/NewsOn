import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../domain/notification_preferences_model.dart';

/// Phase 7 notification preferences + device registration client.
class NotificationPreferencesApi {
  NotificationPreferencesApi({
    ApiService? apiService,
    UserService? userService,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();

  String? get _token {
    final t = _users.getToken();
    if (t != null && t.isNotEmpty) return t;
    return null;
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final token = _token;
    if (token == null) return const NotificationPreferences();
    try {
      final response = await _api.getByPath(
        '/api/notifications/preferences',
        bearerToken: token,
        useV2Host: true,
      );
      if (!response.success || response.data == null) {
        return const NotificationPreferences();
      }
      final raw = response.data;
      Map<String, dynamic>? map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      }
      if (map == null) return const NotificationPreferences();
      final data = map['data'];
      if (data is Map<String, dynamic>) {
        return NotificationPreferences.fromJson(data);
      }
      if (data is Map) {
        return NotificationPreferences.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return NotificationPreferences.fromJson(map);
    } catch (e) {
      debugPrint('ℹ️ Notification preferences fetch failed: $e');
      return const NotificationPreferences();
    }
  }

  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    final token = _token;
    if (token == null) return false;
    try {
      final response = await _api.patchByPath(
        '/api/notifications/preferences',
        body: prefs.toPatchBody(),
        bearerToken: token,
        useV2Host: true,
      );
      return response.success;
    } catch (e) {
      debugPrint('ℹ️ Notification preferences update failed: $e');
      return false;
    }
  }

  /// Registers device token. Never logs the token. Never sends userId.
  Future<bool> registerDevice({
    required String fcmToken,
    String? appVersion,
  }) async {
    final auth = _token;
    if (auth == null) return false;
    final t = fcmToken.trim();
    if (t.length < 10 || t.length > 4096) return false;

    String platform = 'other';
    if (!kIsWeb) {
      if (Platform.isIOS) platform = 'ios';
      if (Platform.isAndroid) platform = 'android';
    }

    try {
      final response = await _api.postByPath(
        '/api/notifications/devices',
        body: {
          'token': t,
          'platform': platform,
          if (appVersion != null && appVersion.isNotEmpty)
            'appVersion': appVersion,
        },
        bearerToken: auth,
        useV2Host: true,
      );
      return response.success;
    } catch (e) {
      debugPrint('ℹ️ Device token registration failed');
      return false;
    }
  }
}
