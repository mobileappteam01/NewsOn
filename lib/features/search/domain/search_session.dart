import '../../../core/constants/news_language_constants.dart';
import '../../../data/models/language_model.dart';

/// Location filters the user chose inside Search. Empty by default; never
/// derived from the Home region.
///
/// `GET /api/v2/search` reads `country`, `state` and `district` (it has no
/// `city` alias, unlike `/api/v2/home`).
class SearchFilters {
  const SearchFilters({this.country, this.state, this.district});

  final String? country;
  final String? state;
  final String? district;

  static String? _clean(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  bool get isEmpty =>
      _clean(country) == null &&
      _clean(state) == null &&
      _clean(district) == null;

  Map<String, String> toQueryParameters() => {
        if (_clean(country) != null) 'country': _clean(country)!,
        if (_clean(state) != null) 'state': _clean(state)!,
        if (_clean(district) != null) 'district': _clean(district)!,
      };

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      _clean(other.country) == _clean(country) &&
      _clean(other.state) == _clean(state) &&
      _clean(other.district) == _clean(district);

  @override
  int get hashCode =>
      Object.hash(_clean(country), _clean(state), _clean(district));
}

/// Search language choices. A `null` code means all languages, so no
/// `language` param is sent.
abstract final class SearchLanguages {
  static List<LanguageModel> get options => NewsLanguageConstants.languages;

  /// Returns [code] when it is a supported news language, otherwise `null`.
  static String? normalize(String? code) {
    final c = code?.trim().toLowerCase();
    if (c == null || c.isEmpty) return null;
    return NewsLanguageConstants.findByCode(c)?.code;
  }
}

/// Values captured when a search is submitted; every page of that search
/// reuses them.
class SearchSession {
  const SearchSession({
    required this.query,
    this.language,
    this.filters = const SearchFilters(),
  });

  final String query;
  final String? language;
  final SearchFilters filters;
}
