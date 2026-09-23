import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/utils/connectivity_helper.dart';
import 'audio_player_adapter.dart';
import 'news_audio_cache_service.dart';
import 'storage_service.dart';

/// Background Music Service
/// Manages background music playback with mild volume
class BackgroundMusicService {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _testOverride ?? _instance;

  BackgroundMusicService._internal({AudioPlayerAdapter? player})
      : _injectedPlayer = player;

  /// Test-only constructor — does not replace the production singleton.
  @visibleForTesting
  factory BackgroundMusicService.forTesting({
    required AudioPlayerAdapter player,
  }) {
    return BackgroundMusicService._internal(player: player);
  }

  static BackgroundMusicService? _testOverride;

  /// Override the singleton for tests. Pass null to restore production.
  @visibleForTesting
  static void debugOverrideInstance(BackgroundMusicService? instance) {
    _testOverride = instance;
  }

  final AudioPlayerAdapter? _injectedPlayer;
  AudioPlayerAdapter? _lazyPlayer;

  /// Lazily creates the real just_audio adapter only when playback is needed.
  AudioPlayerAdapter get _player {
    final injected = _injectedPlayer;
    if (injected != null) return injected;
    return _lazyPlayer ??= JustAudioPlayerAdapter();
  }

  bool _isInitialized = false;
  bool _isPlaying = false;

  /// True only after start() has successfully run at least once this session.
  /// Used so resume() does nothing if we never started (avoids play() with no source).
  bool _wasStartedThisSession = false;
  String? _primaryMusicUrl;
  AudioSource? _bgAudioSource;
  String? _loadedBgSourceKey;
  double _volume = 0.19; // Store volume separately
  Completer<void>? _initCompleter;

  /// Incremented on [stop] so in-flight [start] calls exit before playing.
  int _operationGeneration = 0;

  /// Ensure service is initialized. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();
    try {
      await initialize();
    } finally {
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
    return _initCompleter!.future;
  }

  /// Initialize the background music service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _fetchBackgroundMusicUrl();
      await _player.initialize(volume: _volume);
      _isInitialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
      debugPrint(
        '🎵 BackgroundMusicService initialized with URL: $_primaryMusicUrl, volume: $_volume',
      );
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundMusicService: $e');
      _primaryMusicUrl =
          'https://www.chosic.com/wp-content/uploads/2022/10/True-Patriot(chosic.com).mp3';
      debugPrint('🎵 Using fallback URL: $_primaryMusicUrl');

      await _player.initialize(volume: _volume);
      _isInitialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
  }

  bool _isOperationCancelled(int generation) =>
      generation != _operationGeneration;

  /// Start background music. Only plays when news is playing; call stop() when news stops.
  Future<void> start() async {
    if (!_isInitialized) await initialize();

    if (_primaryMusicUrl == null || _primaryMusicUrl!.isEmpty) {
      debugPrint('❌ No background music URL available');
      return;
    }

    final generation = _operationGeneration;

    try {
      if (!_isPlaying) {
        debugPrint('🎵 Starting background music with URL: $_primaryMusicUrl');

        final source = await _resolveBackgroundMusicSource();
        if (_bgAudioSource == null || _loadedBgSourceKey != _primaryMusicUrl) {
          _bgAudioSource = source;
          _loadedBgSourceKey = _primaryMusicUrl;
          await _player.setAudioSource(source);
        }
        if (_isOperationCancelled(generation)) return;

        await _player.play();
        if (_isOperationCancelled(generation)) {
          await _player.pause();
          return;
        }
        _isPlaying = true;
        _wasStartedThisSession = true;
        debugPrint('🎵 Background music started successfully');
      }
    } catch (e) {
      if (_isOperationCancelled(generation)) return;
      debugPrint('❌ Error starting background music: $e');
      _isPlaying = false;
      _wasStartedThisSession = false;
      rethrow;
    }
  }

  /// Stop background music.
  Future<void> stop() async {
    _operationGeneration++;
    _isPlaying = false;
    _wasStartedThisSession = false;
    try {
      if (_lazyPlayer != null || _injectedPlayer != null) {
        if (_player.hasLoadedSource) {
          await _player.stop();
          debugPrint('🛑 Background music stopped');
        }
      }
    } catch (e) {
      debugPrint('❌ Error stopping background music: $e');
    }
  }

  /// Pause background music.
  Future<void> pause() async {
    try {
      if ((_lazyPlayer != null || _injectedPlayer != null) &&
          _player.hasLoadedSource) {
        await _player.pause();
        _isPlaying = false;
        debugPrint('⏸️ Background music paused');
      }
    } catch (e) {
      debugPrint('❌ Error pausing background music: $e');
      _isPlaying = false;
    }
  }

  /// Resume background music. No-op if we never started this session.
  Future<void> resume() async {
    try {
      if (!_wasStartedThisSession) {
        debugPrint(
          '🎵 Background music resume skipped (was not started this session)',
        );
        return;
      }
      if (!_isPlaying &&
          (_lazyPlayer != null || _injectedPlayer != null) &&
          _player.hasLoadedSource) {
        await _player.play();
        _isPlaying = true;
        debugPrint('▶️ Background music resumed');
      }
    } catch (e) {
      debugPrint('❌ Error resuming background music: $e');
    }
  }

  /// Start or resume background music depending on current player state.
  Future<void> startOrResume() async {
    if (!_wasStartedThisSession) {
      await start();
      return;
    }
    if ((_lazyPlayer != null || _injectedPlayer != null) &&
        _player.hasLoadedSource) {
      await resume();
    } else {
      await start();
    }
  }

  /// Set background music volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    if (_isInitialized &&
        (_lazyPlayer != null || _injectedPlayer != null)) {
      await _player.setVolume(_volume);
    }
    debugPrint('🔊 Background music volume set to: $_volume');
  }

  double get volume => _volume;

  bool get isPlaying => _isPlaying;

  bool get isInitialized => _isInitialized;

  /// Dispose the service. Always stop first so no music plays after dispose.
  Future<void> dispose() async {
    try {
      await stop();
      if (_lazyPlayer != null || _injectedPlayer != null) {
        await _player.dispose();
      }
      _lazyPlayer = null;
      _isPlaying = false;
      _wasStartedThisSession = false;
      _isInitialized = false;
      _primaryMusicUrl = null;
      _initCompleter = null;
      debugPrint('🗑️ BackgroundMusicService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing BackgroundMusicService: $e');
      _isPlaying = false;
      _wasStartedThisSession = false;
      _isInitialized = false;
    }
  }

  Future<AudioSource> _resolveBackgroundMusicSource() async {
    final url = _primaryMusicUrl;
    if (url == null || url.isEmpty) {
      throw Exception('No background music URL available');
    }
    return NewsAudioCacheService.instance.resolvePlaybackSource(url);
  }

  /// Fetch background music URL from Firebase Realtime Database (with offline cache).
  Future<void> _fetchBackgroundMusicUrl() async {
    const cacheKey = 'bgMusicUrl';
    final cachedUrl = StorageService.getRealtimeDbCache(cacheKey);
    final cachedString =
        cachedUrl is String ? cachedUrl : cachedUrl?.toString();

    if (await ConnectivityHelper.hasConnection()) {
      try {
        final DatabaseReference ref = FirebaseDatabase.instance.ref();
        final DataSnapshot snapshot = await ref.child(cacheKey).get();

        if (snapshot.exists && snapshot.value != null) {
          _primaryMusicUrl = snapshot.value as String;
          await StorageService.saveRealtimeDbCache(cacheKey, _primaryMusicUrl);
          debugPrint(
            '🎵 Fetched background music URL from Firebase: $_primaryMusicUrl',
          );
          if (_primaryMusicUrl != null && _primaryMusicUrl!.isNotEmpty) {
            unawaited(
              NewsAudioCacheService.instance.downloadAndCache(_primaryMusicUrl!),
            );
          }
          return;
        }
        throw Exception('bgMusicUrl not found in Firebase');
      } catch (e) {
        debugPrint('❌ Error fetching background music URL from Firebase: $e');
        if (cachedString != null && cachedString.isNotEmpty) {
          _primaryMusicUrl = cachedString;
          debugPrint('📦 Using cached background music URL (offline fallback)');
          return;
        }
        rethrow;
      }
    }

    if (cachedString != null && cachedString.isNotEmpty) {
      _primaryMusicUrl = cachedString;
      debugPrint('📦 Using cached background music URL (device offline)');
      return;
    }

    throw Exception('Background music URL not available offline');
  }

  String? get currentMusicUrl => _primaryMusicUrl;
}
