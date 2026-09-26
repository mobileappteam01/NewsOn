import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/user_service.dart';
import '../../home_v2/data/v2_home_api.dart';
import '../../home_v2/domain/v2_home_metadata.dart';
import '../domain/v2_account_profile.dart';

class V2AccountApi {
  V2AccountApi({
    ApiService? apiService,
    UserService? userService,
    V2HomeMetadataApi? metadataApi,
  })  : _apiOrNull = apiService,
        _usersOrNull = userService,
        _metadataOrNull = metadataApi;

  ApiService? _apiOrNull;
  UserService? _usersOrNull;
  V2HomeMetadataApi? _metadataOrNull;

  ApiService get _api => _apiOrNull ??= ApiService();
  UserService get _users => _usersOrNull ??= UserService();
  V2HomeMetadataApi get _metadata =>
      _metadataOrNull ??= V2HomeMetadataApi();

  static const path = '/api/v2/account/profile';

  String? get _token {
    final t = _users.getToken();
    if (t != null && t.isNotEmpty && _users.isLoggedIn) return t;
    return null;
  }

  Future<V2AccountProfile> fetchProfile() async {
    final token = _token;
    if (token == null) {
      throw V2AccountException('Please sign in to view account settings');
    }
    final response = await _api.getByPath(
      path,
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success || response.data == null) {
      throw V2AccountException(response.error ?? 'Failed to load profile');
    }
    final profile = V2AccountProfile.parseResponse(response.data);
    if (profile == null) {
      throw V2AccountException('Invalid profile response');
    }
    await _users.saveUserData(
      token: token,
      userData: profile.toLocalUserData(_users.getUserData()),
    );
    return profile;
  }

  Future<V2AccountProfile> patchProfile(Map<String, dynamic> body) async {
    final token = _token;
    if (token == null) {
      throw V2AccountException('Please sign in to save account settings');
    }
    final response = await _api.patchByPath(
      path,
      body: body,
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success || response.data == null) {
      throw V2AccountException(response.error ?? 'Failed to save profile');
    }
    final profile = V2AccountProfile.parseResponse(response.data);
    if (profile == null) {
      throw V2AccountException('Invalid profile response');
    }
    await _users.saveUserData(
      token: token,
      userData: profile.toLocalUserData(_users.getUserData()),
    );
    return profile;
  }

  Future<List<V2RegionOption>> fetchCountries() => _metadata.fetchCountries();

  /// Clears the local authenticated session (token + userData).
  /// Does not call a V1 logout HTTP API.
  Future<void> clearSession() async {
    await _users.clearUserData();
  }
}

class V2AccountException implements Exception {
  V2AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

class V2AccountController extends ChangeNotifier {
  V2AccountController({V2AccountApi? api}) : _api = api ?? V2AccountApi();

  final V2AccountApi _api;

  V2AccountState _state = const V2AccountState();
  V2AccountState get state => _state;

  List<V2RegionOption> _countries = const [];
  List<V2RegionOption> get countries => _countries;

  bool _countriesLoading = false;
  bool get countriesLoading => _countriesLoading;
  String? _countriesError;
  String? get countriesError => _countriesError;

  bool _dirty = false;
  bool get isDirty => _dirty;

  void markDirty() {
    if (_dirty) return;
    _dirty = true;
    if (_state.phase == V2AccountPhase.loaded ||
        _state.phase == V2AccountPhase.saved) {
      _state = _state.copyWith(phase: V2AccountPhase.editing);
      notifyListeners();
    }
  }

  Future<void> load() async {
    _state = const V2AccountState(phase: V2AccountPhase.loading);
    _dirty = false;
    notifyListeners();
    try {
      final profile = await _api.fetchProfile();
      _state = V2AccountState(
        phase: V2AccountPhase.loaded,
        profile: profile,
      );
    } catch (e) {
      debugPrint('⚠️ V2Account load failed: $e');
      _state = V2AccountState(
        phase: V2AccountPhase.apiError,
        error: e.toString(),
      );
    }
    notifyListeners();
    unawaited(loadCountries());
  }

  Future<void> loadCountries() async {
    _countriesLoading = true;
    _countriesError = null;
    notifyListeners();
    try {
      final items = await _api.fetchCountries();
      final sorted = List<V2RegionOption>.from(items)
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      _countries = sorted;
      _countriesLoading = false;
    } catch (e) {
      _countriesLoading = false;
      _countriesError = 'Could not load countries';
      debugPrint('⚠️ V2Account countries failed: $e');
    }
    notifyListeners();
  }

  /// Client-side validation. Returns field errors; empty map means ok.
  Map<String, String> validate({
    required String username,
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String? dateOfBirthYmd,
    required String? country,
    String? city,
  }) {
    final errors = <String, String>{};
    if (username.trim().isEmpty) {
      errors['username'] = 'Username is required';
    }
    if (firstName.trim().isEmpty) {
      errors['firstName'] = 'First name is required';
    }
    final mobile = mobileNumber.trim();
    if (mobile.isNotEmpty &&
        !RegExp(r'^\+?[0-9][0-9\s\-()]{6,20}$').hasMatch(mobile)) {
      errors['mobileNumber'] = 'Enter a valid mobile number';
    }
    if (dateOfBirthYmd != null &&
        dateOfBirthYmd.isNotEmpty &&
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateOfBirthYmd)) {
      errors['dateOfBirth'] = 'Use a valid date';
    }
    if (country != null &&
        country.isNotEmpty &&
        _countries.isNotEmpty &&
        !_countries.any((c) => c.slug == country || c.name == country)) {
      errors['country'] = 'Select a country from the list';
    }
    return errors;
  }

  Future<bool> save({
    required String username,
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String? dateOfBirthYmd,
    required String? country,
    String? city,
  }) async {
    if (_state.isSaving) return false;

    final errors = validate(
      username: username,
      firstName: firstName,
      lastName: lastName,
      mobileNumber: mobileNumber,
      dateOfBirthYmd: dateOfBirthYmd,
      country: country,
      city: city,
    );
    if (errors.isNotEmpty) {
      _state = _state.copyWith(
        phase: V2AccountPhase.validationError,
        fieldErrors: errors,
        error: 'Please fix the highlighted fields',
      );
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(
      phase: V2AccountPhase.saving,
      fieldErrors: const {},
      clearError: true,
    );
    notifyListeners();

    try {
      final current = _state.profile;
      if (current == null) {
        _state = _state.copyWith(
          phase: V2AccountPhase.apiError,
          error: 'Profile not loaded',
        );
        notifyListeners();
        return false;
      }

      final body = current.changedPatchBody(
        nextUsername: username,
        nextFirstName: firstName,
        nextLastName: lastName,
        nextMobileNumber: mobileNumber,
        nextDateOfBirthYmd: dateOfBirthYmd,
        nextCountry: country,
        nextCity: city,
      );

      if (body.isEmpty) {
        _dirty = false;
        _state = V2AccountState(
          phase: V2AccountPhase.saved,
          profile: current,
        );
        notifyListeners();
        return true;
      }

      final patched = await _api.patchProfile(body);
      // Canonical reload so reopen/logout-login match server values.
      V2AccountProfile profile;
      try {
        profile = await _api.fetchProfile();
      } catch (_) {
        profile = patched;
      }
      _dirty = false;
      _state = V2AccountState(
        phase: V2AccountPhase.saved,
        profile: profile,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('⚠️ V2Account save failed: $e');
      _state = _state.copyWith(
        phase: V2AccountPhase.apiError,
        error: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Clears account state and local session for logout.
  Future<void> logout() async {
    _dirty = false;
    _countries = const [];
    _state = const V2AccountState();
    notifyListeners();
    await _api.clearSession();
  }
}
