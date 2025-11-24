/// Model for Terms and Conditions / Privacy Policy content
class ContentModel {
  final String id;
  final String? termsAndCondition;
  final String? privacyPolicy;
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ContentModel({
    required this.id,
    this.termsAndCondition,
    this.privacyPolicy,
    required this.isActive,
    required this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['_id'] as String,
      termsAndCondition: json['termsAndCondition'] as String?,
      privacyPolicy: json['privacyPolicy'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'] as String)
              : null,
    );
  }
}

/// Response model for content API
class ContentResponse {
  final bool success;
  final String message;
  final List<ContentModel> content;
  final ContentModel? activeContent;

  ContentResponse({
    required this.success,
    required this.message,
    required this.content,
    this.activeContent,
  });

  factory ContentResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List?;
    final contentList =
        data != null
            ? data
                .map(
                  (item) => ContentModel.fromJson(item as Map<String, dynamic>),
                )
                .toList()
            : <ContentModel>[];

    // Find active content (isActive: true and isDeleted: false)
    final active = contentList.firstWhere(
      (item) => item.isActive && !item.isDeleted,
      orElse:
          () =>
              contentList.isNotEmpty
                  ? contentList.first
                  : ContentModel(id: '', isActive: false, isDeleted: false),
    );

    return ContentResponse(
      success: json['message'] == 'success',
      message: json['message'] as String? ?? 'Unknown',
      content: contentList,
      activeContent: active.id.isNotEmpty ? active : null,
    );
  }
}
