# API Service Usage Guide

## Overview
The `ApiService` is a reusable service for making HTTP requests to your backend API. It automatically:
- Fetches base URL from Firebase Realtime Database (`ipAddress`)
- Fetches endpoints from Firestore (`apiEndPoints` collection)
- Handles all HTTP methods (GET, POST, PUT, DELETE)
- Provides proper error handling and response parsing

## Setup

### 1. Firebase Realtime Database
Store your base URL in Realtime Database:
```
ipAddress: "https://your-api-domain.com"
```

### 2. Firestore Collection
Store your endpoints in Firestore under `apiEndPoints` collection:

**Collection:** `apiEndPoints`
**Document:** `auth`
**Fields:**
- `signUp`: "api/user/createUserMobile"
- `signIn`: "api/user/login" (example)

**Document:** `chooseCategory` (example)
**Fields:**
- `getCategories`: "api/categories"
- `selectCategory`: "api/user/selectCategory"

## Usage Examples

### Example 1: POST Request (Sign Up)
```dart
import 'package:newson/data/services/api_service.dart';

final apiService = ApiService();

// Make POST request
final response = await apiService.post(
  'auth',        // Module name (Firestore document)
  'signUp',      // Endpoint key (field name in document)
  body: {
    'email': 'user@example.com',
    'password': 'password123',
  },
);

if (response.success) {
  print('Success: ${response.data}');
} else {
  print('Error: ${response.error}');
}
```

### Example 2: GET Request
```dart
final apiService = ApiService();

final response = await apiService.get(
  'chooseCategory',
  'getCategories',
  queryParameters: {
    'userId': '123',
    'type': 'news',
  },
);

if (response.success) {
  final categories = response.data;
  // Process categories
}
```

### Example 3: PUT Request
```dart
final apiService = ApiService();

final response = await apiService.put(
  'user',
  'updateProfile',
  body: {
    'name': 'John Doe',
    'email': 'john@example.com',
  },
);
```

### Example 4: DELETE Request
```dart
final apiService = ApiService();

final response = await apiService.delete(
  'user',
  'deleteAccount',
);
```

## Creating Module-Specific Services

For better organization, create service classes for each module:

```dart
// lib/data/services/user_api_service.dart
import 'package:newson/data/services/api_service.dart';

class UserApiService {
  final ApiService _apiService = ApiService();

  Future<ApiResponse> updateProfile(Map<String, dynamic> profileData) {
    return _apiService.put(
      'user',
      'updateProfile',
      body: profileData,
    );
  }

  Future<ApiResponse> getUserProfile(String userId) {
    return _apiService.get(
      'user',
      'getProfile',
      queryParameters: {'userId': userId},
    );
  }
}
```

## Response Structure

All API calls return an `ApiResponse` object:

```dart
class ApiResponse {
  final bool success;      // true if status code 200-299
  final dynamic data;       // Parsed JSON response or raw string
  final String? error;      // Error message if failed
  final int statusCode;     // HTTP status code
}
```

## Error Handling

The service automatically handles:
- Network timeouts (30 seconds)
- JSON parsing errors
- HTTP error status codes
- Firebase connection errors

Always check `response.success` before using `response.data`.

## Caching

The service caches:
- Base URL (until app restart or manual clear)
- Endpoints (until app restart or manual clear)

To clear cache:
```dart
apiService.clearAllCaches();
// or
apiService.clearBaseUrlCache();
apiService.clearEndpointsCache();
```

## Custom Headers

You can add custom headers to any request:

```dart
final response = await apiService.post(
  'auth',
  'signUp',
  body: requestBody,
  headers: {
    'Authorization': 'Bearer $token',
    'X-Custom-Header': 'value',
  },
);
```

Default headers (always included):
- `Content-Type: application/json`
- `Accept: application/json`

