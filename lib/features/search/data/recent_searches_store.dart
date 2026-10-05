import 'package:shared_preferences/shared_preferences.dart';

/// Bounded local recent-search history. No server keystroke logging.
class RecentSearchesStore {
  RecentSearchesStore({this.maxItems = 10});

  static const _prefsKey = 'v2_recent_searches';
  final int maxItems;

  /// Serializes read-modify-write updates so an add racing a remove/clear
  /// cannot write back a list that still has the removed term.
  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const [];
    return List<String>.from(list);
  }

  Future<List<String>> add(String query) {
    final q = query.trim();
    if (q.isEmpty) return load();
    return _serialized(() async {
      final current = await load();
      current.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      current.insert(0, q);
      if (current.length > maxItems) {
        current.removeRange(maxItems, current.length);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, current);
      return current;
    });
  }

  /// Removes only [query] (exact term) and returns the remaining history.
  Future<List<String>> remove(String query) {
    return _serialized(() async {
      final current = await load();
      final before = current.length;
      current.removeWhere((e) => e == query);
      if (current.length == before) return current;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, current);
      return current;
    });
  }

  Future<void> clear() {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, const []);
    });
  }
}
