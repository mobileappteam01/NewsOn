import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/background_music_service.dart';
import '../../providers/remote_config_provider.dart';
import '../../providers/audio_player_provider.dart';

/// Settings screen for background music: enable/disable and volume.
/// Background music plays only while news is playing when enabled.
class BackgroundMusicSettings extends StatefulWidget {
  const BackgroundMusicSettings({super.key});

  @override
  State<BackgroundMusicSettings> createState() => _BackgroundMusicSettingsState();
}

class _BackgroundMusicSettingsState extends State<BackgroundMusicSettings> {
  late bool _enabled;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _enabled = StorageService.getBackgroundMusicEnabled();
    _volume = StorageService.getBackgroundMusicVolume();
  }

  Future<void> _setEnabled(bool value) async {
    await StorageService.saveBackgroundMusicEnabled(value);
    setState(() => _enabled = value);
    if (!value) {
      await BackgroundMusicService().stop();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? LocalizationHelper.backgroundMusicEnabled(context)
                : LocalizationHelper.backgroundMusicDisabled(context),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    await StorageService.saveBackgroundMusicVolume(clamped);
    await BackgroundMusicService().setVolume(clamped);
    setState(() => _volume = clamped);
    if (mounted) {
      try {
        context.read<AudioPlayerProvider>().setBackgroundMusicVolume(clamped);
      } catch (_) {
        // Provider may not be in tree when opened from drawer
      }
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
                  commonappBar(
                    config.getAppNameLogoForTheme(Theme.of(context).brightness),
                    () => Navigator.pop(context),
                  ),
                  giveHeight(12),
                  Text(
                    LocalizationHelper.backgroundMusicSettings(context),
                    style: GoogleFonts.playfairDisplay(
                      color: config.primaryColorValue,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  giveHeight(8),
                  Text(
                    LocalizationHelper.backgroundMusicSettingsDescription(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  giveHeight(24),

                  // Enable / Disable
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          LocalizationHelper.enableBackgroundMusic(context),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: _enabled,
                        onChanged: _setEnabled,
                      ),
                    ],
                  ),
                  _divider(),

                  // Volume (only when enabled)
                  if (_enabled) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LocalizationHelper.backgroundMusicVolume(context),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${(_volume * 100).round()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: config.primaryColorValue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: config.primaryColorValue,
                        inactiveTrackColor: config.primaryColorValue.withOpacity(0.3),
                        thumbColor: config.primaryColorValue,
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: _setVolume,
                        min: 0.0,
                        max: 1.0,
                      ),
                    ),
                    _divider(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _divider() => const Divider(color: Colors.grey, thickness: 0.5);
}
