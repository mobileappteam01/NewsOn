import 'package:flutter/foundation.dart';

import 'home_filter_state.dart';
import 'v2_home_metadata.dart';

/// Canonical V2 Home category / request semantics.
///
/// Side Menu categories = primary preference (applied by **backend** when
/// `category` is omitted and the user is authenticated).
///
/// Home Filter categories = temporary override only (sent as `category=`).
///
/// Priority:
/// 1. Explicit active Home filter categories → send them
/// 2. Otherwise omit `category` → backend uses saved preferences
/// 3. No prefs on server → default Home feed
abstract final class V2EffectiveHomeFilter {
  /// Builds the filter actually sent to `GET /api/v2/home`.
  ///
  /// Never injects saved preferences into the query. Never emits an empty
  /// `category` parameter.
  static HomeFilterState forRequest(HomeFilterState explicit) {
    // Location (and any other non-category fields) always come from the
    // temporary Home filter. Categories only when explicitly applied.
    if (explicit.hasCategories) return explicit;
    if (!explicit.hasLocation) return explicit;
    return HomeFilterState(
      country: explicit.country,
      state: explicit.state,
      district: explicit.district,
    );
  }

  /// Whether the temporary Home category filter is active.
  static bool hasExplicitCategories(HomeFilterState explicit) =>
      explicit.hasCategories;

  /// UI helper: saved Side Menu prefs exist locally (backend still owns apply).
  static bool hasSavedPreferences(List<String> savedTokens) =>
      uniqueTokens(savedTokens).isNotEmpty;

  static List<String> uniqueTokens(Iterable<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final value in raw) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (isMongoObjectId(trimmed)) {
        if (seen.contains(trimmed)) continue;
        seen.add(trimmed);
        out.add(trimmed);
        continue;
      }
      final slug = normalizeCategorySlug(trimmed);
      if (slug.isEmpty || !isCategorySlugToken(slug) || seen.contains(slug)) {
        continue;
      }
      seen.add(slug);
      out.add(slug);
    }
    return out;
  }
}

/// @Deprecated — use [V2EffectiveHomeFilter]. Kept as a thin alias for tests.
abstract final class V2EffectiveCategories {
  static List<String> resolve({
    required List<String> explicitHomeCategories,
    required List<String> savedUserCategories,
  }) {
    final explicit = V2EffectiveHomeFilter.uniqueTokens(explicitHomeCategories);
    if (explicit.isNotEmpty) return explicit;
    // Preference resolution for *awareness* only — request builder must omit
    // category and let the backend apply prefs.
    return V2EffectiveHomeFilter.uniqueTokens(savedUserCategories);
  }

  static HomeFilterState applyToFilter(
    HomeFilterState committed, {
    required List<String> savedUserCategories,
  }) {
    // Request path: never merge prefs into the outgoing filter.
    return V2EffectiveHomeFilter.forRequest(committed);
  }

  static List<String> uniqueTokens(Iterable<String> raw) =>
      V2EffectiveHomeFilter.uniqueTokens(raw);
}

/// Maps Side Menu category preferences (ObjectIds and/or slugs).
abstract final class V2CategoryPreferenceResolver {
  /// Bumped when Side Menu saves category preferences so V2 Home can reload.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void bump() => revision.value++;

  static List<String> rawTokensFromUserData(Map<String, dynamic>? userData) {
    final raw = userData?['category'];
    if (raw is! List || raw.isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item == null) continue;
      final token = item.toString().trim();
      if (token.isEmpty || seen.contains(token)) continue;
      seen.add(token);
      out.add(token);
    }
    return out;
  }

  /// Prefer catalog slugs; fall back to raw ObjectIds/slugs.
  static List<String> tokensForHomeQuery(
    List<String> rawTokens,
    List<V2CategoryOption> catalog,
  ) {
    if (rawTokens.isEmpty) return const [];
    if (catalog.isEmpty) {
      return V2EffectiveHomeFilter.uniqueTokens(rawTokens);
    }

    final byId = <String, String>{};
    final bySlug = <String, String>{};
    for (final option in catalog) {
      final id = option.id?.trim();
      if (id != null && id.isNotEmpty) byId[id] = option.slug;
      bySlug[option.slug.toLowerCase()] = option.slug;
    }

    final out = <String>[];
    final seen = <String>{};
    for (final token in rawTokens) {
      final mapped = byId[token] ??
          bySlug[token.toLowerCase()] ??
          (isCategorySlugToken(normalizeCategorySlug(token))
              ? normalizeCategorySlug(token)
              : (isMongoObjectId(token) ? token : null));
      if (mapped == null || mapped.isEmpty || seen.contains(mapped)) continue;
      seen.add(mapped);
      out.add(mapped);
    }
    return out;
  }
}
