import '../../news/data/v2_feed_item_mapper.dart';

/// Category shown on a Home article card.
///
/// Articles carry several categories (e.g. `top, business`). While the feed is
/// category-filtered, the badge names the category that put the article in
/// the feed, not whichever tag happens to be stored first.
String? v2HomeBadgeCategory(
  List<String>? articleCategories,
  Set<String> activeCategoryKeys,
) {
  final categories = (articleCategories ?? const <String>[])
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  if (categories.isEmpty) return null;
  if (activeCategoryKeys.isNotEmpty) {
    for (final category in categories) {
      if (activeCategoryKeys.contains(V2HomeCategoryFilters.matchKey(category))) {
        return category;
      }
    }
  }
  return categories.first;
}
