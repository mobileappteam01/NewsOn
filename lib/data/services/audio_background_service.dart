import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/news_article.dart';

/// Background Audio Service Handler
/// Manages audio playback in the background with notification controls
class AudioBackgroundService {
  static AudioHandler? _audioHandler;

  static Future<AudioHandler> init() async {
    _audioHandler = await AudioService.init(
      builder: () => NewsAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.newson.audio',
        androidNotificationChannelName: 'News Audio',
        androidNotificationChannelDescription:
            'Playback controls for news articles',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
      ),
    );
    return _audioHandler!;
  }

  static AudioHandler? get handler => _audioHandler;
}

/// Audio Handler for background playback
class NewsAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  NewsAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _playlist.clear();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Play article from audio bytes
  Future<void> playArticle(NewsArticle article, Uint8List audioBytes) async {
    try {
      // Create temporary file from bytes
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(audioBytes);

      // Update media item
      mediaItem.add(
        MediaItem(
          id: article.articleId ?? article.title,
          title: article.title,
          artist: article.sourceName ?? 'News',
          artUri:
              article.imageUrl != null ? Uri.parse(article.imageUrl!) : null,
          duration: null, // Will be updated when audio loads
        ),
      );

      // Load and play
      await _playlist.clear();
      await _playlist.add(AudioSource.file(tempFile.path));
      await _player.setAudioSource(_playlist);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing article in background: $e');
      rethrow;
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState:
          const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
