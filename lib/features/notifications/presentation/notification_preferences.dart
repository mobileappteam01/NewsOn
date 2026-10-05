import 'package:flutter/foundation.dart';

import '../data/notification_preferences_api.dart';
import '../domain/notification_preferences_model.dart';

/// Lightweight preferences controller for V2 notification settings.
///
/// Serializes preference writes so rapid taps cannot leave a stale ON state
/// after an OFF request, and never restores default-true after a failed GET
/// when a local value was already known.
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

  int _patchGeneration = 0;
  NotificationPreferences? _queuedPatch;
  bool _hasLoadedOnce = false;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final remote = await _api.fetchPreferences();
      // Ignore a late GET that would overwrite a newer in-flight user edit.
      if (_updating || _queuedPatch != null) return;
      _prefs = remote;
      _hasLoadedOnce = true;
    } catch (_) {
      _error = 'load_failed';
      // Keep previous prefs when we already had a known value (do not snap to ON).
      if (!_hasLoadedOnce) {
        _prefs = const NotificationPreferences();
      }
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
    // Coalesce rapid taps onto the latest desired state.
    if (_updating) {
      _queuedPatch = next;
      _prefs = next;
      notifyListeners();
      return;
    }

    final generation = ++_patchGeneration;
    final previous = _prefs;
    _updating = true;
    _prefs = next;
    _error = null;
    notifyListeners();

    final ok = await _api.updatePreferences(next);
    if (generation != _patchGeneration) {
      // Superseded — a newer patch already owns UI state.
      return;
    }

    _updating = false;
    if (!ok) {
      // Only roll back if no newer queued value took over.
      if (_queuedPatch == null) {
        _prefs = previous;
        _error = 'update_failed';
      }
      notifyListeners();
    } else {
      _hasLoadedOnce = true;
      notifyListeners();
    }

    final queued = _queuedPatch;
    if (queued != null) {
      _queuedPatch = null;
      await _patch(queued);
    }
  }
}
