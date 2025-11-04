import 'package:flutter/material.dart';
import '../data/models/remote_config_model.dart';
import '../data/services/remote_config_service.dart';

/// Provider for managing Remote Config state
class RemoteConfigProvider extends ChangeNotifier {
  final RemoteConfigService _remoteConfigService = RemoteConfigService();
  RemoteConfigModel _config = RemoteConfigModel();
  bool _isInitialized = false;

  RemoteConfigModel get config => _config;
  bool get isInitialized => _isInitialized;

  /// Initialize Remote Config
  Future<void> initialize() async {
    try {
      await _remoteConfigService.initialize();
      _config = _remoteConfigService.getConfig();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing RemoteConfigProvider: $e');
      // Use default values if initialization fails
      _config = RemoteConfigModel();
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Fetch and update config
  Future<void> fetchAndUpdate() async {
    try {
      final updated = await _remoteConfigService.fetchConfig();
      if (updated) {
        _config = _remoteConfigService.getConfig();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching config: $e');
    }
  }

  /// Refresh config (can be called manually)
  Future<void> refresh() async {
    await fetchAndUpdate();
  }

  /// Force refresh config (bypasses minimum fetch interval)
  Future<void> forceRefresh() async {
    try {
      final updated = await _remoteConfigService.forceFetchConfig();
      if (updated) {
        _config = _remoteConfigService.getConfig();
        notifyListeners();
        print('✅ UI updated with new Remote Config values');
      }
    } catch (e) {
      print('❌ Error force refreshing config: $e');
    }
  }
}
