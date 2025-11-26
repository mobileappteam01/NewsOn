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

  /// Update app icon from Realtime Database
  /// Creates a new config instance with the updated app icon
  void updateAppIcon(String? appIconUrl) {
    if (appIconUrl != null && appIconUrl.isNotEmpty) {
      // Create a new config with updated app icon using fromJson for easier copying
      final currentJson = _config.toJson();
      currentJson['appIcon'] = appIconUrl;
      _config = RemoteConfigModel.fromJson(currentJson);
      notifyListeners();
      debugPrint('✅ App icon updated in RemoteConfigProvider: $appIconUrl');
    }
  }

  /// Initialize Remote Config
  /// Loads cached data immediately, then tries to fetch new data
  Future<void> initialize() async {
    try {
      // Load cached config first for immediate UI update (if available)
      // The getConfig() method will automatically use cached data if available
      final cachedConfig = _remoteConfigService.getConfig();
      if (cachedConfig.appName.isNotEmpty) {
        _config = cachedConfig;
        _isInitialized = true;
        notifyListeners(); // Notify immediately with cached data
        print('📦 RemoteConfigProvider initialized with cached data');
      }

      // Then try to initialize and fetch new data
      await _remoteConfigService.initialize();
      _config = _remoteConfigService.getConfig();
      _isInitialized = true;
      notifyListeners(); // Notify again with fresh data (if fetched)
    } catch (e) {
      print('Error initializing RemoteConfigProvider: $e');
      // Try to use cached data if initialization fails
      final cachedConfig = _remoteConfigService.getConfig();
      _config = cachedConfig;
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
