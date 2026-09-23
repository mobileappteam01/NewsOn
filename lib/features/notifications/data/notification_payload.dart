/// Parsed V2 FCM data payload (Phase 7 contract).
///
/// All FCM data values are strings. Unknown fields are ignored.
class NotificationPayload {
  const NotificationPayload({
    required this.type,
    this.articleId,
    this.categoryId,
    this.publisherId,
    this.route,
    this.campaignId,
    this.title,
    this.body,
  });

  final String type;
  final String? articleId;
  final String? categoryId;
  final String? publisherId;
  final String? route;
  final String? campaignId;
  final String? title;
  final String? body;

  /// Deduping key for short-lived open processing.
  String get dedupeKey {
    final parts = <String>[
      type,
      if (campaignId != null && campaignId!.isNotEmpty) campaignId!,
      if (articleId != null && articleId!.isNotEmpty) articleId!,
      if (publisherId != null && publisherId!.isNotEmpty) publisherId!,
      if (categoryId != null && categoryId!.isNotEmpty) categoryId!,
    ];
    return parts.join('|');
  }

  /// Returns null when [type] is missing/empty — caller must fall back safely.
  static NotificationPayload? tryParse(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    final type = _str(data['type']);
    if (type == null || type.isEmpty) return null;

    return NotificationPayload(
      type: type.toLowerCase().trim(),
      articleId: _str(data['articleId']),
      categoryId: _str(data['categoryId']),
      publisherId: _str(data['publisherId']),
      route: _str(data['route']),
      campaignId: _str(data['campaignId']),
      title: _str(data['title']),
      body: _str(data['body']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
