import '../../data/models/remote_config_model.dart';

/// Global voice/audio feature gate driven by Firebase Remote Config
/// (`enable_voice_features`). Updated whenever [RemoteConfigProvider] loads config.
class VoiceFeatures {
  VoiceFeatures._();

  static bool _enabled = true;

  /// Whether listen, TTS playback, mini player, and related settings are available.
  static bool get isEnabled => _enabled;

  static void applyFromConfig(RemoteConfigModel config) {
    _enabled = config.enableVoiceFeatures;
  }
}
