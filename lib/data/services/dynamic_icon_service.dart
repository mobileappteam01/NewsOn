import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// Service to handle dynamic app icon changes
/// Works on Android using activity-alias mechanism
class DynamicIconService {
  static const MethodChannel _channel = MethodChannel(
    'com.app.newson/dynamic_icon',
  );

  /// Change app icon to a predefined variant
  /// Available variants: 'default', 'variant1', 'variant2', etc.
  /// These must be pre-defined in AndroidManifest.xml as activity-alias entries
  static Future<bool> changeIcon(String iconName) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('⚠️ Dynamic icon change is only supported on Android');
        return false;
      }

      final result = await _channel.invokeMethod('changeIcon', {
        'iconName': iconName,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ Error changing app icon: $e');
      return false;
    }
  }

  /// Download icon from URL and apply it
  /// Note: This requires the icon to be pre-registered in AndroidManifest.xml
  /// For truly dynamic icons, we need to use a predefined set of icon variants
  static Future<bool> changeIconFromUrl(String iconUrl) async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('⚠️ Dynamic icon change is only supported on Android');
        return false;
      }

      // Download the icon
      final response = await http.get(Uri.parse(iconUrl));
      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download icon from URL: $iconUrl');
        return false;
      }

      // Save to temporary directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/dynamic_icon.png');
      await file.writeAsBytes(response.bodyBytes);

      // Apply the icon
      // Note: This will use a predefined activity-alias
      // For truly dynamic icons, you need to pre-register multiple variants
      final result = await _channel.invokeMethod('changeIconFromFile', {
        'iconPath': file.path,
      });

      return result == true;
    } catch (e) {
      debugPrint('❌ Error changing icon from URL: $e');
      return false;
    }
  }

  /// Get current active icon name
  static Future<String?> getCurrentIcon() async {
    try {
      if (!Platform.isAndroid) {
        return null;
      }

      final result = await _channel.invokeMethod('getCurrentIcon');
      return result as String?;
    } catch (e) {
      debugPrint('❌ Error getting current icon: $e');
      return null;
    }
  }

  /// Reset to default icon
  static Future<bool> resetToDefault() async {
    return await changeIcon('default');
  }
}
