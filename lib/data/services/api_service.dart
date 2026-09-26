import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';
import '../../core/config/v2_api_config.dart';
import 'v2_api_config_service.dart';

/// Reusable API Service for making HTTP requests
/// - Fetches V1 base URL from Firebase Realtime Database (ipAddress)
/// - Fetches V1 endpoints from Firestore (apiEndPoints collection; skips `v2` doc)
/// - Loads isolated V2 host via [V2ApiConfigService] (`apiEndPoints/v2`)
/// - Handles all HTTP methods with proper error handling
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initializeDio();
  }

  /// Log-safe header map: never includes Authorization / Bearer values.
  static Map<String, String> headersForLog(Map<String, String> headers) {
    final out = <String, String>{};
    for (final e in headers.entries) {
      final key = e.key.toLowerCase();
      if (key == 'authorization' || key == 'proxy-authorization') {
        out[e.key] = e.value.trim().isEmpty
            ? '(empty)'
            : 'Bearer token added to request';
      } else {
        out[e.key] = e.value;
      }
    }
    return out;
  }

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedBaseUrl;
  String? _cachedImageBaseUrl;
  final Map<String, String> _cachedEndpoints = {};
  bool _isInitialized = false;

  /// Coalesce concurrent [initialize] calls (startup + HomeScreen fallback).
  Future<void>? _initFuture;

  /// In-flight Firestore endpoint refresh (avoid stampedes on For You open).
  Future<void>? _endpointsRefreshFuture;

  // Dio client with SSL certificate handling
  late final Dio _dio;

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Don't throw exceptions for any status code - we'll handle them manually
        validateStatus: (status) {
          return status != null && status < 600; // Accept all status codes
        },
      ),
    );

    // Configure SSL certificate handling
    // In debug mode, allow bad certificates (for development)
    // In release mode, use strict certificate validation
    if (kDebugMode) {
      // For development: Allow bad certificates
      // WARNING: This should only be used in development!
      final adapter = IOHttpClientAdapter();
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (
          X509Certificate cert,
          String host,
          int port,
        ) {
          debugPrint(
            '⚠️ SSL Certificate Warning: Allowing bad certificate for $host',
          );
          return true; // Allow bad certificates in debug mode
        };
        return client;
      };
      _dio.httpClientAdapter = adapter;
    }
    // In release mode, default strict SSL validation is used
  }

  /// Initialize API Service - Fetch base URL and all endpoints at startup
  /// Call this once when the app launches
  Future<void> initialize() async {
    // Fast path: usable base URL + at least some endpoints already in memory.
    if (_isInitialized &&
        _cachedBaseUrl != null &&
        _cachedBaseUrl!.trim().isNotEmpty &&
        _cachedEndpoints.isNotEmpty) {
      debugPrint('✅ API Service already initialized');
      return;
    }

    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _doInitialize();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInitialize() async {
    try {
      debugPrint('🚀 Initializing API Service...');

      _hydrateFromLocalCache();

      // If we already have a cached base URL (common after first launch),
      // mark usable immediately so deep links / first paint are not blocked.
      final hadCachedBase =
          _cachedBaseUrl != null && _cachedBaseUrl!.trim().isNotEmpty;

      // Step 1: Fetch base URL from Realtime Database (with timeout)
      try {
        await _fetchBaseUrl().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('⚠️ Base URL fetch timed out / failed: $e');
        if (!hadCachedBase) {
          _hydrateFromLocalCache();
        }
      }

      // Step 2: Fetch image base URL from Realtime Database
      try {
        await _fetchImageBaseUrl().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Image Base URL fetch skipped: $e');
      }

      // Step 3: Fetch all endpoints from Firestore (keep local cache if remote fails)
      try {
        await _fetchAllEndpoints().timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('⚠️ Endpoints fetch timed out / failed: $e');
        if (_cachedEndpoints.isEmpty) {
          _hydrateEndpointsFromLocalCache();
        }
      }

      // Step 4: Isolated V2 host config (soft-fail — must not block V1).
      try {
        await V2ApiConfigService.instance.initialize().timeout(
          const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('⚠️ V2 API config init skipped: $e');
      }

      if (_cachedBaseUrl != null && _cachedBaseUrl!.trim().isNotEmpty) {
        _isInitialized = true;
        debugPrint('✅ API Service initialized successfully');
        debugPrint('   Base URL: $_cachedBaseUrl');
        debugPrint('   Endpoints loaded: ${_cachedEndpoints.length}');
      } else {
        throw Exception('Base URL unavailable after initialize()');
      }
    } catch (e) {
      debugPrint('❌ Error initializing API Service: $e');
      _hydrateFromLocalCache();
      if (_cachedBaseUrl != null && _cachedBaseUrl!.trim().isNotEmpty) {
        _isInitialized = true;
        debugPrint('✅ API Service using cached URLs (offline/fallback)');
        return;
      }
      rethrow;
    }
  }

  void _hydrateFromLocalCache() {
    final fromDefine = _stagingBaseUrlOverride;
    if (fromDefine != null) {
      _cachedBaseUrl = fromDefine;
    } else {
      final cachedIp = StorageService.getRealtimeDbCache('ipAddress');
      if (cachedIp != null) {
        final asString = cachedIp.toString().trim();
        if (asString.isNotEmpty) {
          _cachedBaseUrl = asString;
        }
      }
    }

    final cachedImageBase = StorageService.getImageBaseUrlCache();
    if (cachedImageBase != null && cachedImageBase.isNotEmpty) {
      _cachedImageBaseUrl = cachedImageBase;
    }

    _hydrateEndpointsFromLocalCache();
  }

  void _hydrateEndpointsFromLocalCache() {
    final cached = StorageService.getApiEndpointsCache();
    if (cached.isEmpty) return;
    // Local cache is a base layer; never wipe fresher in-memory keys.
    // Skip isolated V2 host doc keys so they never enter the V1 endpoint map.
    cached.forEach((key, value) {
      if (_isV2ConfigEndpointKey(key)) return;
      _cachedEndpoints.putIfAbsent(key, () => value);
    });
    debugPrint(
      '📦 Hydrated ${_cachedEndpoints.length} API endpoints from local cache',
    );
  }

  static bool _isV2ConfigEndpointKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'v2' ||
        lower.startsWith('v2/') ||
        lower == V2ApiConfigService.firestoreModule ||
        lower.startsWith('${V2ApiConfigService.firestoreModule}/');
  }

  /// Ensure base URL + [module]/[endpointKey] are available before a request.
  /// Retries Firestore when cold start raced ahead of endpoint download.
  Future<void> ensureEndpoint(String module, String endpointKey) async {
    await initialize();

    if (_resolveEndpoint(module, endpointKey) != null) {
      return;
    }

    debugPrint(
      '🔄 Endpoint "$endpointKey" missing in "$module" — refreshing from Firestore',
    );
    await _refreshEndpoints();

    if (_resolveEndpoint(module, endpointKey) != null) {
      return;
    }

    // Last chance: disk cache may have been written by a parallel refresh.
    _hydrateEndpointsFromLocalCache();
    if (_resolveEndpoint(module, endpointKey) != null) {
      return;
    }

    throw Exception(
      'Endpoint "$endpointKey" not found in module "$module". '
      'Make sure the endpoint exists in Firestore and API Service is initialized.',
    );
  }

  Future<void> _refreshEndpoints() async {
    if (_endpointsRefreshFuture != null) {
      await _endpointsRefreshFuture;
      return;
    }
    _endpointsRefreshFuture = () async {
      try {
        await _fetchAllEndpoints().timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('⚠️ Endpoint refresh failed: $e');
      }
    }();
    try {
      await _endpointsRefreshFuture;
    } finally {
      _endpointsRefreshFuture = null;
    }
  }

  /// Apply base URL known from bootstrap (Realtime DB / cache) without waiting.
  ///
  /// Also honors compile-time `--dart-define=NEWSON_API_BASE_URL=...` for
  /// local/staging validation without changing production Firebase `ipAddress`.
  void applyKnownBaseUrl(String? url) {
    final fromDefine = _stagingBaseUrlOverride;
    if (fromDefine != null) {
      _cachedBaseUrl = fromDefine;
      return;
    }
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _cachedBaseUrl = trimmed;
  }

  /// Non-empty only when `--dart-define=NEWSON_API_BASE_URL=` is set.
  static String? get _stagingBaseUrlOverride {
    const raw = String.fromEnvironment('NEWSON_API_BASE_URL');
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Fetch base URL from Firebase Realtime Database
  Future<void> _fetchBaseUrl() async {
    final fromDefine = _stagingBaseUrlOverride;
    if (fromDefine != null) {
      _cachedBaseUrl = fromDefine;
      debugPrint('✅ Base URL from NEWSON_API_BASE_URL: $_cachedBaseUrl');
      return;
    }
    try {
      final dbRef = _database.ref();
      final snapshot = await dbRef.child('ipAddress').get();

      if (snapshot.exists) {
        _cachedBaseUrl = snapshot.value.toString();
        await StorageService.saveRealtimeDbCache('ipAddress', _cachedBaseUrl);
        debugPrint('✅ Base URL fetched: $_cachedBaseUrl');
      } else {
        throw Exception('Base URL not found in Realtime Database');
      }
    } catch (e) {
      debugPrint('❌ Error fetching base URL: $e');
      rethrow;
    }
  }

  /// Fetch image base URL from Firebase Realtime Database
  Future<void> _fetchImageBaseUrl() async {
    try {
      final dbRef = _database.ref();
      final snapshot = await dbRef.child('imageBaseURL').get();

      if (snapshot.exists) {
        _cachedImageBaseUrl = snapshot.value.toString();
        await StorageService.saveImageBaseUrlCache(_cachedImageBaseUrl!);
        debugPrint('✅ Image Base URL fetched: $_cachedImageBaseUrl');
      } else {
        debugPrint('⚠️ Image Base URL not found in Realtime Database');
        // Don't throw - imageBaseURL is optional
      }
    } catch (e) {
      debugPrint('❌ Error fetching image base URL: $e');
      // Don't rethrow - imageBaseURL is optional
    }
  }

  /// Get cached image base URL
  String? getImageBaseUrl() => _cachedImageBaseUrl;

  /// Fetch all endpoints from Firestore apiEndPoints collection
  Future<void> _fetchAllEndpoints() async {
    try {
      final collectionRef = _firestore.collection('apiEndPoints');
      final querySnapshot = await collectionRef.get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('⚠️ No endpoints found in apiEndPoints collection');
        return;
      }

      int endpointCount = 0;
      for (final doc in querySnapshot.docs) {
        final module = doc.id;
        // V2 host config lives under apiEndPoints/v2 — loaded by V2ApiConfigService.
        if (module.toLowerCase() == V2ApiConfigService.firestoreModule) {
          continue;
        }
        final data = doc.data();

        // Store all fields from each document as endpoints
        data.forEach((endpointKey, endpointValue) {
          final cacheKey = '$module/$endpointKey';
          _cachedEndpoints[cacheKey] = endpointValue.toString();
          endpointCount++;
        });

        debugPrint('✅ Loaded module "$module" with ${data.length} endpoints');
      }

      // Drop any stale v2/* keys from older caches before persisting V1 map.
      _cachedEndpoints.removeWhere((key, _) => _isV2ConfigEndpointKey(key));

      await StorageService.saveApiEndpointsCache(
        Map<String, String>.from(_cachedEndpoints),
      );

      debugPrint('✅ Total endpoints loaded: $endpointCount');
    } catch (e) {
      debugPrint('❌ Error fetching endpoints: $e');
      rethrow;
    }
  }

  /// Get base URL (from cache, must be initialized first)
  String getBaseUrl() {
    if (_cachedBaseUrl == null) {
      throw Exception(
        'API Service not initialized. Call ApiService().initialize() first.',
      );
    }
    return _cachedBaseUrl!;
  }

  /// Resolve endpoint with exact key, then case-insensitive / alias match.
  String? _resolveEndpoint(String module, String endpointKey) {
    final cacheKey = '$module/$endpointKey';
    final exact = _cachedEndpoints[cacheKey];
    if (exact != null && exact.isNotEmpty) return exact;

    final wanted = '$module/$endpointKey'.toLowerCase();
    for (final entry in _cachedEndpoints.entries) {
      if (entry.key.toLowerCase() == wanted && entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    // Aliases for keys that may differ between Firestore docs and app code.
    const aliases = <String, List<String>>{
      'foryou': ['for_you', 'for-you', 'for you'],
      'breakingnews': ['breaking_news', 'breaking-news'],
    };
    final aliasList = aliases[endpointKey.toLowerCase()] ?? const <String>[];
    for (final alias in aliasList) {
      final aliasKey = '$module/$alias';
      final value = _cachedEndpoints[aliasKey];
      if (value != null && value.isNotEmpty) return value;
      for (final entry in _cachedEndpoints.entries) {
        if (entry.key.toLowerCase() == aliasKey.toLowerCase() &&
            entry.value.isNotEmpty) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// Get endpoint (from cache, must be initialized first)
  /// [module] - The document name in apiEndPoints collection (e.g., 'auth')
  /// [endpointKey] - The field name in the document (e.g., 'signUp')
  String getEndpoint(String module, String endpointKey) {
    final resolved = _resolveEndpoint(module, endpointKey);
    if (resolved != null) return resolved;

    throw Exception(
      'Endpoint "$endpointKey" not found in module "$module". '
      'Make sure the endpoint exists in Firestore and API Service is initialized.',
    );
  }

  /// Full URL for endpoints with a path segment (e.g. .../getNewsByIdMobile/:id).
  String buildUrlWithPathSegment(
    String module,
    String endpointKey,
    String pathSegment,
  ) {
    final base = buildUrl(module, endpointKey);
    final segment = Uri.encodeComponent(pathSegment);
    if (base.endsWith('/')) return '$base$segment';
    return '$base/$segment';
  }

  /// Build URL using [fallbackRelativePath] when Firestore endpoint is missing.
  String buildUrlWithPathSegmentOrFallback(
    String module,
    String endpointKey,
    String pathSegment, {
    required String fallbackRelativePath,
  }) {
    try {
      return buildUrlWithPathSegment(module, endpointKey, pathSegment);
    } catch (_) {
      final baseUri = Uri.parse(getBaseUrl());
      final domain = baseUri.origin;
      final path = fallbackRelativePath.startsWith('/')
          ? fallbackRelativePath
          : '/$fallbackRelativePath';
      final segment = Uri.encodeComponent(pathSegment);
      return '$domain$path/$segment';
    }
  }

  /// Build full URL from base URL and endpoint
  String buildUrl(String module, String endpointKey) {
    final baseUrl = getBaseUrl();
    final endpoint = getEndpoint(module, endpointKey);

    debugPrint('🔗 Building URL - Module: $module, EndpointKey: $endpointKey');
    debugPrint('🔗 Base URL: $baseUrl');
    debugPrint('🔗 Endpoint from Firebase: $endpoint');

    // If endpoint is already a full URL, use it directly
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      debugPrint('🔗 Using full URL endpoint: $endpoint');
      return endpoint;
    }

    // Parse base URL to get origin (scheme+host+port — required for staging :8010).
    final baseUri = Uri.parse(baseUrl);
    final domain = baseUri.origin;

    // If endpoint starts with /api/, use it directly with domain
    // This handles cases where endpoint is stored as full path like /api/bookmark/removeBookmark
    if (endpoint.startsWith('/api/')) {
      final fullUrl = '$domain$endpoint';
      debugPrint('🔗 Endpoint starts with /api/, building: $fullUrl');
      return fullUrl;
    }

    // If endpoint starts with /, append to domain
    if (endpoint.startsWith('/')) {
      final fullUrl = '$domain$endpoint';
      debugPrint('🔗 Endpoint starts with /, building: $fullUrl');
      return fullUrl;
    }

    // If baseUrl has a path component, preserve it
    final basePath =
        baseUri.path.isNotEmpty && baseUri.path != '/' ? baseUri.path : '';
    final cleanBasePath =
        basePath.endsWith('/')
            ? basePath.substring(0, basePath.length - 1)
            : basePath;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    final finalUrl = '$domain$cleanBasePath$cleanEndpoint';
    debugPrint('🔗 Final URL: $finalUrl');
    return finalUrl;
  }

  /// GET with path segment appended to the endpoint (e.g. article id).
  Future<ApiResponse> getWithPathSegment(
    String module,
    String endpointKey,
    String pathSegment, {
    required String fallbackRelativePath,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
      final url = buildUrlWithPathSegmentOrFallback(
        module,
        endpointKey,
        pathSegment,
        fallbackRelativePath: fallbackRelativePath,
      );

      debugPrint('🌐 GET Request (path): $url');

      final finalHeaders = <String, String>{};
      if (headers != null) finalHeaders.addAll(headers);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
      }

      final response = await _dio.get(
        url,
        options: Options(headers: finalHeaders),
      );

      return _handleDioResponse(response);
    } on DioException catch (e) {
      debugPrint('❌ GET path Request Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ GET path Request Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Make GET request
  Future<ApiResponse> get(
    String module,
    String endpointKey, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
      await ensureEndpoint(module, endpointKey);
      final url = buildUrl(module, endpointKey);

      debugPrint('🌐 GET Request: $url');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        debugPrint('📋 Query Parameters: $queryParameters');
      }

      // Add Bearer token to headers if provided
      final finalHeaders = <String, String>{};
      if (headers != null) {
        finalHeaders.addAll(headers);
      }
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
        debugPrint('🔐 Bearer token added to request');
      }

      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: finalHeaders),
      );

      return _handleDioResponse(response);
    } on DioException catch (e) {
      debugPrint('❌ GET Request Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ GET Request Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Make GET request with support for multiple values per parameter
  /// Used for APIs that expect: ?category=top&category=lifestyle
  Future<ApiResponse> getWithMultipleParams(
    String module,
    String endpointKey, {
    Map<String, dynamic>? queryParameters,
    Map<String, List<String>>? multiValueParams,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
      await ensureEndpoint(module, endpointKey);
      final baseUrl = buildUrl(module, endpointKey);
      
      // Build query string manually to support multiple values for same key
      final queryParts = <String>[];
      
      // Add single-value parameters
      if (queryParameters != null) {
        queryParameters.forEach((key, value) {
          queryParts.add('$key=${Uri.encodeComponent(value.toString())}');
        });
      }
      
      // Add multi-value parameters (e.g., category=top&category=lifestyle)
      if (multiValueParams != null) {
        multiValueParams.forEach((key, values) {
          for (final value in values) {
            queryParts.add('$key=${Uri.encodeComponent(value)}');
          }
        });
      }
      
      final url = queryParts.isNotEmpty 
          ? '$baseUrl?${queryParts.join('&')}'
          : baseUrl;

      debugPrint('🌐 GET Request (multi-param): $url');

      // Add Bearer token to headers if provided
      final finalHeaders = <String, String>{};
      if (headers != null) {
        finalHeaders.addAll(headers);
      }
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
        debugPrint('🔐 Bearer token added to request');
      }

      final response = await _dio.get(
        url,
        options: Options(headers: finalHeaders),
      );

      return _handleDioResponse(response);
    } on DioException catch (e) {
      debugPrint('❌ GET Request Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ GET Request Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Make POST request
  Future<ApiResponse> post(
    String module,
    String endpointKey, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
      await ensureEndpoint(module, endpointKey);
      final url = buildUrl(module, endpointKey);

      debugPrint('🌐 POST Request: $url');
      debugPrint('📦 Request Body: ${jsonEncode(body)}');

      // Add Bearer token to headers if provided
      final finalHeaders = <String, String>{};
      if (headers != null) {
        finalHeaders.addAll(headers);
      }
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
        debugPrint('🔐 Bearer token added to request');
      }

      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      // Check if response indicates an error (4xx or 5xx)
      if (response.statusCode != null && response.statusCode! >= 400) {
        // Handle as error response - extract server error message
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }

      return _handleDioResponse(response);
    } on DioException catch (e) {
      debugPrint('❌ POST Request Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ POST Request Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Make PUT request
  Future<ApiResponse> put(
    String module,
    String endpointKey, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
      await ensureEndpoint(module, endpointKey);
      final url = buildUrl(module, endpointKey);

      debugPrint('🌐 PUT Request: $url');
      debugPrint('📦 Request Body: ${jsonEncode(body)}');

      // Add Bearer token to headers if provided
      final finalHeaders = <String, String>{};
      if (headers != null) {
        finalHeaders.addAll(headers);
      }
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
        debugPrint('🔐 Bearer token added to request');
      }

      final response = await _dio.put(
        url,
        data: body,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      // Check if response indicates an error (4xx or 5xx)
      if (response.statusCode != null && response.statusCode! >= 400) {
        // Handle as error response - extract server error message
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }

      return _handleDioResponse(response);
    } on DioException catch (e) {
      debugPrint('❌ PUT Request Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ PUT Request Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Make DELETE request
  /// [pathParameters] - Map of path parameters to replace in the endpoint URL
  ///   Example: {'id': '123'} will replace {id} or :id in the endpoint
  Future<ApiResponse> delete(
    String module,
    String endpointKey, {
    Map<String, String>? headers,
    String? bearerToken,
    Map<String, String>? queryParameters,
    Map<String, String>? pathParameters,
  }) async {
    try {
      await ensureEndpoint(module, endpointKey);
      final url = buildUrl(module, endpointKey);

      debugPrint('🌐 DELETE Request: $url');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        debugPrint('📋 Query Parameters: $queryParameters');
      }

      // Add Bearer token to headers if provided
      final finalHeaders = <String, String>{};
      if (headers != null) {
        finalHeaders.addAll(headers);
        debugPrint('📋 Custom headers added: ${headersForLog(headers)}');
      }
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
        debugPrint('🔐 Bearer token added to request');
      }

      // Replace path parameters in URL if provided
      String finalUrl = url;
      if (pathParameters != null && pathParameters.isNotEmpty) {
        debugPrint('🔧 Processing path parameters: $pathParameters');
        debugPrint('🔧 Original URL: $finalUrl');

        // First, try to replace {param} or :param patterns in the URL
        bool hasPlaceholders = false;
        pathParameters.forEach((key, value) {
          if (finalUrl.contains('{$key}') || finalUrl.contains(':$key')) {
            hasPlaceholders = true;
            finalUrl = finalUrl.replaceAll('{$key}', value);
            finalUrl = finalUrl.replaceAll(':$key', value);
            debugPrint('🔧 Replaced placeholder {$key} with $value');
          }
        });

        debugPrint('🔧 URL after placeholder replacement: $finalUrl');
        debugPrint('🔧 Has placeholders: $hasPlaceholders');
        debugPrint('🔧 Final URL contains {: ${finalUrl.contains('{')}');
        debugPrint('🔧 Final URL contains :: ${finalUrl.contains(':')}');

        // If URL doesn't have placeholder patterns, append path parameters to the end
        // This handles cases where the endpoint is stored as /api/bookmark/removeBookmark
        // and we need to append /{newsId} to make it /api/bookmark/removeBookmark/{newsId}
        if (!hasPlaceholders) {
          final paramValues = pathParameters.values.toList();
          final allParams = paramValues.join('/');
          debugPrint('🔧 Appending path parameters to URL: $allParams');

          // Remove trailing slash if present, then append parameters
          final cleanUrl =
              finalUrl.endsWith('/')
                  ? finalUrl.substring(0, finalUrl.length - 1)
                  : finalUrl;
          finalUrl = '$cleanUrl/$allParams';

          debugPrint('🔧 Final URL after appending: $finalUrl');
        } else {
          debugPrint('✅ URL already had placeholders, replaced them');
        }

        debugPrint('✅ Final URL with path parameters: $finalUrl');
        debugPrint('📋 Path parameters used: $pathParameters');
      } else {
        debugPrint(
          '⚠️ No path parameters provided, using original URL: $finalUrl',
        );
      }

      // Log the final URL that will be used
      debugPrint('🌐 Final DELETE URL: $finalUrl');

      debugPrint('📤 Final DELETE headers: ${headersForLog(finalHeaders)}');
      if (pathParameters != null) {
        debugPrint('📤 Path parameters: $pathParameters');
      }

      final response = await _dio.delete(
        finalUrl,
        queryParameters: queryParameters,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      // Check if response indicates an error (4xx or 5xx)
      if (response.statusCode != null && response.statusCode! >= 400) {
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }

      return _handleDioResponse(response);
    } on DioException catch (e) {
      debugPrint('❌ DELETE Request Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ DELETE Request Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// DELETE using an absolute-or-relative API path (bypasses Firestore endpoint keys).
  /// Example: `/api/bookmark/removeAllBookmarks`
  Future<ApiResponse> deleteByPath(
    String relativeOrAbsolutePath, {
    Map<String, String>? headers,
    String? bearerToken,
    Map<String, String>? queryParameters,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    try {
      final url = await _resolvePathUrlReady(
        relativeOrAbsolutePath,
        useV2Host: useV2Host,
        baseUrlOverride: baseUrlOverride,
      );

      final finalHeaders = <String, String>{};
      if (headers != null) finalHeaders.addAll(headers);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
      }

      debugPrint('🌐 DELETE (by path) Request: $url');
      final response = await _dio.delete(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }

      return _handleDioResponse(response);
    } on V2ApiConfigException {
      rethrow;
    } on DioException catch (e) {
      debugPrint('❌ DELETE (by path) Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ DELETE (by path) Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  String _resolvePathUrl(
    String relativeOrAbsolutePath, {
    bool useV2Host = false,
    String? baseUrlOverride,
  }) {
    if (relativeOrAbsolutePath.startsWith('http://') ||
        relativeOrAbsolutePath.startsWith('https://')) {
      return relativeOrAbsolutePath;
    }

    final String base;
    if (baseUrlOverride != null && baseUrlOverride.trim().isNotEmpty) {
      base = baseUrlOverride.trim();
    } else if (useV2Host) {
      // Explicit V2 host — never fall back to V1 ipAddress / NEWSON_API_BASE_URL.
      base = V2ApiConfigService.instance.requireBaseUrl();
    } else {
      base = getBaseUrl();
    }

    return joinApiBaseAndPath(base, relativeOrAbsolutePath);
  }

  /// Resolves path URL; when [useV2Host] awaits shared V2 config readiness first.
  Future<String> _resolvePathUrlReady(
    String relativeOrAbsolutePath, {
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    if (useV2Host &&
        (baseUrlOverride == null || baseUrlOverride.trim().isEmpty)) {
      await V2ApiConfigService.instance.ensureReady();
    }
    return _resolvePathUrl(
      relativeOrAbsolutePath,
      useV2Host: useV2Host,
      baseUrlOverride: baseUrlOverride,
    );
  }

  /// Joins an API origin with a relative path (preserves non-default ports).
  /// Absolute http(s) paths are returned unchanged.
  @visibleForTesting
  static String joinApiBaseAndPath(String baseUrl, String relativeOrAbsolutePath) {
    if (relativeOrAbsolutePath.startsWith('http://') ||
        relativeOrAbsolutePath.startsWith('https://')) {
      return relativeOrAbsolutePath;
    }
    final baseUri = Uri.parse(baseUrl.trim());
    final domain = baseUri.origin;
    final path = relativeOrAbsolutePath.startsWith('/')
        ? relativeOrAbsolutePath
        : '/$relativeOrAbsolutePath';
    return '$domain$path';
  }

  /// GET by absolute-or-relative API path (bypasses Firestore endpoint keys).
  ///
  /// Set [useV2Host] to resolve against the isolated V2 Firebase base URL.
  Future<ApiResponse> getByPath(
    String relativeOrAbsolutePath, {
    Map<String, String>? headers,
    String? bearerToken,
    Map<String, String>? queryParameters,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    try {
      final url = await _resolvePathUrlReady(
        relativeOrAbsolutePath,
        useV2Host: useV2Host,
        baseUrlOverride: baseUrlOverride,
      );
      final finalHeaders = <String, String>{};
      if (headers != null) finalHeaders.addAll(headers);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
      }
      debugPrint('🌐 GET (by path) Request: $url');
      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 400) {
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }
      return _handleDioResponse(response);
    } on V2ApiConfigException {
      rethrow;
    } on DioException catch (e) {
      debugPrint('❌ GET (by path) Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ GET (by path) Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// POST by absolute-or-relative API path (bypasses Firestore endpoint keys).
  Future<ApiResponse> postByPath(
    String relativeOrAbsolutePath, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    try {
      final url = await _resolvePathUrlReady(
        relativeOrAbsolutePath,
        useV2Host: useV2Host,
        baseUrlOverride: baseUrlOverride,
      );
      final finalHeaders = <String, String>{};
      if (headers != null) finalHeaders.addAll(headers);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
      }
      debugPrint('🌐 POST (by path) Request: $url');
      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 400) {
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }
      return _handleDioResponse(response);
    } on V2ApiConfigException {
      rethrow;
    } on DioException catch (e) {
      debugPrint('❌ POST (by path) Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ POST (by path) Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// PUT by absolute-or-relative API path (V2 preference routes, etc.).
  Future<ApiResponse> putByPath(
    String relativeOrAbsolutePath, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    try {
      final url = await _resolvePathUrlReady(
        relativeOrAbsolutePath,
        useV2Host: useV2Host,
        baseUrlOverride: baseUrlOverride,
      );
      final finalHeaders = <String, String>{};
      if (headers != null) finalHeaders.addAll(headers);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
      }
      debugPrint('🌐 PUT (by path) Request: $url');
      final response = await _dio.put(
        url,
        data: body,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 400) {
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }
      return _handleDioResponse(response);
    } on V2ApiConfigException {
      rethrow;
    } on DioException catch (e) {
      debugPrint('❌ PUT (by path) Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ PUT (by path) Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// PATCH by absolute-or-relative API path.
  Future<ApiResponse> patchByPath(
    String relativeOrAbsolutePath, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
    bool useV2Host = false,
    String? baseUrlOverride,
  }) async {
    try {
      final url = await _resolvePathUrlReady(
        relativeOrAbsolutePath,
        useV2Host: useV2Host,
        baseUrlOverride: baseUrlOverride,
      );
      final finalHeaders = <String, String>{};
      if (headers != null) finalHeaders.addAll(headers);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $bearerToken';
      }
      debugPrint('🌐 PATCH (by path) Request: $url');
      final response = await _dio.patch(
        url,
        data: body,
        options: Options(
          headers: finalHeaders,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 400) {
        return _handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          ),
        );
      }
      return _handleDioResponse(response);
    } on V2ApiConfigException {
      rethrow;
    } on DioException catch (e) {
      debugPrint('❌ PATCH (by path) Error: ${e.message}');
      return _handleDioError(e);
    } catch (e) {
      debugPrint('❌ PATCH (by path) Error: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Handle Dio response
  ApiResponse _handleDioResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    final isSuccess = statusCode >= 200 && statusCode < 300;

    debugPrint('📥 Response Status: $statusCode');
    debugPrint('📥 Response Body: ${response.data}');

    try {
      final data = response.data;

      if (isSuccess) {
        return ApiResponse(
          success: true,
          data: data,
          error: null,
          statusCode: statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          data: data,
          error:
              data is Map
                  ? (data['message'] ?? data['error'] ?? 'Request failed')
                  : 'Request failed with status $statusCode',
          statusCode: statusCode,
        );
      }
    } catch (e) {
      // If parsing fails, return raw response
      return ApiResponse(
        success: isSuccess,
        data: response.data,
        error: isSuccess ? null : 'Request failed with status $statusCode',
        statusCode: statusCode,
      );
    }
  }

  /// Handle Dio errors
  ApiResponse _handleDioError(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    dynamic errorData;

    // Check if we have a response (even for 500 errors, Dio might have response data)
    if (error.response != null) {
      errorData = error.response?.data;
      debugPrint('📥 Error Response Status: $statusCode');
      debugPrint('📥 Error Response Body: $errorData');
      debugPrint('📥 Error Response Headers: ${error.response?.headers}');
    } else {
      debugPrint('📥 Error (no response): ${error.message}');
      debugPrint('📥 Error Type: ${error.type}');
    }

    // Handle different error types
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiResponse(
        success: false,
        data: null,
        error: 'Request timeout. Please check your internet connection.',
        statusCode: 0,
      );
    } else if (error.type == DioExceptionType.connectionError) {
      return ApiResponse(
        success: false,
        data: null,
        error: 'Connection error. Please check your internet connection.',
        statusCode: 0,
      );
    }

    // Extract error message from response
    String errorMessage = 'Request failed';

    // Try to extract error message from response data
    if (errorData != null) {
      if (errorData is Map) {
        // Try multiple common error message fields
        errorMessage =
            errorData['message'] ??
            errorData['error'] ??
            errorData['errorMessage'] ??
            errorData['msg'] ??
            errorData['detail'] ??
            errorData['description'] ??
            'Request failed';
      } else if (errorData is String) {
        errorMessage = errorData;
      }
    }

    // If no error message found in response, use status code specific messages
    if (errorMessage == 'Request failed' || errorMessage.isEmpty) {
      switch (statusCode) {
        case 400:
          errorMessage = 'Bad request. Please check your input.';
          break;
        case 401:
          errorMessage = 'Unauthorized. Please sign in again.';
          break;
        case 403:
          errorMessage = 'Access forbidden.';
          break;
        case 404:
          errorMessage = 'Resource not found.';
          break;
        case 500:
          errorMessage =
              'Server error. Please try again later or contact support.';
          break;
        case 502:
          errorMessage = 'Bad gateway. Server is temporarily unavailable.';
          break;
        case 503:
          errorMessage = 'Service unavailable. Please try again later.';
          break;
        default:
          if (statusCode > 0) {
            errorMessage = 'Request failed with status $statusCode';
          } else {
            errorMessage = error.message ?? 'Unknown error occurred';
          }
      }
    }

    // Log the final error message
    debugPrint('❌ Final Error Message: $errorMessage');

    return ApiResponse(
      success: false,
      data: errorData,
      error: errorMessage,
      statusCode: statusCode,
    );
  }

  /// Check if API Service is initialized
  bool get isInitialized => _isInitialized;

  /// Refresh/Re-initialize API Service (useful when endpoints change)
  Future<void> refresh() async {
    _isInitialized = false;
    _cachedBaseUrl = null;
    _cachedEndpoints.clear();
    await initialize();
  }

  /// Clear cached base URL (useful for testing or when base URL changes)
  void clearBaseUrlCache() {
    _cachedBaseUrl = null;
    _isInitialized = false;
    debugPrint('🗑️ Base URL cache cleared');
  }

  /// Clear cached endpoints (useful for testing or when endpoints change)
  void clearEndpointsCache() {
    _cachedEndpoints.clear();
    _isInitialized = false;
    debugPrint('🗑️ Endpoints cache cleared');
  }

  /// Clear all caches
  void clearAllCaches() {
    clearBaseUrlCache();
    clearEndpointsCache();
  }
}

/// API Response model
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.data,
    required this.error,
    required this.statusCode,
  });

  @override
  String toString() {
    return 'ApiResponse(success: $success, statusCode: $statusCode, error: $error, data: $data)';
  }
}
