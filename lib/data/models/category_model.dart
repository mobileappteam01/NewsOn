/// Category model representing a category from the API
class CategoryModel {
  final String id;
  final String categoryName;
  final String name;
  final String? imageUrl; // Full URL (imageBaseURL + media.url)
  final String? mediaUrl; // Relative path from API
  final bool isActive;
  final bool isDeleted;

  CategoryModel({
    required this.id,
    required this.categoryName,
    required this.name,
    this.imageUrl,
    this.mediaUrl,
    required this.isActive,
    required this.isDeleted,
  });

  /// Create CategoryModel from API response JSON
  factory CategoryModel.fromJson(
    Map<String, dynamic> json,
    String? imageBaseUrl,
  ) {
    final media = json['media'] as Map<String, dynamic>?;
    final mediaUrl = media?['url'] as String?;
    
    // Build full image URL if both base URL and media URL are available
    String? fullImageUrl;
    if (imageBaseUrl != null && mediaUrl != null) {
      // Ensure base URL doesn't end with / and media URL doesn't start with /
      final base = imageBaseUrl.endsWith('/') 
          ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
          : imageBaseUrl;
      // Remove leading slash from media URL if present, then add it back
      final media = mediaUrl.startsWith('/') 
          ? mediaUrl.substring(1)
          : mediaUrl;
      fullImageUrl = '$base/$media';
    }

    return CategoryModel(
      id: json['_id'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: fullImageUrl,
      mediaUrl: mediaUrl,
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  /// Convert CategoryModel to JSON
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'categoryName': categoryName,
      'name': name,
      'media': mediaUrl != null
          ? {
              'url': mediaUrl,
            }
          : null,
      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, categoryName: $categoryName, imageUrl: $imageUrl)';
  }
}

