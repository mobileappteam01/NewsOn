import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
// import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:newson/data/models/app_update_model.dart';
import 'package:newson/core/constants/api_constants.dart';

import '../../core/constants/app_constants.dart';

class AppUpdateService {
  static Future<AppUpdateModel?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/${ApiConstants.appupdate}'),
      );
      print("appupdate ${response.body}");
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['message'] == 'success') {
          final updateInfo = AppUpdateModel.fromJson(jsonData);
          print("updateInfo $updateInfo");
          // Check if update is needed by comparing versions
          // final packageInfo = await PackageInfo.fromPlatform();
          // final currentVersion = packageInfo.version;

          if (_isNewerVersion(updateInfo.newVersion, AppConstants.appVersion)) {
            return updateInfo;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error checking for update: $e');
      return null;
    }
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      for (var i = 0; i < newParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (newParts[i] > currentParts[i]) return true;
        if (newParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> launchUpdate(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }
}
