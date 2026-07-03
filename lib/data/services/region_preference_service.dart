import 'package:shared_preferences/shared_preferences.dart';

import '../models/region_model.dart';

/// Persists user region selection via SharedPreferences.
class RegionPreferenceService {
  static const String _countryKey = 'region_country';
  static const String _stateKey = 'region_state';
  static const String _districtKey = 'region_district';

  Future<void> saveRegion(SavedRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    if (region.country != null && region.country!.isNotEmpty) {
      await prefs.setString(_countryKey, region.country!);
    } else {
      await prefs.remove(_countryKey);
    }
    if (region.state != null && region.state!.isNotEmpty) {
      await prefs.setString(_stateKey, region.state!);
    } else {
      await prefs.remove(_stateKey);
    }
    if (region.district != null && region.district!.isNotEmpty) {
      await prefs.setString(_districtKey, region.district!);
    } else {
      await prefs.remove(_districtKey);
    }
  }

  Future<SavedRegion> getSavedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return SavedRegion(
      country: prefs.getString(_countryKey),
      state: prefs.getString(_stateKey),
      district: prefs.getString(_districtKey),
    );
  }

  Future<void> clearRegion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countryKey);
    await prefs.remove(_stateKey);
    await prefs.remove(_districtKey);
  }
}
