import 'dart:convert';

/// Model for Dynamic API Configuration from Firebase Remote Config
class ApiConfigModel {
  // Base URL
  final String baseUrl;

  // Endpoints
  final String breakingNewsEndPoint;
  final String latestNewsEndpoint;
  final String archiveNewsEndpoint;
  final String searchEndpoint;

  // Query Parameters
  final String apiKeyParam;
  final String categoryParam;
  final String countryParam;
  final String languageParam;
  final String queryParam;
  final String pageParam;
  final String sizeParam;

  // Default Values
  final String defaultLanguage;
  final String defaultCountry;
  final int defaultPageSize;

  // Request timeout in seconds
  final int requestTimeoutSeconds;

  // Categories (stored as JSON string, will be parsed to List)
  final String categoriesJson;

  // API Key (can be overridden from Remote Config)
  final String? apiKey;

  ApiConfigModel({
    this.baseUrl = 'https://newsdata.io/api/1',
    this.breakingNewsEndPoint = '/latest',
    this.latestNewsEndpoint = '/news',
    this.archiveNewsEndpoint = '/archive',
    this.searchEndpoint = '/news',
    this.apiKeyParam = 'apikey',
    this.categoryParam = 'category',
    this.countryParam = 'country',
    this.languageParam = 'language',
    this.queryParam = 'q',
    this.pageParam = 'page',
    this.sizeParam = 'size',
    this.defaultLanguage = 'en',
    this.defaultCountry = 'us',
    this.defaultPageSize = 10,
    this.requestTimeoutSeconds = 30,
    this.categoriesJson =
        '["top","business","entertainment","environment","food","health","politics","science","sports","technology","tourism","world"]',
    this.apiKey,
  });

  /// Parse categories from JSON string
  List<String> get categories {
    try {
      final List<dynamic> parsed = json.decode(categoriesJson);
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      // Return default categories if parsing fails
      return [
        'top',
        'business',
        'entertainment',
        'environment',
        'food',
        'health',
        'politics',
        'science',
        'sports',
        'technology',
        'tourism',
        'world',
      ];
    }
  }

  /// Get request timeout as Duration
  Duration get requestTimeout => Duration(seconds: requestTimeoutSeconds);

  /// Create from JSON (for Remote Config)
  factory ApiConfigModel.fromJson(Map<String, dynamic> json) {
    return ApiConfigModel(
      baseUrl: json['base_url'] as String? ?? 'https://newsdata.io/api/1',
      breakingNewsEndPoint:
          json['breaking_news_endpoint'] as String? ?? '/latest',
      latestNewsEndpoint: json['latest_news_endpoint'] as String? ?? '/news',
      archiveNewsEndpoint:
          json['archive_news_endpoint'] as String? ?? '/archive',
      searchEndpoint: json['search_endpoint'] as String? ?? '/news',
      apiKeyParam: json['api_key_param'] as String? ?? 'apikey',
      categoryParam: json['category_param'] as String? ?? 'category',
      countryParam: json['country_param'] as String? ?? 'country',
      languageParam: json['language_param'] as String? ?? 'language',
      queryParam: json['query_param'] as String? ?? 'q',
      pageParam: json['page_param'] as String? ?? 'page',
      sizeParam: json['size_param'] as String? ?? 'size',
      defaultLanguage: json['default_language'] as String? ?? 'en',
      defaultCountry: json['default_country'] as String? ?? 'us',
      defaultPageSize: json['default_page_size'] as int? ?? 10,
      requestTimeoutSeconds: json['request_timeout_seconds'] as int? ?? 30,
      categoriesJson:
          json['categories_json'] as String? ??
          '["top","business","entertainment","environment","food","health","politics","science","sports","technology","tourism","world"]',
      apiKey: json['api_key'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'base_url': baseUrl,
      'breaking_news_endpoint': breakingNewsEndPoint,
      'latest_news_endpoint': latestNewsEndpoint,
      'archive_news_endpoint': archiveNewsEndpoint,
      'search_endpoint': searchEndpoint,
      'api_key_param': apiKeyParam,
      'category_param': categoryParam,
      'country_param': countryParam,
      'language_param': languageParam,
      'query_param': queryParam,
      'page_param': pageParam,
      'size_param': sizeParam,
      'default_language': defaultLanguage,
      'default_country': defaultCountry,
      'default_page_size': defaultPageSize,
      'request_timeout_seconds': requestTimeoutSeconds,
      'categories_json': categoriesJson,
      'api_key': apiKey,
    };
  }

  /// Create copy with updated values
  ApiConfigModel copyWith({
    String? baseUrl,
    String? breakingNewsEndPoint,
    String? latestNewsEndpoint,
    String? archiveNewsEndpoint,
    String? searchEndpoint,
    String? apiKeyParam,
    String? categoryParam,
    String? countryParam,
    String? languageParam,
    String? queryParam,
    String? pageParam,
    String? sizeParam,
    String? defaultLanguage,
    String? defaultCountry,
    int? defaultPageSize,
    int? requestTimeoutSeconds,
    String? categoriesJson,
    String? apiKey,
  }) {
    return ApiConfigModel(
      baseUrl: baseUrl ?? this.baseUrl,
      breakingNewsEndPoint: breakingNewsEndPoint ?? this.breakingNewsEndPoint,
      latestNewsEndpoint: latestNewsEndpoint ?? this.latestNewsEndpoint,
      archiveNewsEndpoint: archiveNewsEndpoint ?? this.archiveNewsEndpoint,
      searchEndpoint: searchEndpoint ?? this.searchEndpoint,
      apiKeyParam: apiKeyParam ?? this.apiKeyParam,
      categoryParam: categoryParam ?? this.categoryParam,
      countryParam: countryParam ?? this.countryParam,
      languageParam: languageParam ?? this.languageParam,
      queryParam: queryParam ?? this.queryParam,
      pageParam: pageParam ?? this.pageParam,
      sizeParam: sizeParam ?? this.sizeParam,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultCountry: defaultCountry ?? this.defaultCountry,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
