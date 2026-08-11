import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';

/// Provider for managing app theme
class ThemeProvider with ChangeNotifier {
  late ThemeMode _themeMode;

  ThemeProvider() {
    // Sync read — storage is already initialized in main() before runApp.
    // Avoids a first-frame theme flash (empty/wrong colors).
    _themeMode = _themeModeFromStorage();
  }

  ThemeMode get themeMode => _themeMode;

  static ThemeMode _themeModeFromStorage() {
    switch (StorageService.getThemeMode()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      default:
        modeString = 'system';
    }

    await StorageService.saveThemeMode(modeString);
    notifyListeners();
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}
