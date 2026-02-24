import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:newson/data/services/user_service.dart' show UserService;
import '../../data/services/api_service.dart';

/// Model class for city data
class City {
  final String name;
  final String? state;
  final String? country;

  City({
    required this.name,
    this.state,
    this.country,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'state': state,
      'country': country,
    };
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Model class for country data
class Country {
  final String name;
  final String? code;
  final String? dialCode;
  final String? countryId;
  final bool? isActive;
  final bool? isDeleted;

  Country({
    required this.name,
    this.code,
    this.dialCode,
    this.countryId,
    this.isActive,
    this.isDeleted,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['country_name'] as String? ?? json['name'] as String? ?? '',
      code: json['code'] as String?,
      dialCode: json['dialCode'] as String?,
      countryId: json['country_id'] as String?,
      isActive: json['isActive'] as bool?,
      isDeleted: json['isDeleted'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'dialCode': dialCode,
      'country_id': countryId,
      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          (name == other.name || countryId == other.countryId);

  @override
  int get hashCode => name.hashCode;
}

/// Service for fetching location data (cities and countries)
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  // Cache for location data
  List<City>? _cachedCities;
  List<Country>? _cachedCountries;

  /// Fetch cities from API
  Future<List<City>> getCities({String? country}) async {
    try {
      // Return cached data if available
      if (_cachedCities != null && country == null) {
        return _cachedCities!;
      }

      final userToken = _userService.getToken();
      print('🔑 User token for fetching cities: $userToken');

      if (userToken == null || userToken.isEmpty) {
        debugPrint('⚠️ User not logged in - using default cities');
        return _getDefaultCities();
      }

      // Initialize API service if needed
      if (!_apiService.isInitialized) {
        await _apiService.initialize();
      }

      // Build query parameters
      Map<String, String> queryParams = {};
      if (country != null) {
        queryParams['country'] = country;
      }

      // Make API call - try different possible endpoints
      ApiResponse response;
      try {
        // First try the most likely endpoint
        response = await _apiService.get(
          'location',
          'getCities',
          queryParameters: queryParams,
          bearerToken: userToken,
        );
      } catch (e) {
        debugPrint(
            '⚠️ Failed to call location/getCities, trying profile/getCities: $e');
        // Fallback to profile module
        response = await _apiService.get(
          'profile',
          'getCities',
          queryParameters: queryParams,
          bearerToken: userToken,
        );
      }

      if (response.success && response.data != null) {
        final List<dynamic> citiesData = response.data['cities'] ?? [];
        final cities =
            citiesData.map((cityJson) => City.fromJson(cityJson)).toList();

        // Cache if no country filter
        if (country == null) {
          _cachedCities = cities;
        }

        debugPrint('✅ Loaded ${cities.length} cities from API');
        return cities;
      } else {
        debugPrint('⚠️ Failed to load cities: ${response.error}');
        debugPrint('⚠️ Status code: ${response.statusCode}');
        debugPrint('⚠️ Using default cities as fallback');
        return _getDefaultCities();
      }
    } catch (e) {
      debugPrint('❌ Error loading cities: $e');
      debugPrint('❌ Using default cities as fallback');
      return _getDefaultCities();
    }
  }

  /// Fetch countries from API
  Future<List<Country>> getCountries() async {
    try {
      // Return cached data if available
      if (_cachedCountries != null) {
        return _cachedCountries!;
      }

      final userToken = _userService.getToken();
      print('🔑 User token for fetching countries: $userToken');

      if (userToken == null || userToken.isEmpty) {
        debugPrint('⚠️ User not logged in - using default countries');
        return _getDefaultCountries();
      }

      // Initialize API service if needed
      if (!_apiService.isInitialized) {
        await _apiService.initialize();
      }

      // Make API call - try different possible endpoints
      ApiResponse response;
      try {
        // First try the most likely endpoint
        response = await _apiService.get(
          'profile',
          'getCountries',
          bearerToken: userToken,
        );
      } catch (e) {
        debugPrint(
            '⚠️ Failed to call location/getCountries, trying profile/getCountries: $e');
        // Fallback to profile module
        response = await _apiService.get(
          'profile',
          'getCountries',
          bearerToken: userToken,
        );
      }

      if (response.success && response.data != null) {
        // Handle the new API response structure
        final List<dynamic> countriesData;

        if (response.data['data'] != null) {
          // New API structure: {"message":"success","data":[...]}
          countriesData = response.data['data'] as List<dynamic>;
        } else if (response.data['countries'] != null) {
          // Old API structure: {"countries":[...]}
          countriesData = response.data['countries'] as List<dynamic>;
        } else {
          debugPrint('⚠️ No countries data found in response');
          return _getDefaultCountries();
        }

        // Filter only active countries and parse
        final countries = countriesData
            .where((countryJson) =>
                countryJson['isActive'] == true &&
                (countryJson['isDeleted'] != true))
            .map((countryJson) => Country.fromJson(countryJson))
            .toList();

        _cachedCountries = countries;
        debugPrint('✅ Loaded ${countries.length} active countries from API');
        return countries;
      } else {
        debugPrint('⚠️ Failed to load countries: ${response.error}');
        debugPrint('⚠️ Status code: ${response.statusCode}');
        debugPrint('⚠️ Using default countries as fallback');
        return _getDefaultCountries();
      }
    } catch (e) {
      debugPrint('❌ Error loading countries: $e');
      debugPrint('❌ Using default countries as fallback');
      return _getDefaultCountries();
    }
  }

  /// Get default cities as fallback
  List<City> _getDefaultCities() {
    return [
      City(name: 'Chennai', state: 'Tamil Nadu', country: 'India'),
      City(name: 'Coimbatore', state: 'Tamil Nadu', country: 'India'),
      City(name: 'Madurai', state: 'Tamil Nadu', country: 'India'),
      City(name: 'Salem', state: 'Tamil Nadu', country: 'India'),
      City(name: 'Bangalore', state: 'Karnataka', country: 'India'),
      City(name: 'Mumbai', state: 'Maharashtra', country: 'India'),
      City(name: 'Delhi', state: 'Delhi', country: 'India'),
      City(name: 'Kolkata', state: 'West Bengal', country: 'India'),
      City(name: 'Hyderabad', state: 'Telangana', country: 'India'),
      City(name: 'Pune', state: 'Maharashtra', country: 'India'),
    ];
  }

  /// Get default countries as fallback
  List<Country> _getDefaultCountries() {
    return [
      Country(name: 'India', code: 'IN', dialCode: '+91'),
      Country(name: 'United States', code: 'US', dialCode: '+1'),
      Country(name: 'United Kingdom', code: 'GB', dialCode: '+44'),
      Country(name: 'Canada', code: 'CA', dialCode: '+1'),
      Country(name: 'Australia', code: 'AU', dialCode: '+61'),
      Country(name: 'Germany', code: 'DE', dialCode: '+49'),
      Country(name: 'France', code: 'FR', dialCode: '+33'),
      Country(name: 'Japan', code: 'JP', dialCode: '+81'),
      Country(name: 'China', code: 'CN', dialCode: '+86'),
      Country(name: 'Singapore', code: 'SG', dialCode: '+65'),
    ];
  }

  /// Clear cached data (useful for refresh)
  void clearCache() {
    _cachedCities = null;
    _cachedCountries = null;
    debugPrint('🗑️ Location cache cleared');
  }

  /// Search cities by name
  List<City> searchCities(String query, List<City> cities) {
    if (query.isEmpty) return cities;

    final lowerQuery = query.toLowerCase();
    return cities
        .where((city) =>
            city.name.toLowerCase().contains(lowerQuery) ||
            (city.state?.toLowerCase().contains(lowerQuery) ?? false) ||
            (city.country?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  /// Search countries by name
  List<Country> searchCountries(String query, List<Country> countries) {
    if (query.isEmpty) return countries;

    final lowerQuery = query.toLowerCase();
    return countries
        .where((country) =>
            country.name.toLowerCase().contains(lowerQuery) ||
            (country.code?.toLowerCase().contains(lowerQuery) ?? false) ||
            (country.dialCode?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }
}
