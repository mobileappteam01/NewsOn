/// One inbox row from the notification-user list API.
class V2NotificationInboxItem {
  const V2NotificationInboxItem({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final String? type;
  final DateTime? createdAt;
  final bool isRead;

  factory V2NotificationInboxItem.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final message =
        (json['message'] ?? json['body'] ?? json['content'] ?? '')
            .toString()
            .trim();
    final type = json['type']?.toString().trim();
    DateTime? createdAt;
    final rawDate = json['createdAt'] ?? json['created_at'] ?? json['updatedAt'];
    if (rawDate != null) {
      createdAt = DateTime.tryParse(rawDate.toString());
    }
    final isRead = json['isRead'] == true || json['is_read'] == true;
    return V2NotificationInboxItem(
      id: id,
      title: title.isEmpty ? 'Notification' : title,
      message: message,
      type: (type != null && type.isNotEmpty) ? type : null,
      createdAt: createdAt,
      isRead: isRead,
    );
  }
}

enum V2NotificationInboxPhase { loading, empty, withData, error }

class V2NotificationInboxState {
  const V2NotificationInboxState({
    this.phase = V2NotificationInboxPhase.loading,
    this.items = const [],
    this.error,
  });

  final V2NotificationInboxPhase phase;
  final List<V2NotificationInboxItem> items;
  final String? error;

  bool get isLoading => phase == V2NotificationInboxPhase.loading;
  bool get isEmpty => phase == V2NotificationInboxPhase.empty;
  bool get isError => phase == V2NotificationInboxPhase.error;
  bool get hasData => phase == V2NotificationInboxPhase.withData;

  V2NotificationInboxState copyWith({
    V2NotificationInboxPhase? phase,
    List<V2NotificationInboxItem>? items,
    String? error,
    bool clearError = false,
  }) {
    return V2NotificationInboxState(
      phase: phase ?? this.phase,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Builds state from a successful API payload. Never treats errors as empty.
  static V2NotificationInboxState fromSuccess(List<V2NotificationInboxItem> items) {
    if (items.isEmpty) {
      return const V2NotificationInboxState(
        phase: V2NotificationInboxPhase.empty,
        items: [],
      );
    }
    return V2NotificationInboxState(
      phase: V2NotificationInboxPhase.withData,
      items: items,
    );
  }

  static V2NotificationInboxState fromError(
    String message, {
    List<V2NotificationInboxItem> preserve = const [],
  }) {
    return V2NotificationInboxState(
      phase: V2NotificationInboxPhase.error,
      items: preserve,
      error: message,
    );
  }

  static List<V2NotificationInboxItem> parseList(dynamic raw) {
    List<dynamic> list = const [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final data = map['data'];
      if (data is List) {
        list = data;
      } else if (data is Map && data['notifications'] is List) {
        list = data['notifications'] as List;
      } else if (map['notifications'] is List) {
        list = map['notifications'] as List;
      } else if (map['items'] is List) {
        list = map['items'] as List;
      }
    }

    final out = <V2NotificationInboxItem>[];
    final seen = <String>{};
    for (final item in list) {
      if (item is! Map) continue;
      final parsed =
          V2NotificationInboxItem.fromJson(Map<String, dynamic>.from(item));
      if (parsed.id.isEmpty || seen.contains(parsed.id)) continue;
      seen.add(parsed.id);
      out.add(parsed);
    }
    return out;
  }
}
