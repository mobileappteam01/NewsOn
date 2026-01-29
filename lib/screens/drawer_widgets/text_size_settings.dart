import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
import '../../providers/remote_config_provider.dart';

class TextSizeSettings extends StatefulWidget {
  const TextSizeSettings({super.key});

  @override
  State<TextSizeSettings> createState() => _TextSizeSettingsState();
}

class _TextSizeSettingsState extends State<TextSizeSettings> {
  late double _textSize;

  @override
  void initState() {
    super.initState();
    // Load saved text size or use default
    _loadTextSize();
  }

  void _loadTextSize() {
    final savedSize = StorageService.getSetting(
      AppConstants.textSizeKey,
      defaultValue: AppConstants.defaultTextSize,
    );
    _textSize =
        (savedSize is double) ? savedSize : AppConstants.defaultTextSize;
  }

  Future<void> _saveTextSize() async {
    await StorageService.saveSetting(AppConstants.textSizeKey, _textSize);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationHelper.textSizeSaved(context))),
      );
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
                  // AppBar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      commonappBar(config.getAppNameLogoForTheme(Theme.of(context).brightness), () {
                        Navigator.pop(context);
                      }),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryColorValue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _saveTextSize,
                        child: Text(
                          LocalizationHelper.save(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  giveHeight(16),

                  // Title
                  Text(
                    LocalizationHelper.textSize(context),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  giveHeight(20),

                  // Slider Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("A-", style: GoogleFonts.poppins(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: _textSize,
                          min: AppConstants.minTextSize,
                          max: AppConstants.maxTextSize,
                          divisions: 12, // 12 steps (12, 13, 14, ..., 24)
                          activeColor: config.primaryColorValue,
                          onChanged: (value) {
                            setState(() => _textSize = value);
                          },
                        ),
                      ),
                      Text("A+", style: GoogleFonts.poppins(fontSize: 18)),
                    ],
                  ),
                  giveHeight(12),

                  // Preview Text (Dynamic from Remote Config)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        config.textSizePreviewText,
                        style: GoogleFonts.poppins(fontSize: _textSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
