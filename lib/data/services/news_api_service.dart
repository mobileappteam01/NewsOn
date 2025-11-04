import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/news_response.dart';

/// Service class for handling News API requests
class NewsApiService {
  final http.Client _client;
  final String _apiKey;

  NewsApiService({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

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
        throw Exception('Invalid API key. Please check your API key in api_constants.dart');
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
  Future<NewsResponse> fetchNewsByCategory(String category, {String? nextPage}) async {
    return fetchNews(
      category: category,
      language: ApiConstants.defaultLanguage,
      nextPage: nextPage,
    );
  }

  /// Search news by query
  Future<NewsResponse> searchNews(String query, {String? nextPage}) async {
    return fetchNews(
      query: query,
      language: ApiConstants.defaultLanguage,
      nextPage: nextPage,
    );
  }

  /// Fetch top/breaking news
  Future<NewsResponse> fetchBreakingNews({String? nextPage}) async {
    return fetchNews(
      category: 'top',
      language: ApiConstants.defaultLanguage,
      nextPage: nextPage,
    );
  }

  /// Build URI with query parameters
  Uri _buildUri({
    String? category,
    String? country,
    String? language,
    String? query,
    String? nextPage,
  }) {
    final queryParameters = <String, String>{
      ApiConstants.apiKeyParam: _apiKey,
    };

    // If nextPage is provided, use it directly
    if (nextPage != null && nextPage.isNotEmpty) {
      queryParameters['page'] = nextPage;
    }

    // Add optional parameters
    if (category != null && category.isNotEmpty) {
      queryParameters[ApiConstants.categoryParam] = category;
    }
    if (country != null && country.isNotEmpty) {
      queryParameters[ApiConstants.countryParam] = country;
    }
    if (language != null && language.isNotEmpty) {
      queryParameters[ApiConstants.languageParam] = language;
    }
    if (query != null && query.isNotEmpty) {
      queryParameters[ApiConstants.queryParam] = query;
    }

    return Uri.parse(ApiConstants.baseUrl + ApiConstants.latestNewsEndpoint)
        .replace(queryParameters: queryParameters);
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
