import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../main.dart';
import '../models/news_response.dart';

/// Service class for handling News API requests
class NewsApiService {
  final http.Client _client;

  NewsApiService({required String apiKey, http.Client? client})
    : _client = client ?? http.Client();

  /// Fetch latest news with optional filters
  Future<NewsResponse> fetchNews({
    String? category,
    String? country,
    String? language,
    String? query,
    String? nextPage,
  }) async {
    try {
      final uri = _buildUri(
        category: category,
        country: country,
        language: language,
        query: query,
        nextPage: nextPage,
      );

      final response = await _client
          .get(uri)
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        return NewsResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception(
          'Invalid API key. Please check your API key in api_constants.dart',
        );
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('No internet connection. Please check your network.');
      }
      rethrow;
    }
  }

  /// Fetch news by category
  Future<NewsResponse> fetchNewsByCategory(
    String category, {
    String? language,
    String? nextPage,
  }) async {
    return fetchNews(
      category: category,
      language: language ?? ApiConstants.defaultLanguage,
      nextPage: nextPage,
    );
  }

  /// Search news by query
  Future<NewsResponse> searchNews(
    String query, {
    String? language,
    String? nextPage,
  }) async {
    return fetchNews(
      query: query,
      language: language ?? ApiConstants.defaultLanguage,
      nextPage: nextPage,
    );
  }

  /// Fetch top/breaking news
  Future<NewsResponse> fetchBreakingNews({
    String? language,
    String? nextPage,
  }) async {
    return fetchNews(
      category: 'top',
      language: language ?? ApiConstants.defaultLanguage,
      nextPage: nextPage,
    );
  }

  /// Fetch archived news by date range
  /// fromDate and toDate should be in format: 'YYYY-MM-DD'
  Future<NewsResponse> fetchArchiveNews({
    String? fromDate,
    String? toDate,
    String? query,
    String? category,
    String? language,
    String? nextPage,
  }) async {
    try {
      final uri = _buildArchiveUri(
        fromDate: fromDate,
        toDate: toDate,
        query: query,
        category: category,
        language: language,
        nextPage: nextPage,
      );

      final response = await _client
          .get(uri)
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return NewsResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception(
          'Invalid API key. Please check your API key in api_constants.dart',
        );
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to load archive news: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('No internet connection. Please check your network.');
      }
      rethrow;
    }
  }

  /// Build URI for archive endpoint with date parameters
  Uri _buildArchiveUri({
    String? fromDate,
    String? toDate,
    String? query,
    String? category,
    String? language,
    String? nextPage,
  }) {
    // Get API key from config if available, otherwise use .env key
    final apiConfig = ApiConstants.getConfig();
    final apiKey =
        apiConfig.apiKey?.isNotEmpty == true ? apiConfig.apiKey! : newsAPIKey;

    final queryParameters = <String, String>{ApiConstants.apiKeyParam: apiKey};

    // Date parameters (required for archive)
    if (fromDate != null && fromDate.isNotEmpty) {
      queryParameters['from_date'] = fromDate;
    }
    if (toDate != null && toDate.isNotEmpty) {
      queryParameters['to_date'] = toDate;
    }

    // If nextPage is provided, use it directly
    if (nextPage != null && nextPage.isNotEmpty) {
      queryParameters[ApiConstants.pageParam] = nextPage;
    }

    // Add optional parameters
    if (category != null && category.isNotEmpty) {
      queryParameters[ApiConstants.categoryParam] = category;
    }
    if (language != null && language.isNotEmpty) {
      queryParameters[ApiConstants.languageParam] = language;
      debugPrint('🌐 Archive API call with language parameter: ${ApiConstants.languageParam}=$language');
    } else {
      debugPrint('⚠️ Archive API call without language parameter - using default');
    }
    if (query != null && query.isNotEmpty) {
      queryParameters[ApiConstants.queryParam] = query;
    }

    // Build URL using dynamic base URL and archive endpoint
    return Uri.parse(
      ApiConstants.baseUrl + ApiConstants.archiveNewsEndpoint,
    ).replace(queryParameters: queryParameters);
  }

  /// Build URI with query parameters (now uses dynamic API config)
  Uri _buildUri({
    String? category,
    String? country,
    String? language,
    String? query,
    String? nextPage,
  }) {
    // Get API key from config if available, otherwise use .env key
    final apiConfig = ApiConstants.getConfig();
    final apiKey =
        apiConfig.apiKey?.isNotEmpty == true ? apiConfig.apiKey! : newsAPIKey;

    final queryParameters = <String, String>{ApiConstants.apiKeyParam: apiKey};

    // If nextPage is provided, use it directly
    if (nextPage != null && nextPage.isNotEmpty) {
      queryParameters[ApiConstants.pageParam] = nextPage;
    }

    // Add optional parameters (all now dynamic from Remote Config)
    if (category != null && category.isNotEmpty) {
      queryParameters[ApiConstants.categoryParam] = category;
    }
    if (country != null && country.isNotEmpty) {
      queryParameters[ApiConstants.countryParam] = country;
    }
    if (language != null && language.isNotEmpty) {
      queryParameters[ApiConstants.languageParam] = language;
      debugPrint('🌐 API call with language parameter: ${ApiConstants.languageParam}=$language');
    } else {
      debugPrint('⚠️ API call without language parameter - using default');
    }
    if (query != null && query.isNotEmpty) {
      queryParameters[ApiConstants.queryParam] = query;
    }

    // Build URL using dynamic base URL and endpoint
    return Uri.parse(
      ApiConstants.baseUrl + ApiConstants.breakingNewsEndPoint,
    ).replace(queryParameters: queryParameters);
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
