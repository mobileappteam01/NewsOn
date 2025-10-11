# API Reference - Newsdata.IO Integration

## Overview

This app uses the **Newsdata.IO** API to fetch news articles. This document provides details about the API integration.

## Base Configuration

**File**: `lib/core/constants/api_constants.dart`

```dart
static const String baseUrl = 'https://newsdata.io/api/1';
static const String apiKey = 'YOUR_API_KEY_HERE';
```

## Endpoints Used

### 1. Latest News
```
GET /news
```

**Parameters**:
- `apikey` (required): Your API key
- `category` (optional): News category
- `country` (optional): Country code
- `language` (optional): Language code
- `q` (optional): Search query
- `page` (optional): Pagination token

**Example Request**:
```
https://newsdata.io/api/1/news?apikey=YOUR_KEY&category=technology&language=en
```

## Available Categories

```dart
- top           // Breaking/Top news
- business      // Business news
- entertainment // Entertainment news
- environment   // Environmental news
- food          // Food & dining news
- health        // Health news
- politics      // Political news
- science       // Science news
- sports        // Sports news
- technology    // Technology news
- tourism       // Travel & tourism news
- world         // World news
```

## Response Format

### Success Response

```json
{
  "status": "success",
  "totalResults": 100,
  "results": [
    {
      "article_id": "unique_id",
      "title": "Article Title",
      "link": "https://...",
      "keywords": ["keyword1", "keyword2"],
      "creator": ["Author Name"],
      "video_url": null,
      "description": "Article description...",
      "content": "Full article content...",
      "pubDate": "2024-01-15 10:30:00",
      "image_url": "https://...",
      "source_id": "source_name",
      "source_priority": 1,
      "country": ["us"],
      "category": ["technology"],
      "language": "en"
    }
  ],
  "nextPage": "pagination_token"
}
```

### Error Response

```json
{
  "status": "error",
  "results": {
    "message": "Error description",
    "code": "error_code"
  }
}
```

## Rate Limits

### Free Plan
- **200 requests per day**
- **10 results per request**
- **No commercial use**

### Paid Plans
- Higher rate limits
- More results per request
- Commercial use allowed
- Priority support

## Implementation in App

### Service Layer
**File**: `lib/data/services/news_api_service.dart`

```dart
class NewsApiService {
  Future<NewsResponse> fetchNews({
    String? category,
    String? country,
    String? language,
    String? query,
    String? nextPage,
  }) async {
    // API call implementation
  }
}
```

### Repository Layer
**File**: `lib/data/repositories/news_repository.dart`

```dart
class NewsRepository {
  Future<NewsResponse> fetchNewsByCategory(String category) async {
    return await _apiService.fetchNewsByCategory(category);
  }
  
  Future<NewsResponse> searchNews(String query) async {
    return await _apiService.searchNews(query);
  }
}
```

### Provider Layer
**File**: `lib/providers/news_provider.dart`

```dart
class NewsProvider with ChangeNotifier {
  Future<void> fetchNewsByCategory(String category) async {
    final response = await _repository.fetchNewsByCategory(category);
    _articles = response.results;
    notifyListeners();
  }
}
```

## Error Handling

### Common Errors

1. **401 Unauthorized**
   - Invalid API key
   - Solution: Check `api_constants.dart`

2. **429 Too Many Requests**
   - Rate limit exceeded
   - Solution: Wait or upgrade plan

3. **500 Internal Server Error**
   - Server-side issue
   - Solution: Retry after some time

4. **Network Error**
   - No internet connection
   - Solution: Check connectivity

### Error Handling in Code

```dart
try {
  final response = await _apiService.fetchNews();
  // Handle success
} catch (e) {
  if (e.toString().contains('401')) {
    // Invalid API key
  } else if (e.toString().contains('429')) {
    // Rate limit exceeded
  } else if (e.toString().contains('SocketException')) {
    // No internet
  } else {
    // Other errors
  }
}
```

## Pagination

The API uses token-based pagination:

```dart
// First request
final response = await fetchNews(category: 'technology');

// Next page
if (response.hasNextPage) {
  final nextResponse = await fetchNews(
    category: 'technology',
    nextPage: response.nextPage,
  );
}
```

## Best Practices

1. **Cache Responses**: Store frequently accessed data locally
2. **Handle Errors Gracefully**: Show user-friendly error messages
3. **Respect Rate Limits**: Implement request throttling
4. **Use Pagination**: Load data in chunks
5. **Optimize Requests**: Only fetch what you need

## Testing

### Test API Key
Use the test endpoint to verify your API key:

```bash
curl "https://newsdata.io/api/1/news?apikey=YOUR_KEY&language=en"
```

### Test in App
1. Add your API key to `api_constants.dart`
2. Run the app
3. Check if news articles load
4. Monitor console for errors

## Additional Resources

- **Official Documentation**: https://newsdata.io/documentation
- **API Dashboard**: https://newsdata.io/dashboard
- **Support**: support@newsdata.io

## Example Usage in App

### Fetch Breaking News
```dart
final newsProvider = Provider.of<NewsProvider>(context);
await newsProvider.fetchBreakingNews();
```

### Fetch by Category
```dart
await newsProvider.fetchNewsByCategory('technology');
```

### Search News
```dart
await newsProvider.searchNews('artificial intelligence');
```

### Load More (Pagination)
```dart
await newsProvider.loadMoreNews();
```

## Data Models

### NewsArticle Model
**File**: `lib/data/models/news_article.dart`

Properties:
- `articleId`: Unique identifier
- `title`: Article title
- `description`: Short description
- `content`: Full content
- `imageUrl`: Article image
- `pubDate`: Publication date
- `category`: News categories
- `creator`: Author names
- `sourceId`: News source

### NewsResponse Model
**File**: `lib/data/models/news_response.dart`

Properties:
- `status`: Response status
- `totalResults`: Total available results
- `results`: List of articles
- `nextPage`: Pagination token

---

**Note**: Always keep your API key secure and never commit it to public repositories.
