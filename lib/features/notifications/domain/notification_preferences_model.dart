/// User notification preference snapshot (Phase 7).
class NotificationPreferences {
  const NotificationPreferences({
    this.notificationsEnabled = true,
    this.breakingNewsEnabled = true,
    this.categoryNotificationsEnabled = true,
    this.publisherNotificationsEnabled = true,
  });

  final bool notificationsEnabled;
  final bool breakingNewsEnabled;
  final bool categoryNotificationsEnabled;
  final bool publisherNotificationsEnabled;

  factory NotificationPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationPreferences();
    bool read(String key, {bool fallback = true}) {
      final v = json[key];
      if (v is bool) return v;
      if (v is String) {
        final n = v.trim().toLowerCase();
        if (n == 'true') return true;
        if (n == 'false') return false;
      }
      return fallback;
    }

    return NotificationPreferences(
      notificationsEnabled: read('notificationsEnabled'),
      breakingNewsEnabled: read('breakingNewsEnabled'),
      categoryNotificationsEnabled: read('categoryNotificationsEnabled'),
      publisherNotificationsEnabled: read('publisherNotificationsEnabled'),
    );
  }

  Map<String, dynamic> toPatchBody() => {
        'notificationsEnabled': notificationsEnabled,
        'breakingNewsEnabled': breakingNewsEnabled,
        'categoryNotificationsEnabled': categoryNotificationsEnabled,
        'publisherNotificationsEnabled': publisherNotificationsEnabled,
      };

  NotificationPreferences copyWith({
    bool? notificationsEnabled,
    bool? breakingNewsEnabled,
    bool? categoryNotificationsEnabled,
    bool? publisherNotificationsEnabled,
  }) {
    return NotificationPreferences(
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      breakingNewsEnabled: breakingNewsEnabled ?? this.breakingNewsEnabled,
      categoryNotificationsEnabled:
          categoryNotificationsEnabled ?? this.categoryNotificationsEnabled,
      publisherNotificationsEnabled:
          publisherNotificationsEnabled ?? this.publisherNotificationsEnabled,
    );
  }
}
