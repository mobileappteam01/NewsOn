import 'package:just_audio/just_audio.dart';

/// Minimal audio player surface for background music.
///
/// Production: [JustAudioPlayerAdapter]
/// Tests: [FakeAudioPlayerAdapter]
abstract class AudioPlayerAdapter {
  Future<void> initialize({required double volume});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> setAudioSource(AudioSource source);
  Future<void> dispose();

  /// True when a non-idle source is loaded.
  bool get hasLoadedSource;
}

/// Production adapter wrapping [AudioPlayer] from just_audio.
class JustAudioPlayerAdapter implements AudioPlayerAdapter {
  JustAudioPlayerAdapter({AudioPlayer? player}) : _owned = player == null {
    _player = player ?? AudioPlayer();
  }

  late final AudioPlayer _player;
  final bool _owned;
  bool _disposed = false;

  AudioPlayer get raw => _player;

  @override
  Future<void> initialize({required double volume}) async {
    await _player.setVolume(volume);
    await _player.setLoopMode(LoopMode.one);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setAudioSource(AudioSource source) =>
      _player.setAudioSource(source);

  @override
  bool get hasLoadedSource =>
      !_disposed && _player.processingState != ProcessingState.idle;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_owned) {
      await _player.dispose();
    }
  }
}
