import 'package:flutter/foundation.dart';

import '../data/models/region_model.dart';
import '../data/services/region_api_service.dart';
import '../data/services/region_preference_service.dart';

/// Region selection state for the home feed filter.
class RegionProvider with ChangeNotifier {
  RegionProvider({
    RegionApiService? apiService,
    RegionPreferenceService? preferenceService,
  })  : _apiService = apiService ?? RegionApiService(),
        _preferenceService = preferenceService ?? RegionPreferenceService();

  final RegionApiService _apiService;
  final RegionPreferenceService _preferenceService;

  bool _initialized = false;
  SavedRegion _applied = const SavedRegion();
  SavedRegion _draft = const SavedRegion();

  List<RegionModel> _countries = [];
  List<RegionModel> _states = [];
  List<RegionModel> _districts = [];

  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingDistricts = false;
  bool _isApplying = false;
  String? _error;

  bool get isInitialized => _initialized;
  SavedRegion get appliedRegion => _applied;
  SavedRegion get draftRegion => _draft;
  bool get hasAppliedRegion => !_applied.isEmpty;

  List<RegionModel> get countries => _countries;
  List<RegionModel> get states => _states;
  List<RegionModel> get districts => _districts;

  bool get isLoadingCountries => _isLoadingCountries;
  bool get isLoadingStates => _isLoadingStates;
  bool get isLoadingDistricts => _isLoadingDistricts;
  bool get isApplying => _isApplying;
  String? get error => _error;

  bool get showDistrictDropdown =>
      _draft.country != null &&
      _draft.country!.isNotEmpty &&
      _draft.state != null &&
      _draft.state!.isNotEmpty &&
      (_isLoadingDistricts || _districts.isNotEmpty);

  Future<void> initialize() async {
    if (_initialized) return;

    _applied = await _preferenceService.getSavedRegion();
    _draft = _applied;

    await loadCountries();

    if (_draft.hasCountry) {
      await loadStates(_draft.country!, restoreSelection: true);
    }
    if (_draft.state != null && _draft.state!.isNotEmpty) {
      await loadDistricts(
        country: _draft.country!,
        state: _draft.state!,
        restoreSelection: true,
      );
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> loadCountries() async {
    _isLoadingCountries = true;
    _error = null;
    notifyListeners();

    final response = await _apiService.fetchCountries();
    _countries = response.regions;
    if (!response.success) {
      _error = response.error;
    }

    _isLoadingCountries = false;
    notifyListeners();
  }

  Future<void> onCountryChanged(String? country) async {
    _draft = SavedRegion(
      country: country,
      state: null,
      district: null,
    );
    _states = [];
    _districts = [];
    _error = null;
    notifyListeners();

    if (country != null && country.isNotEmpty) {
      await loadStates(country);
    }
  }

  Future<void> loadStates(String country, {bool restoreSelection = false}) async {
    _isLoadingStates = true;
    _error = null;
    notifyListeners();

    final response = await _apiService.fetchStates(country);
    _states = response.regions;
    if (!response.success) {
      _error = response.error;
    } else if (!restoreSelection) {
      _draft = _draft.copyWith(clearState: true, clearDistrict: true);
      _districts = [];
    }

    _isLoadingStates = false;
    notifyListeners();
  }

  Future<void> onStateChanged(String? state) async {
    _draft = _draft.copyWith(
      state: state,
      clearState: state == null,
      clearDistrict: true,
    );
    _districts = [];
    _error = null;
    notifyListeners();

    final country = _draft.country;
    if (country != null &&
        country.isNotEmpty &&
        state != null &&
        state.isNotEmpty) {
      await loadDistricts(country: country, state: state);
    }
  }

  Future<void> loadDistricts({
    required String country,
    required String state,
    bool restoreSelection = false,
  }) async {
    _isLoadingDistricts = true;
    _error = null;
    notifyListeners();

    final response = await _apiService.fetchDistricts(
      country: country,
      state: state,
    );
    _districts = response.regions;
    if (!response.success) {
      _error = response.error;
    } else if (!restoreSelection) {
      _draft = _draft.copyWith(clearDistrict: true);
    }

    _isLoadingDistricts = false;
    notifyListeners();
  }

  void onDistrictChanged(String? district) {
    _draft = _draft.copyWith(
      district: district,
      clearDistrict: district == null,
    );
    notifyListeners();
  }

  /// Persists draft selection as the active region filter.
  Future<SavedRegion> applySelection() async {
    if (_draft.country == null || _draft.country!.isEmpty) {
      _error = 'Please select a country';
      notifyListeners();
      return _applied;
    }

    _isApplying = true;
    _error = null;
    notifyListeners();

    try {
      await _preferenceService.saveRegion(_draft);
      _applied = _draft;
      debugPrint(
        '🌍 Region applied: country=${_applied.country}, '
        'state=${_applied.state}, district=${_applied.district}',
      );
    } finally {
      _isApplying = false;
      notifyListeners();
    }

    return _applied;
  }

  /// Clears saved region and draft; caller should refresh the feed.
  Future<void> resetRegion() async {
    await _preferenceService.clearRegion();
    _applied = const SavedRegion();
    _draft = const SavedRegion();
    _states = [];
    _districts = [];
    _error = null;
    notifyListeners();
    await loadCountries();
  }

  void syncDraftFromApplied() {
    _draft = _applied;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
