import '../../../data/models/category_model.dart';

/// Single source of truth for V2 News Categories selection UI.
///
/// Saved preferences may arrive as ObjectIds and/or slugs. Visual selection and
/// the "X of Y selected" count must both use catalog ObjectIds only.
abstract final class V2CategorySelectionIdentity {
  /// Maps saved preference tokens onto catalog [CategoryModel.id] values.
  ///
  /// - Exact ObjectId match → selected
  /// - Slug / name match (case-insensitive) → that category's id
  /// - Stale / unknown tokens → dropped (never inflate the count)
  static Set<String> normalizeSelectedIds({
    required Iterable<String> savedTokens,
    required List<CategoryModel> catalog,
  }) {
    if (catalog.isEmpty) return <String>{};

    final byId = <String, String>{};
    final bySlug = <String, String>{};
    for (final cat in catalog) {
      final id = cat.id.trim();
      if (id.isEmpty) continue;
      byId[id] = id;
      final slug = cat.name.trim().toLowerCase();
      if (slug.isNotEmpty) bySlug[slug] = id;
      final display = cat.categoryName.trim().toLowerCase();
      if (display.isNotEmpty) bySlug.putIfAbsent(display, () => id);
    }

    final out = <String>{};
    for (final raw in savedTokens) {
      final token = raw.trim();
      if (token.isEmpty) continue;
      final mapped = byId[token] ?? bySlug[token.toLowerCase()];
      if (mapped != null && mapped.isNotEmpty) {
        out.add(mapped);
      }
    }
    return out;
  }

  /// Visible selected count — always equals the number of checked cards.
  static int visualSelectedCount({
    required Set<String> selectedIds,
    required List<CategoryModel> catalog,
  }) {
    if (selectedIds.isEmpty || catalog.isEmpty) return 0;
    var n = 0;
    for (final cat in catalog) {
      if (selectedIds.contains(cat.id)) n++;
    }
    return n;
  }

  /// Parse preference id list from GET `/api/v2/me/categories` (or local cache).
  static List<String> parsePreferenceTokens(dynamic raw) {
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }

    dynamic data = map == null ? raw : (map['data'] ?? map);
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
        id = (m['id'] ?? m['_id'] ?? m['categoryId'] ?? m['slug'])?.toString();
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
