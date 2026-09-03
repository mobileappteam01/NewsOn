import 'package:flutter/foundation.dart';

import '../models/region_model.dart';
import 'api_service.dart';
import 'user_service.dart';

class RegionListResponse {
  const RegionListResponse({
    required this.success,
    required this.regions,
    this.error,
  });

  final bool success;
  final List<RegionModel> regions;
  final String? error;
}

/// Fetches region lists from Firestore-configured endpoints (module: region).
class RegionApiService {
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();

  static const String _module = 'region';

  Future<RegionListResponse> fetchCountries() async {
    return _fetchList(
      endpointKey: 'countries',
      queryParameters: const {},
    );
  }

  Future<RegionListResponse> fetchStates(String country) async {
    return _fetchList(
      endpointKey: 'states',
      queryParameters: {'country': country.trim()},
    );
  }

  Future<RegionListResponse> fetchDistricts({
    required String country,
    required String state,
  }) async {
    return _fetchList(
      endpointKey: 'district',
      queryParameters: {
        'country': country.trim(),
        'state': state.trim(),
      },
    );
  }

  Future<RegionListResponse> _fetchList({
    required String endpointKey,
    required Map<String, String> queryParameters,
  }) async {
    try {
      // Public on backend for guest browse (App Store 5.1.1(v)); token optional.
      final token = _userService.isLoggedIn ? _userService.getToken() : null;

      if (!_apiService.isInitialized) {
        await _apiService.initialize();
      }

      final response = await _apiService.get(
        _module,
        endpointKey,
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
        bearerToken: token,
      );

      if (!response.success) {
        return RegionListResponse(
          success: false,
          regions: const [],
          error: response.error ?? 'Failed to load regions',
        );
      }

      final regions = _parseRegions(response.data);
      return RegionListResponse(success: true, regions: regions);
    } catch (e) {
      debugPrint('❌ RegionApiService.$endpointKey: $e');
      final message = e.toString();
      if (message.contains('not found') || message.contains('Endpoint')) {
        return RegionListResponse(
          success: false,
          regions: const [],
          error: 'Region endpoint "$endpointKey" is not configured in Firestore',
        );
      }
      return RegionListResponse(
        success: false,
        regions: const [],
        error: message,
      );
    }
  }

  List<RegionModel> _parseRegions(dynamic data) {
    if (data == null) return const [];

    if (data is Map<String, dynamic>) {
      final list = data['data'];
      if (list is List) {
        return _mapList(list);
      }
    }

    if (data is List) {
      return _mapList(data);
    }

    return const [];
  }

  List<RegionModel> _mapList(List list) {
    return list
        .whereType<Map>()
        .map((item) => RegionModel.fromJson(Map<String, dynamic>.from(item)))
        .where((r) => r.name.isNotEmpty)
        .toList();
  }
}
