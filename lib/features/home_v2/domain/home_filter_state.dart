/// Committed V2 Home filter. Location uses backend slugs.
/// [district] is sent as the `city` query alias.
class HomeFilterState {
  const HomeFilterState({
    this.selectedCategorySlugs = const [],
    this.country,
    this.state,
    this.district,
  });

  final List<String> selectedCategorySlugs;
  final String? country;
  final String? state;

  /// City / district slug. Query param is `city`.
  final String? district;

  bool get hasCategories => selectedCategorySlugs.isNotEmpty;

  bool get hasLocation =>
      _filled(country) || _filled(state) || _filled(district);

  bool get isActive => hasCategories || hasLocation;

  int get categoryCount => selectedCategorySlugs.length;

  HomeFilterState copyWith({
    List<String>? selectedCategorySlugs,
    String? country,
    String? state,
    String? district,
    bool clearCountry = false,
    bool clearState = false,
    bool clearDistrict = false,
  }) {
    return HomeFilterState(
      selectedCategorySlugs:
          selectedCategorySlugs ?? this.selectedCategorySlugs,
      country: clearCountry ? null : (country ?? this.country),
      state: clearState ? null : (state ?? this.state),
      district: clearDistrict ? null : (district ?? this.district),
    );
  }

  HomeFilterState toggleCategory(String slug) {
    final id = slug.trim().toLowerCase();
    if (id.isEmpty) return this;
    final next = List<String>.from(selectedCategorySlugs);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    return copyWith(selectedCategorySlugs: next);
  }

  /// Parent change drops invalid children.
  HomeFilterState selectCountry(String? slug) {
    final next = slug?.trim();
    if (next == null || next.isEmpty) {
      return copyWith(
        clearCountry: true,
        clearState: true,
        clearDistrict: true,
      );
    }
    if (next == country) return this;
    return copyWith(
      country: next,
      clearState: true,
      clearDistrict: true,
    );
  }

  HomeFilterState selectState(String? slug) {
    final next = slug?.trim();
    if (next == null || next.isEmpty) {
      return copyWith(clearState: true, clearDistrict: true);
    }
    if (next == state) return this;
    return copyWith(state: next, clearDistrict: true);
  }

  HomeFilterState selectDistrict(String? slug) {
    final next = slug?.trim();
    if (next == null || next.isEmpty) {
      return copyWith(clearDistrict: true);
    }
    return copyWith(district: next);
  }

  HomeFilterState cleared() => const HomeFilterState();

  /// Query map for `GET /api/v2/home`. Omits empty values.
  /// Categories are unique, comma-joined slugs.
  Map<String, String> toQueryParameters({
    required String language,
    required int page,
    required int limit,
  }) {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    final lang = language.trim();
    if (lang.isNotEmpty) query['language'] = lang;

    final slugs = <String>[];
    final seen = <String>{};
    for (final s in selectedCategorySlugs) {
      final token = s.trim();
      if (token.isEmpty) continue;
      final normalized = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(token)
          ? token
          : token.toLowerCase();
      if (seen.contains(normalized)) continue;
      seen.add(normalized);
      slugs.add(normalized);
    }
    if (slugs.isNotEmpty) {
      query['category'] = slugs.join(',');
    }
    if (_filled(country)) query['country'] = country!.trim();
    if (_filled(state)) query['state'] = state!.trim();
    if (_filled(district)) query['city'] = district!.trim();
    return query;
  }

  static bool _filled(String? v) => v != null && v.trim().isNotEmpty;
}
