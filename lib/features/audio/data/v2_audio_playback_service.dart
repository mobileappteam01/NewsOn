import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Dedicated V2 just_audio player — independent of V1 ElevenLabs / VoiceService.
/// Enforces a single active V2 stream.
class V2AudioPlaybackService {
  V2AudioPlaybackService({AudioPlayer? player}) : _playerOrNull = player;

  AudioPlayer? _playerOrNull;
  String? _activeArticleId;

  AudioPlayer get _player => _playerOrNull ??= AudioPlayer();

  String? get activeArticleId => _activeArticleId;
  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;

  Future<void> playUrl({
    required String articleId,
    required String url,
  }) async {
    final id = articleId.trim();
    final src = url.trim();
    if (id.isEmpty || src.isEmpty) {
      throw ArgumentError('articleId and url required');
    }

    if (_activeArticleId != null &&
        _activeArticleId != id &&
        _player.playing) {
      await _player.stop();
    }

    _activeArticleId = id;
    await _player.setUrl(src);
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> stop() async {
    if (_playerOrNull == null) {
      _activeArticleId = null;
      return;
    }
    await _player.stop();
    _activeArticleId = null;
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> dispose() async {
    if (_playerOrNull != null) {
      await _playerOrNull!.dispose();
    }
    _playerOrNull = null;
    _activeArticleId = null;
  }
}
