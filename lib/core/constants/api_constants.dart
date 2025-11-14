import 'package:newson/data/models/api_config_model.dart';
import 'package:newson/data/services/api_config_service.dart';

/// API Configuration and Constants - Now Dynamic from Firebase Remote Config
/// This class provides access to API configuration loaded from Firebase Remote Config
/// or Realtime Database. Falls back to default values if not configured.
class ApiConstants {
  // Singleton instance of API Config Service
  static final ApiConfigService _apiConfigService = ApiConfigService();

  // Get current API config (cached or default)
  static ApiConfigModel get _config => _apiConfigService.getConfig();

  // Base URL - Dynamic
  static String get baseUrl => _config.baseUrl;

  // Endpoints - Dynamic
  static String get breakingNewsEndPoint => _config.breakingNewsEndPoint;
  static String get latestNewsEndpoint => _config.latestNewsEndpoint;
  static String get archiveNewsEndpoint => _config.archiveNewsEndpoint;
  static String get searchEndpoint => _config.searchEndpoint;

  // Query Parameters - Dynamic
  static String get apiKeyParam => _config.apiKeyParam;
  static String get categoryParam => _config.categoryParam;
  static String get countryParam => _config.countryParam;
  static String get languageParam => _config.languageParam;
  static String get queryParam => _config.queryParam;
  static String get pageParam => _config.pageParam;
  static String get sizeParam => _config.sizeParam;

  // Default Values - Dynamic
  static String get defaultLanguage => _config.defaultLanguage;
  static String get defaultCountry => _config.defaultCountry;
  static int get defaultPageSize => _config.defaultPageSize;

  // Categories - Dynamic from Remote Config
  static List<String> get categories => _config.categories;

  // Request timeout - Dynamic
  static Duration get requestTimeout => _config.requestTimeout;

  /// Initialize API config from Remote Config
  /// Call this during app initialization
  static Future<void> initialize() async {
    await _apiConfigService.initializeFromRemoteConfig();
  }

  /// Initialize API config from Realtime Database (with real-time updates)
  /// Call this if you want real-time API config updates
  static Future<void> initializeFromRealtimeDatabase() async {
    await _apiConfigService.initializeFromRealtimeDatabase();
  }

  /// Refresh API config from Remote Config
  static Future<void> refresh() async {
    await _apiConfigService.refreshFromRemoteConfig();
  }

  /// Force refresh API config (bypasses minimum fetch interval)
  static Future<void> forceRefresh() async {
    await _apiConfigService.forceRefreshFromRemoteConfig();
  }

  /// Get the full API config model
  static ApiConfigModel getConfig() => _config;
}
