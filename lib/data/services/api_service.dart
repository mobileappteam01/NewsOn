import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Reusable API Service for making HTTP requests
/// - Fetches base URL from Firebase Realtime Database (ipAddress)
/// - Fetches endpoints from Firestore (apiEndPoints collection)
/// - Handles all HTTP methods with proper error handling
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initializeDio();
  }

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedBaseUrl;
  String? _cachedImageBaseUrl;
  final Map<String, String> _cachedEndpoints = {};
  bool _isInitialized = false;

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
    if (_isInitialized) {
      debugPrint('✅ API Service already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing API Service...');

      // Step 1: Fetch base URL from Realtime Database
      await _fetchBaseUrl();

      // Step 2: Fetch image base URL from Realtime Database
      await _fetchImageBaseUrl();

      // Step 3: Fetch all endpoints from Firestore
      await _fetchAllEndpoints();

      _isInitialized = true;
      debugPrint('✅ API Service initialized successfully');
      debugPrint('   Base URL: $_cachedBaseUrl');
      debugPrint('   Endpoints loaded: ${_cachedEndpoints.length}');
    } catch (e) {
      debugPrint('❌ Error initializing API Service: $e');
      rethrow;
    }
  }

  /// Fetch base URL from Firebase Realtime Database
  Future<void> _fetchBaseUrl() async {
    try {
      final dbRef = _database.ref();
      final snapshot = await dbRef.child('ipAddress').get();

      if (snapshot.exists) {
        _cachedBaseUrl = snapshot.value.toString();
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
        final data = doc.data();

        // Store all fields from each document as endpoints
        data.forEach((endpointKey, endpointValue) {
          final cacheKey = '$module/$endpointKey';
          _cachedEndpoints[cacheKey] = endpointValue.toString();
          endpointCount++;
        });

        debugPrint('✅ Loaded module "$module" with ${data.length} endpoints');
      }

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

  /// Get endpoint (from cache, must be initialized first)
  /// [module] - The document name in apiEndPoints collection (e.g., 'auth')
  /// [endpointKey] - The field name in the document (e.g., 'signUp')
  String getEndpoint(String module, String endpointKey) {
    final cacheKey = '$module/$endpointKey';

    if (_cachedEndpoints.containsKey(cacheKey)) {
      return _cachedEndpoints[cacheKey]!;
    }

    throw Exception(
      'Endpoint "$endpointKey" not found in module "$module". '
      'Make sure the endpoint exists in Firestore and API Service is initialized.',
    );
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

    // Parse base URL to get domain
    final baseUri = Uri.parse(baseUrl);
    final domain = '${baseUri.scheme}://${baseUri.host}';

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

  /// Make GET request
  Future<ApiResponse> get(
    String module,
    String endpointKey, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
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

  /// Make POST request
  Future<ApiResponse> post(
    String module,
    String endpointKey, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? bearerToken,
  }) async {
    try {
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
      final url = buildUrl(module, endpointKey);

      debugPrint('🌐 DELETE Request: $url');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        debugPrint('📋 Query Parameters: $queryParameters');
      }

      // Add Bearer token to headers if provided
      final finalHeaders = <String, String>{};
      if (headers != null) {
        finalHeaders.addAll(headers);
        debugPrint('📋 Custom headers added: $headers');
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

      debugPrint('📤 Final DELETE headers: $finalHeaders');
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
