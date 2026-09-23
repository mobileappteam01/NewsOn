import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/utils/voice_features.dart';
import '../data/models/remote_config_model.dart';
import '../data/services/news_image_cache_service.dart';
import '../data/services/remote_config_service.dart';
import '../data/services/storage_service.dart';

/// Provider for managing Remote Config state
class RemoteConfigProvider extends ChangeNotifier {
  RemoteConfigService? _remoteConfigService;
  RemoteConfigModel _config = RemoteConfigModel();
  bool _isInitialized = false;
  final bool _firebaseDisabled;

  RemoteConfigProvider() : _firebaseDisabled = false;

  /// Test-only: seed config without touching Firebase Remote Config.
  @visibleForTesting
  RemoteConfigProvider.forTest(RemoteConfigModel config)
      : _firebaseDisabled = true {
    _applyConfig(config);
    _isInitialized = true;
  }

  RemoteConfigService get _service =>
      _remoteConfigService ??= RemoteConfigService();

  RemoteConfigModel get config => _config;
  bool get isInitialized => _isInitialized;
  bool get isVoiceFeaturesEnabled => _config.enableVoiceFeatures;

  void _applyConfig(RemoteConfigModel config) {
    _config = config;
    VoiceFeatures.applyFromConfig(config);
  }

  /// Update app icon from Realtime Database
  /// Creates a new config instance with the updated app icon
  void updateAppIcon(String? appIconUrl) {
    if (appIconUrl != null && appIconUrl.isNotEmpty) {
      // Create a new config with updated app icon using fromJson for easier copying
      final currentJson = _config.toJson();
      currentJson['appIcon'] = appIconUrl;
      _applyConfig(RemoteConfigModel.fromJson(currentJson));
      notifyListeners();
      debugPrint('✅ App icon updated in RemoteConfigProvider: $appIconUrl');
    }
  }

  /// Initialize Remote Config
  /// Loads cached data immediately, then tries to fetch new data
  Future<void> initialize() async {
    if (_firebaseDisabled) return;
    try {
      // Step 1: Try to load cached config first for immediate UI update
      try {
        final cachedConfig = StorageService.getRemoteConfigCache();
        if (cachedConfig != null && cachedConfig.appName.isNotEmpty) {
          _applyConfig(cachedConfig);
          _isInitialized = true;
          notifyListeners(); // Notify immediately with cached data
          debugPrint('📦 RemoteConfigProvider initialized with cached data');
          unawaited(
            NewsImageCacheService.instance.prefetchRemoteConfig(_config),
          );
          // Continue to try fetching fresh data in background
        } else {
          // No cached data, use defaults from RemoteConfigService
          debugPrint('📦 No cached Remote Config found, using defaults');
          _applyConfig(RemoteConfigModel()); // Use default model
          _isInitialized = true;
          notifyListeners(); // Notify with defaults immediately
        }
      } catch (cacheError) {
        debugPrint('⚠️ Error loading cached Remote Config: $cacheError');
        // Use defaults if cache fails
        _applyConfig(RemoteConfigModel());
        _isInitialized = true;
        notifyListeners();
      }

      // Step 2: Try to initialize and fetch new data (works offline with Firebase defaults)
      await _service.initialize();
      _applyConfig(_service.getConfig());
      _isInitialized = true;
      unawaited(NewsImageCacheService.instance.prefetchRemoteConfig(_config));
      notifyListeners(); // Notify again with fresh data (if fetched) or defaults
      debugPrint('✅ RemoteConfigProvider fully initialized');
    } catch (e) {
      debugPrint('❌ Error initializing RemoteConfigProvider: $e');
      // Always ensure we have at least default config
      try {
        final cachedConfig = StorageService.getRemoteConfigCache();
        if (cachedConfig != null) {
          _applyConfig(cachedConfig);
        } else {
          _applyConfig(RemoteConfigModel()); // Use default model
        }
      } catch (cacheError) {
        _applyConfig(RemoteConfigModel()); // Use default model as last resort
      }
      _isInitialized = true;
      notifyListeners(); // Always notify so UI can render
      debugPrint('✅ RemoteConfigProvider initialized with fallback config');
    }
  }

  /// Fetch and update config
  Future<void> fetchAndUpdate() async {
    if (_firebaseDisabled) return;
    try {
      final updated = await _service.fetchConfig();
      if (updated) {
        _applyConfig(_service.getConfig());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching config: $e');
    }
  }

  /// Refresh config (can be called manually)
  Future<void> refresh() async {
    await fetchAndUpdate();
  }

  /// Force refresh config (bypasses minimum fetch interval)
  Future<void> forceRefresh() async {
    if (_firebaseDisabled) return;
    try {
      final updated = await _service.forceFetchConfig();
      if (updated) {
        _applyConfig(_service.getConfig());
        notifyListeners();
        debugPrint('✅ UI updated with new Remote Config values');
      }
    } catch (e) {
      debugPrint('❌ Error force refreshing config: $e');
    }
  }

  /// Test-only: inject a config snapshot without Firebase.
  @visibleForTesting
  void debugOverrideConfig(RemoteConfigModel config) {
    _applyConfig(config);
    _isInitialized = true;
    notifyListeners();
  }
}
