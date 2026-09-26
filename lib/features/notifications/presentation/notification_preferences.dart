import 'package:flutter/material.dart';

import '../data/notification_preferences_api.dart';
import '../domain/notification_preferences_model.dart';

/// Lightweight preferences controller for V2 notification settings.
class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController({
    NotificationPreferencesApi? api,
  }) : _api = api ?? NotificationPreferencesApi();

  final NotificationPreferencesApi _api;

  NotificationPreferences _prefs = const NotificationPreferences();
  NotificationPreferences get prefs => _prefs;

  bool _loading = false;
  bool get loading => _loading;

  bool _updating = false;
  bool get updating => _updating;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _prefs = await _api.fetchPreferences();
    } catch (_) {
      _error = 'load_failed';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setNotificationsEnabled(bool value) =>
      _patch(_prefs.copyWith(notificationsEnabled: value));

  Future<void> setBreakingNewsEnabled(bool value) =>
      _patch(_prefs.copyWith(breakingNewsEnabled: value));

  Future<void> setCategoryNotificationsEnabled(bool value) =>
      _patch(_prefs.copyWith(categoryNotificationsEnabled: value));

  Future<void> setPublisherNotificationsEnabled(bool value) =>
      _patch(_prefs.copyWith(publisherNotificationsEnabled: value));

  Future<void> _patch(NotificationPreferences next) async {
    if (_updating) return;
    final previous = _prefs;
    _updating = true;
    _prefs = next;
    _error = null;
    notifyListeners();
    final ok = await _api.updatePreferences(next);
    _updating = false;
    if (!ok) {
      _prefs = previous;
      _error = 'update_failed';
    }
    notifyListeners();
  }
}
