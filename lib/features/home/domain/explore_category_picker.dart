import '../../../data/models/category_model.dart';

/// Picks a focused discovery row from backend categories.
///
/// Does not hard-code category IDs. Matches by name heuristics only.
abstract final class ExploreCategoryPicker {
  /// Name hints (lowercase) preferred for discovery chips — not IDs.
  static const List<String> preferredNameHints = [
    'sports',
    'business',
    'cinema',
    'entertainment',
    'india',
    'local',
    'politics',
    'technology',
    'world',
    'national',
    'international',
  ];

  static List<CategoryModel> pickFocused(
    List<CategoryModel> all, {
    Set<String>? preferredIds,
    int max = 7,
  }) {
    final active = all
        .where((c) => c.isActive && !c.isDeleted && c.name.trim().isNotEmpty)
        .toList();
    if (active.isEmpty) return const [];

    final chosen = <CategoryModel>[];
    final seen = <String>{};

    void add(CategoryModel c) {
      if (chosen.length >= max) return;
      if (seen.contains(c.id)) return;
      seen.add(c.id);
      chosen.add(c);
    }

    if (preferredIds != null && preferredIds.isNotEmpty) {
      for (final c in active) {
        if (preferredIds.contains(c.id)) add(c);
      }
    }

    for (final hint in preferredNameHints) {
      for (final c in active) {
        final n = c.name.toLowerCase();
        final cn = c.categoryName.toLowerCase();
        if (n.contains(hint) || cn.contains(hint)) {
          add(c);
        }
      }
    }

    // Fill remaining slots from catalog order.
    for (final c in active) {
      add(c);
    }

    return chosen;
  }
}
