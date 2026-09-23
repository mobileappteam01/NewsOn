/// Short-lived open dedupe (campaignId + articleId + type, etc.).
///
/// Prevents duplicate navigation from multiple FCM lifecycle callbacks
/// without permanently suppressing future legitimate opens.
class NotificationOpenDedupe {
  NotificationOpenDedupe({
    this.ttl = const Duration(seconds: 60),
  });

  final Duration ttl;
  final Map<String, DateTime> _recent = {};

  /// Returns true when [key] was processed within [ttl].
  bool shouldSkip(String key) {
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t) > ttl);
    final last = _recent[key];
    if (last != null && now.difference(last) < ttl) {
      return true;
    }
    _recent[key] = now;
    return false;
  }

  void clear() => _recent.clear();

  int get size => _recent.length;
}
