/// Client-side search query validation (Phase 5).
///
/// Does not implement fuzzy ranking. Server performs search.
abstract final class SearchQueryValidator {
  static const int minLength = 2;
  static const int maxLength = 100;
  static const int defaultLimit = 20;
  static const int maxLimit = 50;

  static String normalize(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validate(String raw) {
    final q = normalize(raw);
    if (q.length < minLength) return 'too_short';
    if (q.length > maxLength) return 'too_long';
    return null;
  }

  static bool isValid(String raw) => validate(raw) == null;

  static int clampLimit(int limit) {
    if (limit < 1) return defaultLimit;
    if (limit > maxLimit) return maxLimit;
    return limit;
  }
}
