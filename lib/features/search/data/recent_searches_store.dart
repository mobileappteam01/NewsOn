import 'package:shared_preferences/shared_preferences.dart';

/// Bounded local recent-search history. No server keystroke logging.
class RecentSearchesStore {
  RecentSearchesStore({this.maxItems = 10});

  static const _prefsKey = 'v2_recent_searches';
  final int maxItems;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const [];
    return List<String>.from(list);
  }

  Future<List<String>> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return load();
    final current = await load();
    current.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    current.insert(0, q);
    if (current.length > maxItems) {
      current.removeRange(maxItems, current.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, current);
    return current;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
