import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/theme_provider.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key});

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  late ThemeMode _selectedMode;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _selectedMode = themeProvider.themeMode;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RemoteConfigProvider, ThemeProvider>(
      builder: (context, configProvider, themeProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  commonappBar(config.appNameLogo, () {
                    Navigator.pop(context);
                  }),
                  giveHeight(12),

                  // Title
                  Text(
                    LocalizationHelper.appearance(context),
                    style: GoogleFonts.playfairDisplay(
                      color: config.primaryColorValue,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  giveHeight(24),

                  // Light mode
                  _buildModeOption(
                    title: LocalizationHelper.lightMode(context),
                    theme: theme,
                    mode: ThemeMode.light,
                    isSelected: _selectedMode == ThemeMode.light,
                    config: config,
                    onTap: () async {
                      setState(() => _selectedMode = ThemeMode.light);
                      await themeProvider.setThemeMode(ThemeMode.light);
                    },
                  ),
                  giveHeight(10),

                  // Dark mode
                  _buildModeOption(
                    title: LocalizationHelper.darkMode(context),
                    theme: theme,
                    mode: ThemeMode.dark,
                    isSelected: _selectedMode == ThemeMode.dark,
                    config: config,
                    onTap: () async {
                      setState(() => _selectedMode = ThemeMode.dark);
                      await themeProvider.setThemeMode(ThemeMode.dark);
                    },
                  ),

                  giveHeight(10),

                  // System default mode (optional)
                  _buildModeOption(
                    title: LocalizationHelper.systemDefault(context),
                    theme: theme,
                    mode: ThemeMode.system,
                    isSelected: _selectedMode == ThemeMode.system,
                    config: config,
                    onTap: () async {
                      setState(() => _selectedMode = ThemeMode.system);
                      await themeProvider.setThemeMode(ThemeMode.system);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeOption({
    required String title,
    required ThemeMode mode,
    required bool isSelected,
    required dynamic config,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.secondary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: theme.colorScheme.secondary,
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? config.primaryColorValue : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
