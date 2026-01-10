import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../data/models/remote_config_model.dart';
import '../data/services/remote_config_service.dart';
import '../data/services/storage_service.dart';

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
      // Step 1: Try to load cached config first for immediate UI update
      try {
        final cachedConfig = StorageService.getRemoteConfigCache();
        if (cachedConfig != null && cachedConfig.appName.isNotEmpty) {
          _config = cachedConfig;
          _isInitialized = true;
          notifyListeners(); // Notify immediately with cached data
          debugPrint('📦 RemoteConfigProvider initialized with cached data');
          // Continue to try fetching fresh data in background
        } else {
          // No cached data, use defaults from RemoteConfigService
          debugPrint('📦 No cached Remote Config found, using defaults');
          _config = RemoteConfigModel(); // Use default model
          _isInitialized = true;
          notifyListeners(); // Notify with defaults immediately
        }
      } catch (cacheError) {
        debugPrint('⚠️ Error loading cached Remote Config: $cacheError');
        // Use defaults if cache fails
        _config = RemoteConfigModel();
        _isInitialized = true;
        notifyListeners();
      }

      // Step 2: Try to initialize and fetch new data (works offline with Firebase defaults)
      await _remoteConfigService.initialize();
      _config = _remoteConfigService.getConfig();
      _isInitialized = true;
      notifyListeners(); // Notify again with fresh data (if fetched) or defaults
      debugPrint('✅ RemoteConfigProvider fully initialized');
    } catch (e) {
      debugPrint('❌ Error initializing RemoteConfigProvider: $e');
      // Always ensure we have at least default config
      try {
        final cachedConfig = StorageService.getRemoteConfigCache();
        if (cachedConfig != null) {
          _config = cachedConfig;
        } else {
          _config = RemoteConfigModel(); // Use default model
        }
      } catch (cacheError) {
        _config = RemoteConfigModel(); // Use default model as last resort
      }
      _isInitialized = true;
      notifyListeners(); // Always notify so UI can render
      debugPrint('✅ RemoteConfigProvider initialized with fallback config');
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
