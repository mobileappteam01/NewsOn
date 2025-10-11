/// API Configuration and Constants for Newsdata.IO
class ApiConstants {
  // Base URL for Newsdata.IO API
  static const String baseUrl = 'https://newsdata.io/api/1';
  
  // API Key - Replace with your actual API key from newsdata.io
  static const String apiKey = 'YOUR_API_KEY_HERE';
  
  // Endpoints
  static const String latestNewsEndpoint = '/news';
  static const String archiveNewsEndpoint = '/archive';
  
  // Query Parameters
  static const String apiKeyParam = 'apikey';
  static const String categoryParam = 'category';
  static const String countryParam = 'country';
  static const String languageParam = 'language';
  static const String queryParam = 'q';
  static const String pageParam = 'page';
  static const String sizeParam = 'size';
  
  // Default Values
  static const String defaultLanguage = 'en';
  static const String defaultCountry = 'us';
  static const int defaultPageSize = 10;
  
  // Categories available in Newsdata.IO
  static const List<String> categories = [
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
  
  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
}
