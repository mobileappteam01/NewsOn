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

        if (apiConfigJson.isNotEmpty && apiConfigJson.trim().isNotEmpty) {
          try {
            final Map<String, dynamic> configMap = json.decode(apiConfigJson);
            _cachedConfig = ApiConfigModel.fromJson(configMap);
            _isInitialized = true;
            print('✅ API Config loaded from Remote Config');

            // Step 3: Save to local cache after successful load
            await StorageService.saveApiConfigCache(_cachedConfig!);
            print('💾 API Config saved to local cache');
            return _cachedConfig!;
          } catch (jsonError) {
            print('⚠️ Error parsing API Config JSON: $jsonError');
            print('📦 Using cached or default API Config');
            // Fall through to use cached/default config
          }
        }
        
        // Use cached or default config if Remote Config doesn't have it or parsing failed
        if (_cachedConfig == null) {
          _cachedConfig = ApiConfigModel();
          _isInitialized = true;
          print('⚠️ Using default API Config (Remote Config empty or invalid)');
        } else {
          print('⚠️ Using cached API Config');
        }
        return _cachedConfig!;
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

      // Step 1: Try to load from cache first (for offline support)
      final cachedData = StorageService.getRealtimeDbCache('api_config');
      if (cachedData != null) {
        try {
          final configMap = Map<String, dynamic>.from(cachedData as Map);
          _cachedConfig = ApiConfigModel.fromJson(configMap);
          _isInitialized = true;
          print('📦 Loaded API Config from cache');
          // Return cached data immediately, then try to fetch fresh data
          _fetchRealtimeDbInBackground();
          return _cachedConfig!;
        } catch (e) {
          print('⚠️ Error parsing cached API Config: $e');
        }
      }

      // Step 2: Try to fetch from Realtime Database
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

        // Cache the data for offline use
        await StorageService.saveRealtimeDbCache('api_config', data);

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
      // If we have cached data, use it
      if (_cachedConfig != null) {
        print('📦 Using cached API Config due to error');
        return _cachedConfig!;
      }
      // Fallback to Remote Config
      return await initializeFromRemoteConfig();
    }
  }

  /// Fetch Realtime Database data in background (for refresh)
  Future<void> _fetchRealtimeDbInBackground() async {
    try {
      final ref = _database.ref('api_config');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>;
        // Update cache with fresh data
        await StorageService.saveRealtimeDbCache('api_config', data);
        print('🔄 Updated API Config cache from Realtime Database');
      }
    } catch (e) {
      print('⚠️ Background fetch failed for API Config: $e');
      // Silently fail - we already have cached data
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
          
          // Update cache with fresh data
          StorageService.saveRealtimeDbCache('api_config', data);
          
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
