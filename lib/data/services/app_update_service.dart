import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_model.dart';
import 'api_service.dart';

/// Service to check for app updates
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final ApiService _apiService = ApiService();
  
  AppUpdateModel? _cachedUpdateInfo;
  PackageInfo? _packageInfo;
  bool _hasCheckedUpdate = false;

  /// Get cached update info
  AppUpdateModel? get cachedUpdateInfo => _cachedUpdateInfo;
  
  /// Get current app version
  String get currentAppVersion => _packageInfo?.version ?? '0.0.0';
  
  /// Get current build number
  String get currentBuildNumber => _packageInfo?.buildNumber ?? '0';

  /// Initialize package info
  Future<void> _initPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    debugPrint('📱 App Version: ${_packageInfo!.version}');
    debugPrint('📱 Build Number: ${_packageInfo!.buildNumber}');
  }

  /// Check for app updates
  /// Returns AppUpdateModel if update is available, null otherwise
  Future<AppUpdateModel?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // Don't check again if already checked (unless forced)
      if (_hasCheckedUpdate && !forceCheck && _cachedUpdateInfo != null) {
        debugPrint('📦 Using cached update info');
        return _cachedUpdateInfo;
      }

      debugPrint('🔍 Checking for app updates...');

      // Initialize package info
      await _initPackageInfo();

      // Fetch update info from API
      // Module: 'appupdate', Endpoint key: 'appupdate' (based on user's description)
      final response = await _apiService.get('app', 'appupdate');

      if (response.success && response.data != null) {

        final data = response.data;
        
        // Handle response structure: { "message": "success", "data": {...} }
        Map<String, dynamic>? updateData;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
            updateData = data['data'] as Map<String, dynamic>;
          } else {
            updateData = data;
          }
        }

        if (updateData != null) {
          _cachedUpdateInfo = AppUpdateModel.fromJson(updateData);
          _hasCheckedUpdate = true;

          debugPrint('✅ Update info fetched: $_cachedUpdateInfo');

          // Check if update is available
          if (_cachedUpdateInfo!.isUpdateAvailable(currentAppVersion)) {
            debugPrint('🆕 Update available: ${_cachedUpdateInfo!.newVersion}');
            return _cachedUpdateInfo;
          } else {
            debugPrint('✅ App is up to date (current: $currentAppVersion, server: ${_cachedUpdateInfo!.newVersion})');
            return null;
          }
        }
      }

      debugPrint('⚠️ No update info available from API');
      _hasCheckedUpdate = true;
      return null;
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
      _hasCheckedUpdate = true;
      return null;
    }
  }

  /// Check if update should be shown (considering force update)
  Future<bool> shouldShowUpdateDialog() async {
    final updateInfo = await checkForUpdate();
    return updateInfo != null && updateInfo.isActive;
  }

  /// Get the appropriate store link based on platform
  String? getStoreLink() {
    if (_cachedUpdateInfo == null) return null;
    
    if (Platform.isAndroid) {
      return _cachedUpdateInfo!.androidLink;
    } else if (Platform.isIOS) {
      return _cachedUpdateInfo!.iosLink;
    }
    return null;
  }

  /// Open store link for update
  Future<bool> openStoreLink() async {
    final link = getStoreLink();
    if (link == null || link.isEmpty) {
      debugPrint('⚠️ No store link available');
      return false;
    }

    try {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint('❌ Cannot launch URL: $link');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error opening store link: $e');
      return false;
    }
  }

  /// Get full image URL for update media
  String? getMediaUrl() {
    if (_cachedUpdateInfo?.media == null) return null;
    
    final mediaUrl = _cachedUpdateInfo!.media!.url;
    if (mediaUrl.isEmpty) return null;
    
    // If it's already a full URL, return as is
    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
      return mediaUrl;
    }
    
    // Otherwise, prepend the image base URL
    final imageBaseUrl = _apiService.getImageBaseUrl();
    if (imageBaseUrl != null && imageBaseUrl.isNotEmpty) {
      return '$imageBaseUrl/$mediaUrl';
    }
    
    return mediaUrl;
  }

  /// Reset update check (for testing or re-checking)
  void resetUpdateCheck() {
    _hasCheckedUpdate = false;
    _cachedUpdateInfo = null;
  }
}
