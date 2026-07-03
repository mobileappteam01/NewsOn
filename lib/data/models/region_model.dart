/// Region item from countries / states / districts APIs.
class RegionModel {
  const RegionModel({
    required this.name,
    this.country,
    this.state,
  });

  final String name;
  final String? country;
  final String? state;

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    return RegionModel(
      name: (json['name'] ?? '').toString().trim(),
      country: json['country']?.toString().trim(),
      state: json['state']?.toString().trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegionModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          country == other.country &&
          state == other.state;

  @override
  int get hashCode => Object.hash(name, country, state);
}

/// Saved/applied region filter for news API query params.
class SavedRegion {
  const SavedRegion({
    this.country,
    this.state,
    this.district,
  });

  final String? country;
  final String? state;
  final String? district;

  bool get isEmpty =>
      (country == null || country!.isEmpty) &&
      (state == null || state!.isEmpty) &&
      (district == null || district!.isEmpty);

  bool get hasCountry => country != null && country!.isNotEmpty;

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (country != null && country!.trim().isNotEmpty) {
      params['country'] = country!.trim();
    }
    if (state != null && state!.trim().isNotEmpty) {
      params['state'] = state!.trim();
    }
    if (district != null && district!.trim().isNotEmpty) {
      params['district'] = district!.trim();
    }
    return params;
  }

  SavedRegion copyWith({
    String? country,
    String? state,
    String? district,
    bool clearCountry = false,
    bool clearState = false,
    bool clearDistrict = false,
  }) {
    return SavedRegion(
      country: clearCountry ? null : (country ?? this.country),
      state: clearState ? null : (state ?? this.state),
      district: clearDistrict ? null : (district ?? this.district),
    );
  }
}
