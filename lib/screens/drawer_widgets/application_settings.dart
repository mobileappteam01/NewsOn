import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';
import 'text_size_settings.dart';
import 'appearance_settings.dart';
import 'news_reading_settings.dart';

class ApplicationSettings extends StatefulWidget {
  const ApplicationSettings({super.key});

  @override
  State<ApplicationSettings> createState() => _ApplicationSettingsState();
}

class _ApplicationSettingsState extends State<ApplicationSettings> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 App Header
                  commonappBar(config.appNameLogo, () {
                    Navigator.pop(context);
                  }),
                  giveHeight(12),

                  // 🔹 Title
                  Text(
                    LocalizationHelper.applicationSettings(context),
                    style: GoogleFonts.playfairDisplay(
                      color: config.primaryColorValue,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  giveHeight(24),

                  // 🔹 Settings Options
                  _buildSettingItem(
                    title: LocalizationHelper.textSize(context),
                    theme: theme,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TextSizeSettings(),
                          ),
                        ),
                  ),
                  _divider(),
                  _buildSettingItem(
                    title: LocalizationHelper.appearance(context),
                    theme: theme,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppearanceSettings(),
                          ),
                        ),
                  ),
                  _divider(),
                  _buildSettingItem(
                    title: LocalizationHelper.newsReadingSettings(context),
                    theme: theme,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewsReadingSettings(),
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

  Widget _buildSettingItem({
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: theme.colorScheme.secondary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.colorScheme.secondary,
      ),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(color: Colors.grey, thickness: 0.5);
}
