import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/widgets/language_selector_dialog.dart';
import '../../core/config/v2_feature_flags.dart';
import '../../providers/remote_config_provider.dart';
import '../../features/notifications/presentation/notification_preferences.dart';
import 'text_size_settings.dart';
import 'appearance_settings.dart';
import 'news_reading_settings.dart';
import 'background_music_settings.dart';

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
        final voiceEnabled = configProvider.isVoiceFeaturesEnabled;
        final theme = Theme.of(context);
        final showNotifications = V2FeatureFlags.homeReader(config) ||
            V2FeatureFlags.forYou(config);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 App Header
                  commonappBar(
                      config.getAppNameLogoForTheme(
                          Theme.of(context).brightness), () {
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
                    title: LocalizationHelper.language(context),
                    theme: theme,
                    onTap: () => showAppLanguageSelectorDialog(context),
                  ),
                  if (showNotifications) ...[
                    _divider(),
                    const _NotificationToggle(),
                  ],
                  _divider(),
                  _buildSettingItem(
                    title: LocalizationHelper.textSize(context),
                    theme: theme,
                    onTap: () => Navigator.push(
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AppearanceSettings(),
                      ),
                    ),
                  ),
                  if (voiceEnabled) ...[
                    _divider(),
                    _buildSettingItem(
                      title: LocalizationHelper.newsReadingSettings(context),
                      theme: theme,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NewsReadingSettings(),
                        ),
                      ),
                    ),
                    _divider(),
                    _buildSettingItem(
                      title: LocalizationHelper.backgroundMusic(context),
                      theme: theme,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BackgroundMusicSettings(),
                        ),
                      ),
                    ),
                  ],
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

class _NotificationToggle extends StatefulWidget {
  const _NotificationToggle();

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  late final NotificationPreferencesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotificationPreferencesController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final enabled = _controller.prefs.notificationsEnabled;
        final busy = _controller.loading || _controller.updating;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: theme.colorScheme.secondary,
            ),
          ),
          value: enabled,
          onChanged: busy
              ? null
              : (value) => _controller.setNotificationsEnabled(value),
        );
      },
    );
  }
}
