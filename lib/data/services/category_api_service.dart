import 'package:newson/data/models/category_model.dart';
import 'package:newson/data/services/api_service.dart';

/// Category API Service for handling category-related API calls
class CategoryApiService {
  final ApiService _apiService = ApiService();

  /// Get categories list with pagination support
  /// [page] - Page number to fetch (default: 1)
  /// [limit] - Number of items per page (default: 10, fixed)
  Future<CategoryResponse> getCategories({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Build query parameters for pagination
      final queryParameters = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final response = await _apiService.get(
        'chooseCategory', // Module name in Firestore apiEndPoints collection
        'getCategories', // Endpoint key in the chooseCategory document
        queryParameters: queryParameters,
      );

      if (response.success) {
        // Parse categories from response
        List<CategoryModel> categories = [];
        int total = 0;
        int page = 1;
        int totalPages = 1;

        // Get image base URL from ApiService
        final imageBaseUrl = _apiService.getImageBaseUrl();

        if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;

          // Extract pagination metadata
          total = data['total'] as int? ?? 0;
          page = data['page'] as int? ?? 1;
          totalPages = data['totalPages'] as int? ?? 1;

          // The response structure is: { "message": "success", "data": [...] }
          if (data.containsKey('data') && data['data'] is List) {
            final dataList = data['data'] as List;
            categories =
                dataList
                    .where((item) => item is Map<String, dynamic>)
                    .map((item) {
                      final categoryMap = item as Map<String, dynamic>;
                      // Only include active and non-deleted categories
                      final isActive = categoryMap['isActive'] as bool? ?? true;
                      final isDeleted =
                          categoryMap['isDeleted'] as bool? ?? false;

                      if (isActive && !isDeleted) {
                        return CategoryModel.fromJson(
                          categoryMap,
                          imageBaseUrl,
                        );
                      }
                      return null;
                    })
                    .whereType<CategoryModel>()
                    .toList();
          } else if (data.containsKey('categories') &&
              data['categories'] is List) {
            // Fallback: if categories is a list of strings
            final categoriesList = data['categories'] as List;
            categories =
                categoriesList
                    .where((item) => item is Map<String, dynamic>)
                    .map(
                      (item) => CategoryModel.fromJson(
                        item as Map<String, dynamic>,
                        imageBaseUrl,
                      ),
                    )
                    .toList();
          }
        } else if (response.data is List) {
          // Direct list response (fallback for non-paginated responses)
          final dataList = response.data as List;
          categories =
              dataList
                  .where((item) => item is Map<String, dynamic>)
                  .map(
                    (item) => CategoryModel.fromJson(
                      item as Map<String, dynamic>,
                      imageBaseUrl,
                    ),
                  )
                  .toList();
          total = categories.length;
          totalPages = 1;
        }

        return CategoryResponse(
          success: true,
          categories: categories,
          message: 'Categories loaded successfully',
          total: total,
          page: page,
          limit: limit,
          totalPages: totalPages,
        );
      } else {
        return CategoryResponse(
          success: false,
          categories: [],
          message: response.error ?? 'Failed to load categories',
          total: 0,
          page: 1,
          limit: limit,
          totalPages: 0,
        );
      }
    } catch (e) {
      return CategoryResponse(
        success: false,
        categories: [],
        message: 'Error loading categories: $e',
        total: 0,
        page: 1,
        limit: limit,
        totalPages: 0,
      );
    }
  }

  /// Select categories (deprecated - sign-up API handles this now)
  /// Kept for backward compatibility if needed
  Future<CategoryResponse> selectCategories(List<String> categoryIds) async {
    try {
      final response = await _apiService.post(
        'chooseCategory',
        'selectCategories', // Assuming this endpoint exists
        body: {'categories': categoryIds},
      );

      if (response.success) {
        // Return the same categories list (we don't need to parse response)
        return CategoryResponse(
          success: true,
          categories: [], // Empty list since we're just confirming selection
          message:
              response.data is Map
                  ? (response.data['message'] ??
                      'Categories selected successfully')
                  : 'Categories selected successfully',
        );
      } else {
        return CategoryResponse(
          success: false,
          categories: [],
          message: response.error ?? 'Failed to select categories',
        );
      }
    } catch (e) {
      return CategoryResponse(
        success: false,
        categories: [],
        message: 'Error selecting categories: $e',
      );
    }
  }
}

/// Category Response model with pagination support
class CategoryResponse {
  final bool success;
  final List<CategoryModel> categories;
  final String message;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  CategoryResponse({
    required this.success,
    required this.categories,
    required this.message,
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.totalPages = 0,
  });

  /// Check if there are more pages available
  bool get hasMorePages => page < totalPages;

  @override
  String toString() {
    return 'CategoryResponse(success: $success, categories: ${categories.length}, page: $page/$totalPages, message: $message)';
  }
}
