# Dynamic API Configuration Guide

## Overview

The NewsOn app now supports **fully dynamic API configuration** using Firebase Remote Config and Firebase Realtime Database. All API endpoints, parameters, and settings can be updated without requiring an app update!

## Features

✅ **Dynamic API Endpoints** - Change base URLs and endpoints on the fly  
✅ **Dynamic Query Parameters** - Update parameter names without code changes  
✅ **Dynamic Categories** - Add/remove news categories remotely  
✅ **Dynamic API Keys** - Store API keys in Remote Config (optional)  
✅ **Real-time Updates** - Use Firebase Realtime Database for instant updates  
✅ **Fallback Support** - Default values ensure app works even if Remote Config fails  

## Architecture

### Components

1. **ApiConfigModel** (`lib/data/models/api_config_model.dart`)
   - Data model for API configuration
   - Handles JSON serialization/deserialization
   - Provides default values

2. **ApiConfigService** (`lib/data/services/api_config_service.dart`)
   - Manages API config loading from Remote Config or Realtime Database
   - Handles caching and real-time updates
   - Provides refresh methods

3. **ApiConstants** (`lib/core/constants/api_constants.dart`)
   - Public interface for accessing API configuration
   - Provides getters for all API settings
   - Maintains backward compatibility

## Setup Instructions

### 1. Firebase Remote Config Setup

#### Option A: Using Firebase Console

1. Go to Firebase Console → Remote Config
2. Add a new parameter: `api_config_json`
3. Set the value to a JSON string containing your API configuration:

```json
{
  "base_url": "https://newsdata.io/api/1",
  "breaking_news_endpoint": "/latest",
  "latest_news_endpoint": "/news",
  "archive_news_endpoint": "/archive",
  "search_endpoint": "/news",
  "api_key_param": "apikey",
  "category_param": "category",
  "country_param": "country",
  "language_param": "language",
  "query_param": "q",
  "page_param": "page",
  "size_param": "size",
  "default_language": "en",
  "default_country": "us",
  "default_page_size": 10,
  "request_timeout_seconds": 30,
  "categories_json": "[\"top\",\"business\",\"entertainment\",\"environment\",\"food\",\"health\",\"politics\",\"science\",\"sports\",\"technology\",\"tourism\",\"world\"]"
}
```

4. Publish the configuration

#### Option B: Using Template File

The `firebase_remote_config_template.json` file already includes the API config. You can deploy it using:

```bash
firebase deploy --only remoteconfig
```

### 2. Firebase Realtime Database Setup (Optional - for Real-time Updates)

If you want real-time API config updates:

1. Go to Firebase Console → Realtime Database
2. Create a node: `api_config`
3. Add the same JSON structure as above
4. The app will automatically listen for changes

### 3. App Initialization

The app automatically initializes API config in `main.dart`:

```dart
// Initialize Remote Config FIRST (required for API config)
final remoteConfigProvider = RemoteConfigProvider();
await remoteConfigProvider.initialize();

// Initialize Dynamic API Configuration from Remote Config
await ApiConstants.initialize();
```

For real-time updates, uncomment this line in `main.dart`:

```dart
// await ApiConstants.initializeFromRealtimeDatabase();
```

## Usage

### Accessing API Configuration

All API constants are now accessed through getters:

```dart
// Base URL
String baseUrl = ApiConstants.baseUrl;

// Endpoints
String breakingNewsEndpoint = ApiConstants.breakingNewsEndPoint;
String latestNewsEndpoint = ApiConstants.latestNewsEndpoint;

// Query Parameters
String apiKeyParam = ApiConstants.apiKeyParam;
String categoryParam = ApiConstants.categoryParam;

// Default Values
String defaultLanguage = ApiConstants.defaultLanguage;
int defaultPageSize = ApiConstants.defaultPageSize;

// Categories
List<String> categories = ApiConstants.categories;

// Request Timeout
Duration timeout = ApiConstants.requestTimeout;
```

### Refreshing API Configuration

To manually refresh API config from Remote Config:

```dart
// Normal refresh (respects minimum fetch interval)
await ApiConstants.refresh();

// Force refresh (bypasses minimum fetch interval)
await ApiConstants.forceRefresh();
```

### Getting Full Config Model

```dart
ApiConfigModel config = ApiConstants.getConfig();
String baseUrl = config.baseUrl;
List<String> categories = config.categories;
```

## Configuration Structure

### API Config JSON Structure

```json
{
  "base_url": "https://newsdata.io/api/1",
  "breaking_news_endpoint": "/latest",
  "latest_news_endpoint": "/news",
  "archive_news_endpoint": "/archive",
  "search_endpoint": "/news",
  "api_key_param": "apikey",
  "category_param": "category",
  "country_param": "country",
  "language_param": "language",
  "query_param": "q",
  "page_param": "page",
  "size_param": "size",
  "default_language": "en",
  "default_country": "us",
  "default_page_size": 10,
  "request_timeout_seconds": 30,
  "categories_json": "[\"top\",\"business\",\"entertainment\"]",
  "api_key": "optional_api_key_here"
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `base_url` | String | Base URL for all API requests |
| `breaking_news_endpoint` | String | Endpoint for breaking/top news |
| `latest_news_endpoint` | String | Endpoint for latest news |
| `archive_news_endpoint` | String | Endpoint for archived news |
| `search_endpoint` | String | Endpoint for search |
| `api_key_param` | String | Query parameter name for API key |
| `category_param` | String | Query parameter name for category |
| `country_param` | String | Query parameter name for country |
| `language_param` | String | Query parameter name for language |
| `query_param` | String | Query parameter name for search query |
| `page_param` | String | Query parameter name for pagination |
| `size_param` | String | Query parameter name for page size |
| `default_language` | String | Default language code |
| `default_country` | String | Default country code |
| `default_page_size` | Number | Default number of results per page |
| `request_timeout_seconds` | Number | Request timeout in seconds |
| `categories_json` | String | JSON array of category names |
| `api_key` | String (optional) | API key (if stored in Remote Config) |

## Examples

### Changing API Base URL

Update in Firebase Remote Config:

```json
{
  "base_url": "https://new-api.example.com/v2"
}
```

The app will use the new URL on next refresh!

### Adding New Categories

Update `categories_json` in Remote Config:

```json
{
  "categories_json": "[\"top\",\"business\",\"entertainment\",\"technology\",\"sports\",\"new_category\"]"
}
```

### Changing Endpoint Paths

```json
{
  "breaking_news_endpoint": "/v2/breaking",
  "latest_news_endpoint": "/v2/latest"
}
```

### Using Different API Provider

You can completely switch API providers:

```json
{
  "base_url": "https://api.newsapi.org/v2",
  "breaking_news_endpoint": "/top-headlines",
  "api_key_param": "apiKey",
  "category_param": "category",
  "country_param": "country"
}
```

## Best Practices

1. **Always provide default values** - The app includes sensible defaults
2. **Test changes in staging** - Use Remote Config conditions for testing
3. **Monitor API responses** - Watch for errors after config changes
4. **Use Realtime Database for critical updates** - Instant updates without waiting for fetch interval
5. **Version your config** - Keep track of config changes in Firebase

## Troubleshooting

### API Config Not Loading

- Check Firebase Remote Config is initialized
- Verify `api_config_json` parameter exists in Remote Config
- Check network connectivity
- Review app logs for error messages

### Default Values Being Used

- Remote Config might not be published
- Minimum fetch interval might not have passed
- Use `forceRefresh()` for immediate update

### Real-time Updates Not Working

- Ensure Realtime Database is enabled
- Check Firebase Database rules allow read access
- Verify `initializeFromRealtimeDatabase()` is called

## Migration Notes

The existing code continues to work! All `ApiConstants` static properties are now getters that read from dynamic config. No code changes needed in existing services.

## Security Considerations

- **API Keys**: Consider storing sensitive API keys in Remote Config instead of code
- **Database Rules**: Restrict write access to Realtime Database `api_config` node
- **Validation**: Always validate API responses after config changes

## Support

For issues or questions:
1. Check Firebase Console for Remote Config status
2. Review app logs for initialization errors
3. Verify JSON structure matches expected format

---

**Last Updated**: 2024  
**Version**: 1.0.0

