import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
import '../../providers/remote_config_provider.dart';

class NewsReadingSettings extends StatefulWidget {
  const NewsReadingSettings({super.key});

  @override
  State<NewsReadingSettings> createState() => _NewsReadingSettingsState();
}

class _NewsReadingSettingsState extends State<NewsReadingSettings> {
  String _selectedMode = AppConstants.defaultReadingMode;

  @override
  void initState() {
    super.initState();
    _loadReadingMode();
  }

  void _loadReadingMode() {
    final savedMode = StorageService.getNewsReadingMode();
    setState(() {
      _selectedMode = savedMode;
    });
  }

  Future<void> _saveReadingMode(String mode) async {
    debugPrint('🎧 NewsReadingSettings: User selected mode: "$mode"');
    await StorageService.saveNewsReadingMode(mode);
    
    // Verify the save was successful by reading it back
    final savedMode = StorageService.getNewsReadingMode();
    debugPrint('🎧 NewsReadingSettings: Verified saved mode: "$savedMode"');
    
    setState(() {
      _selectedMode = mode;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocalizationHelper.settingsSaved(context)} - Mode: ${_getModeDisplayName(mode)}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  String _getModeDisplayName(String mode) {
    switch (mode) {
      case AppConstants.readingModeTitleOnly:
        return 'Title Only';
      case AppConstants.readingModeDescriptionOnly:
        return 'Description Only';
      case AppConstants.readingModeFullNews:
        return 'Full News';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
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
                    LocalizationHelper.selectNewsReadingMode(context),
                    style: GoogleFonts.playfairDisplay(
                      color: config.primaryColorValue,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  giveHeight(24),

                  // Play Title Only option
                  _buildModeOption(
                    title: LocalizationHelper.playTitleOnly(context),
                    theme: theme,
                    mode: AppConstants.readingModeTitleOnly,
                    isSelected: _selectedMode == AppConstants.readingModeTitleOnly,
                    config: config,
                    onTap: () => _saveReadingMode(AppConstants.readingModeTitleOnly),
                  ),
                  giveHeight(10),

                  // Play Description Only option
                  _buildModeOption(
                    title: LocalizationHelper.playDescriptionOnly(context),
                    theme: theme,
                    mode: AppConstants.readingModeDescriptionOnly,
                    isSelected: _selectedMode == AppConstants.readingModeDescriptionOnly,
                    config: config,
                    onTap: () => _saveReadingMode(AppConstants.readingModeDescriptionOnly),
                  ),
                  giveHeight(10),

                  // Play Full News option
                  _buildModeOption(
                    title: LocalizationHelper.playFullNews(context),
                    theme: theme,
                    mode: AppConstants.readingModeFullNews,
                    isSelected: _selectedMode == AppConstants.readingModeFullNews,
                    config: config,
                    onTap: () => _saveReadingMode(AppConstants.readingModeFullNews),
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
    required String mode,
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
          border: Border.all(
            color: isSelected
                ? config.primaryColorValue
                : theme.colorScheme.secondary,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? config.primaryColorValue.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? config.primaryColorValue
                      : theme.colorScheme.secondary,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? config.primaryColorValue : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
