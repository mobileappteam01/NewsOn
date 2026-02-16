import 'dart:async';
import 'package:flutter/foundation.dart';
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

  Country({
    required this.name,
    this.code,
    this.dialCode,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      dialCode: json['dialCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'dialCode': dialCode,
    };
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Service for fetching location data (cities and countries)
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  final ApiService _apiService = ApiService();

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

      // Initialize API service if needed
      if (!_apiService.isInitialized) {
        await _apiService.initialize();
      }

      // Build query parameters
      Map<String, String> queryParams = {};
      if (country != null) {
        queryParams['country'] = country;
      }

      // Make API call
      final response = await _apiService.get(
        'location',
        'getCities',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final List<dynamic> citiesData = response.data['cities'] ?? [];
        final cities =
            citiesData.map((cityJson) => City.fromJson(cityJson)).toList();

        // Cache if no country filter
        if (country == null) {
          _cachedCities = cities;
        }

        debugPrint('✅ Loaded ${cities.length} cities');
        return cities;
      } else {
        debugPrint('⚠️ Failed to load cities: ${response.error}');
        return _getDefaultCities();
      }
    } catch (e) {
      debugPrint('❌ Error loading cities: $e');
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

      // Initialize API service if needed
      if (!_apiService.isInitialized) {
        await _apiService.initialize();
      }

      // Make API call
      final response = await _apiService.get(
        'location',
        'getCountries',
      );

      if (response.success && response.data != null) {
        final List<dynamic> countriesData = response.data['countries'] ?? [];
        final countries = countriesData
            .map((countryJson) => Country.fromJson(countryJson))
            .toList();

        _cachedCountries = countries;
        debugPrint('✅ Loaded ${countries.length} countries');
        return countries;
      } else {
        debugPrint('⚠️ Failed to load countries: ${response.error}');
        return _getDefaultCountries();
      }
    } catch (e) {
      debugPrint('❌ Error loading countries: $e');
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
