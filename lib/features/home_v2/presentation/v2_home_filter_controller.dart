import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../data/v2_home_api.dart';
import '../domain/home_filter_state.dart';
import '../domain/v2_effective_categories.dart';
import '../domain/v2_home_metadata.dart';

/// Holds the committed **temporary** V2 Home filter.
///
/// Saved Side Menu preferences are tracked for awareness / reload only.
/// They are **never** merged into the outbound Home query — the backend
/// applies them when `category` is omitted.
class V2HomeFilterController extends ChangeNotifier {
  V2HomeFilterController({
    UserService? userService,
    V2HomeMetadataApi? metadataApi,
    ApiService? apiService,
  })  : _users = userService ?? UserService(),
        _metadata = metadataApi ?? V2HomeMetadataApi(),
        _apiOrNull = apiService;

  final UserService _users;
  final V2HomeMetadataApi _metadata;
  ApiService? _apiOrNull;

  /// Lazily created so unit tests can exercise apply/clear without Firebase.
  ApiService get _api => _apiOrNull ??= ApiService();

  HomeFilterState _committed = const HomeFilterState();
  List<String> _savedCategoryTokens = const [];
  List<V2CategoryOption> _catalog = const [];
  bool _catalogLoaded = false;
  bool _preferencesReady = false;

  /// Explicit sheet Apply state only (never includes saved preferences).
  HomeFilterState get committed => _committed;

  /// Filter sent to `GET /api/v2/home` — explicit categories only.
  HomeFilterState get requestFilter =>
      V2EffectiveHomeFilter.forRequest(_committed);

  /// @Deprecated — use [requestFilter].
  HomeFilterState get effectiveFilter => requestFilter;

  List<String> get savedCategoryTokens => _savedCategoryTokens;

  List<V2CategoryOption> get catalog => _catalog;

  /// True after bootstrap finished syncing local/server preference awareness.
  bool get preferencesReady => _preferencesReady;

  bool get isActive => _committed.isActive;

  bool get hasExplicitCategories =>
      V2EffectiveHomeFilter.hasExplicitCategories(_committed);

  bool get hasSavedPreferences =>
      V2EffectiveHomeFilter.hasSavedPreferences(_savedCategoryTokens);

  /// True when the feed may be constrained by prefs or an explicit filter
  /// (for empty-state copy only — not for the request).
  bool get hasEffectiveCategories =>
      hasExplicitCategories || hasSavedPreferences;

  /// Apply commits temporary [draft]. Dismiss without calling this leaves feed.
  void apply(HomeFilterState draft) {
    _committed = draft;
    notifyListeners();
  }

  /// Clears the temporary Home filter. Saved preferences remain server-side
  /// and apply again because `category` is omitted on the next request.
  void clearAndApply() {
    _committed = const HomeFilterState();
    notifyListeners();
  }

  /// Refreshes category catalog + local preference tokens, and pulls the
  /// latest `/api/v2/me/categories` into [UserService] when logged in.
  Future<void> syncSavedPreferences({bool forceCatalog = false}) async {
    if (!_catalogLoaded || forceCatalog) {
      try {
        _catalog = await _metadata.fetchCategories();
        _catalogLoaded = true;
      } catch (e) {
        debugPrint('ℹ️ V2HomeFilter: category catalog load failed: $e');
      }
    }

    await _refreshServerCategoryPreferences();

    final raw = V2CategoryPreferenceResolver.rawTokensFromUserData(
      _users.getUserData(),
    );
    _savedCategoryTokens =
        V2CategoryPreferenceResolver.tokensForHomeQuery(raw, _catalog);
    _preferencesReady = true;
    notifyListeners();
  }

  Future<void> _refreshServerCategoryPreferences() async {
    final token = _users.getToken();
    if (token == null || token.isEmpty || !_users.isLoggedIn) return;
    try {
      final response = await _api.getByPath(
        '/api/v2/me/categories',
        bearerToken: token,
        useV2Host: true,
      );
      if (!response.success || response.data == null) return;
      final ids = _parseCategoryIds(response.data);
      if (ids == null) return;
      final existing = _users.getUserData();
      if (existing == null) return;
      final merged = Map<String, dynamic>.from(existing);
      merged['category'] = ids;
      await _users.saveUserData(token: token, userData: merged);
    } catch (e) {
      debugPrint('ℹ️ V2HomeFilter: me/categories refresh failed: $e');
    }
  }

  /// Returns null when the payload could not be parsed (leave local alone).
  static List<String>? _parseCategoryIds(dynamic raw) {
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }
    if (map == null) return null;

    dynamic data = map['data'] ?? map;
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      data = nested['categories'] ??
          nested['categoryIds'] ??
          nested['category'] ??
          nested['items'];
    }
    if (data is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final item in data) {
      String? id;
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        id = (m['id'] ?? m['_id'] ?? m['categoryId'])?.toString();
      } else if (item != null) {
        id = item.toString();
      }
      final token = id?.trim() ?? '';
      if (token.isEmpty || seen.contains(token)) continue;
      seen.add(token);
      out.add(token);
    }
    return out;
  }
}
