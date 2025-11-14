import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/api_config_model.dart';
import '../services/storage_service.dart';

/// Service to manage Dynamic API Configuration
/// Supports both Firebase Remote Config and Realtime Database
class ApiConfigService {
  static final ApiConfigService _instance = ApiConfigService._internal();
  factory ApiConfigService() => _instance;
  ApiConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  ApiConfigModel? _cachedConfig;
  bool _isInitialized = false;

  ApiConfigModel? get cachedConfig => _cachedConfig;
  bool get isInitialized => _isInitialized;

  /// Initialize API Config from Remote Config
  /// Loads cached data first, then tries to fetch new data
  Future<ApiConfigModel> initializeFromRemoteConfig() async {
    try {
      print('🔧 Initializing API Config from Remote Config...');

      // Step 1: Try to load from local cache first
      final cachedConfig = StorageService.getApiConfigCache();
      if (cachedConfig != null) {
        _cachedConfig = cachedConfig;
        _isInitialized = true;
        print('📦 Loaded cached API Config from local storage');
      }

      // Step 2: Try to get API config JSON from Remote Config
      try {
        final apiConfigJson = _remoteConfig.getString('api_config_json');

        if (apiConfigJson.isNotEmpty) {
          final Map<String, dynamic> configMap = json.decode(apiConfigJson);
          _cachedConfig = ApiConfigModel.fromJson(configMap);
          _isInitialized = true;
          print('✅ API Config loaded from Remote Config');

          // Step 3: Save to local cache after successful load
          await StorageService.saveApiConfigCache(_cachedConfig!);
          print('💾 API Config saved to local cache');
          return _cachedConfig!;
        } else {
          // Use cached or default config if Remote Config doesn't have it
          if (_cachedConfig == null) {
            _cachedConfig = ApiConfigModel();
            _isInitialized = true;
            print('⚠️ Using default API Config (Remote Config empty)');
          } else {
            print('⚠️ Remote Config empty, using cached API Config');
          }
          return _cachedConfig!;
        }
      } catch (fetchError) {
        // If fetch fails (offline), use cached data or defaults
        print(
          '⚠️ Failed to fetch API Config from Remote Config (offline?): $fetchError',
        );
        if (_cachedConfig != null) {
          print('📦 Using cached API Config');
          return _cachedConfig!;
        } else {
          _cachedConfig = ApiConfigModel();
          _isInitialized = true;
          print('📦 Using default API Config');
          return _cachedConfig!;
        }
      }
    } catch (e) {
      print('❌ Error loading API Config from Remote Config: $e');
      // Try to use cached data as fallback
      final cachedConfig = StorageService.getApiConfigCache();
      if (cachedConfig != null) {
        _cachedConfig = cachedConfig;
        _isInitialized = true;
        print('📦 Fallback: Using cached API Config');
        return _cachedConfig!;
      }
      // Last resort: return default config
      _cachedConfig = ApiConfigModel();
      _isInitialized = true;
      return _cachedConfig!;
    }
  }

  /// Initialize API Config from Realtime Database
  /// This allows for more complex configurations and real-time updates
  Future<ApiConfigModel> initializeFromRealtimeDatabase() async {
    try {
      print('🔧 Initializing API Config from Realtime Database...');

      final ref = _database.ref('api_config');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>;
        final configMap = Map<String, dynamic>.from(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
        _cachedConfig = ApiConfigModel.fromJson(configMap);
        _isInitialized = true;
        print('✅ API Config loaded from Realtime Database');

        // Listen for real-time updates
        _setupRealtimeListener();

        return _cachedConfig!;
      } else {
        // Fallback to Remote Config if Realtime DB doesn't have config
        print('⚠️ Realtime Database empty, falling back to Remote Config');
        return await initializeFromRemoteConfig();
      }
    } catch (e) {
      print('❌ Error loading API Config from Realtime Database: $e');
      // Fallback to Remote Config
      return await initializeFromRemoteConfig();
    }
  }

  /// Setup real-time listener for API config changes
  void _setupRealtimeListener() {
    final ref = _database.ref('api_config');
    ref.onValue.listen((event) {
      if (event.snapshot.exists) {
        try {
          final data = event.snapshot.value as Map<Object?, Object?>;
          final configMap = Map<String, dynamic>.from(
            data.map((key, value) => MapEntry(key.toString(), value)),
          );
          _cachedConfig = ApiConfigModel.fromJson(configMap);
          print('🔄 API Config updated from Realtime Database');
        } catch (e) {
          print('❌ Error updating API Config from Realtime Database: $e');
        }
      }
    });
  }

  /// Get current API config (cached or default)
  /// Tries to load from cache if not initialized
  ApiConfigModel getConfig() {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }
    // Try to load from cache if not initialized
    final cachedConfig = StorageService.getApiConfigCache();
    if (cachedConfig != null) {
      _cachedConfig = cachedConfig;
      return _cachedConfig!;
    }
    // Return default if not initialized and no cache
    return ApiConfigModel();
  }

  /// Refresh API config from Remote Config
  Future<ApiConfigModel> refreshFromRemoteConfig() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      if (updated) {
        return await initializeFromRemoteConfig();
      }
      return getConfig();
    } catch (e) {
      print('❌ Error refreshing API Config: $e');
      return getConfig();
    }
  }

  /// Force refresh API config (bypasses minimum fetch interval)
  Future<ApiConfigModel> forceRefreshFromRemoteConfig() async {
    try {
      // Temporarily set fetch interval to 0
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );

      final updated = await _remoteConfig.fetchAndActivate();

      // Reset to normal fetch interval
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      if (updated) {
        return await initializeFromRemoteConfig();
      }
      return getConfig();
    } catch (e) {
      print('❌ Error force refreshing API Config: $e');
      return getConfig();
    }
  }

  /// Update API config in Realtime Database (for admin use)
  Future<void> updateConfigInRealtimeDatabase(ApiConfigModel config) async {
    try {
      final ref = _database.ref('api_config');
      await ref.set(config.toJson());
      _cachedConfig = config;
      print('✅ API Config updated in Realtime Database');
    } catch (e) {
      print('❌ Error updating API Config in Realtime Database: $e');
      rethrow;
    }
  }
}
