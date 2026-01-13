import 'dart:async';
import 'dart:ui' show Color;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/news_article.dart';

/// Background Audio Service Handler
/// Manages audio playback in the background with notification controls
/// This service shares the AudioPlayer instance with AudioPlayerService
class AudioBackgroundService {
  static NewsAudioHandler? _audioHandler;
  static bool _isInitialized = false;

  /// Initialize the audio service - call this once at app startup
  static Future<NewsAudioHandler> init() async {
    if (_isInitialized && _audioHandler != null) {
      debugPrint('✅ AudioBackgroundService already initialized');
      return _audioHandler!;
    }

    debugPrint('🎵 Initializing AudioBackgroundService...');
    _audioHandler = await AudioService.init(
      builder: () => NewsAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.app.newson.audio',
        androidNotificationChannelName: 'News Audio',
        androidNotificationChannelDescription: 'Playback controls for news articles',
        androidNotificationOngoing: false, // Allow notification to be dismissed
        androidStopForegroundOnPause: true, // Stop foreground when paused (allows swipe dismiss)
        androidShowNotificationBadge: true,
        notificationColor: const Color(0xFFE31E24), // App primary color
        androidNotificationIcon: 'drawable/ic_notification', // Custom notification icon
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );
    _isInitialized = true;
    debugPrint('✅ AudioBackgroundService initialized successfully');
    return _audioHandler!;
  }

  /// Get the audio handler instance
  static NewsAudioHandler? get handler => _audioHandler;

  /// Check if initialized
  static bool get isInitialized => _isInitialized;
}

/// Audio Handler for background playback
/// Implements BaseAudioHandler with SeekHandler for seek functionality
class NewsAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // Stream subscriptions
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<SequenceState?>? _sequenceStateSubscription;

  // Current article for metadata
  NewsArticle? _currentArticle;
  
  // Callbacks for playlist navigation (set by AudioPlayerProvider)
  Function()? onSkipToNext;
  Function()? onSkipToPrevious;

  /// Get the underlying AudioPlayer instance
  AudioPlayer get player => _player;

  NewsAudioHandler() {
    _initializeStreams();
    debugPrint('🎵 NewsAudioHandler created');
  }

  /// Initialize stream listeners
  void _initializeStreams() {
    // Transform playback events to audio_service PlaybackState
    _playbackEventSubscription = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Listen to duration changes
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        // Update media item with duration
        final updatedItem = mediaItem.value!.copyWith(duration: duration);
        mediaItem.add(updatedItem);
      }
    });

    // Listen to sequence state for queue updates
    _sequenceStateSubscription = _player.sequenceStateStream.listen((state) {
      if (state != null && state.sequence.isNotEmpty) {
        // Update queue if needed
        _updateQueue(state);
      }
    });
  }

  /// Broadcast current playback state to notification and UI
  void _broadcastState() {
    final playing = _player.playing;
    
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex ?? 0,
    ));
  }

  /// Map just_audio ProcessingState to audio_service AudioProcessingState
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Update queue from sequence state
  void _updateQueue(SequenceState state) {
    final items = state.sequence.map((source) {
      final tag = source.tag;
      if (tag is MediaItem) {
        return tag;
      }
      return MediaItem(
        id: source.hashCode.toString(),
        title: 'News Article',
      );
    }).toList();
    
    if (items.isNotEmpty) {
      queue.add(items);
    }
  }

  /// Set the current article and update media item
  Future<void> setCurrentArticle(NewsArticle article, {Duration? duration}) async {
    _currentArticle = article;
    
    final item = MediaItem(
      id: article.articleId ?? article.title,
      title: article.title,
      artist: article.sourceName ?? 'NewsOn',
      album: article.category?.isNotEmpty == true ? article.category!.first : 'News',
      artUri: article.imageUrl != null && article.imageUrl!.isNotEmpty 
          ? Uri.tryParse(article.imageUrl!) 
          : null,
      duration: duration ?? _player.duration,
      extras: {
        'articleId': article.articleId,
        'sourceIcon': article.sourceIcon,
      },
    );
    
    mediaItem.add(item);
    debugPrint('🎵 Media item updated: ${article.title}');
    
    // IMPORTANT: Broadcast state to refresh notification with new media item
    _broadcastState();
  }

  /// Play audio from URL
  Future<void> playFromUrl(String url) async {
    try {
      debugPrint('🎵 [AudioHandler] Playing from URL: $url');
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint('❌ [AudioHandler] Error playing from URL: $e');
      rethrow;
    }
  }

  /// Set audio source (for concatenating multiple sources)
  Future<void> setAudioSource(AudioSource source) async {
    try {
      await _player.setAudioSource(source);
    } catch (e) {
      debugPrint('❌ [AudioHandler] Error setting audio source: $e');
      rethrow;
    }
  }

  // ============ BaseAudioHandler overrides ============

  @override
  Future<void> play() async {
    debugPrint('▶️ [AudioHandler] Play');
    await _player.play();
  }

  @override
  Future<void> pause() async {
    debugPrint('⏸️ [AudioHandler] Pause');
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    debugPrint('⏹️ [AudioHandler] Stop');
    await _player.stop();
    // Reset position
    await _player.seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint('⏩ [AudioHandler] Seek to ${position.inSeconds}s');
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    debugPrint('🏃 [AudioHandler] Set speed: $speed');
    await _player.setSpeed(speed);
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + const Duration(seconds: 10);
    final duration = _player.duration ?? Duration.zero;
    await seek(newPosition > duration ? duration : newPosition);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('⏭️ [AudioHandler] Skip to next');
    // Use callback if set (for playlist navigation via AudioPlayerProvider)
    if (onSkipToNext != null) {
      onSkipToNext!();
    } else if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('⏮️ [AudioHandler] Skip to previous');
    // Use callback if set (for playlist navigation via AudioPlayerProvider)
    if (onSkipToPrevious != null) {
      onSkipToPrevious!();
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    debugPrint('🗑️ [AudioHandler] Task removed - stopping playback');
    await stop();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _playbackEventSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _currentIndexSubscription?.cancel();
    await _sequenceStateSubscription?.cancel();
    await _player.dispose();
    debugPrint('🗑️ [AudioHandler] Disposed');
  }

  // ============ Getters for player state ============

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Duration get bufferedPosition => _player.bufferedPosition;
  double get speed => _player.speed;
  ProcessingState get processingState => _player.processingState;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  NewsArticle? get currentArticle => _currentArticle;
}
