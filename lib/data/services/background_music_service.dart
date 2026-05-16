import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/utils/connectivity_helper.dart';
import 'news_audio_cache_service.dart';
import 'storage_service.dart';

/// Background Music Service
/// Manages background music playback with mild volume
class BackgroundMusicService {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
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
  /// Returns a Future that completes when initialization is done (for first-time wait).
  /// If init is already in progress, waits for it instead of starting a second one.
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
      // Fetch background music URL from Firebase
      await _fetchBackgroundMusicUrl();

      // Set initial volume to stored or default level
      await _player.setVolume(_volume);
      await _player.setLoopMode(LoopMode.one); // Loop the background music
      _isInitialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
      debugPrint(
          '🎵 BackgroundMusicService initialized with URL: $_primaryMusicUrl, volume: $_volume');
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundMusicService: $e');
      // Set fallback URL if Firebase fetch fails
      _primaryMusicUrl =
          'https://www.chosic.com/wp-content/uploads/2022/10/True-Patriot(chosic.com).mp3';
      debugPrint('🎵 Using fallback URL: $_primaryMusicUrl');

      // Retry initialization with fallback URL
      await _player.setVolume(_volume);
      await _player.setLoopMode(LoopMode.one);
      _isInitialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
  }

  bool _isOperationCancelled(int generation) => generation != _operationGeneration;

  /// Start background music. Only plays when news is playing; call stop() when news stops.
  Future<void> start() async {
    if (!_isInitialized) await initialize();

    // Ensure we have a valid URL
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

        // Brief wait for source to be ready (keep short so BG starts quickly)
        await Future.delayed(const Duration(milliseconds: 150));
        if (_isOperationCancelled(generation)) return;

        // Start playback
        await _player.play();
        if (_isOperationCancelled(generation)) {
          await _player.stop();
          return;
        }
        _isPlaying = true;
        _wasStartedThisSession = true;
        debugPrint('🎵 Background music started successfully');

        // Brief verify (if we were stopped during this delay, treat as cancelled, don't throw)
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isOperationCancelled(generation) || !_isPlaying) return;
        if (!_player.playing) {
          _isPlaying = false;
          _wasStartedThisSession = false;
          debugPrint('❌ Background music failed to start playing');
          throw Exception('Background music failed to start');
        }
      }
    } catch (e) {
      if (_isOperationCancelled(generation)) return;
      debugPrint('❌ Error starting background music: $e');
      _isPlaying = false;
      _wasStartedThisSession = false;
      rethrow;
    }
  }

  /// Stop background music. Call whenever news stops (pause, stop, complete, error, switch).
  Future<void> stop() async {
    _operationGeneration++;
    _isPlaying = false;
    _wasStartedThisSession = false;
    try {
      if (_player.processingState != ProcessingState.idle) {
        await _player.stop();
        debugPrint('🛑 Background music stopped');
      }
    } catch (e) {
      debugPrint('❌ Error stopping background music: $e');
    }
  }

  /// Pause background music. Pauses whenever the player has a loaded source
  /// (not idle), so BG pauses even if user paused news before start() finished.
  Future<void> pause() async {
    try {
      if (_player.processingState != ProcessingState.idle) {
        await _player.pause();
        _isPlaying = false;
        debugPrint('⏸️ Background music paused');
      }
    } catch (e) {
      debugPrint('❌ Error pausing background music: $e');
      _isPlaying = false;
    }
  }

  /// Resume background music. No-op if we never started this session (avoids wrong play).
  Future<void> resume() async {
    try {
      if (!_wasStartedThisSession) {
        debugPrint('🎵 Background music resume skipped (was not started this session)');
        return;
      }
      if (!_isPlaying && _player.processingState != ProcessingState.idle) {
        await _player.play();
        _isPlaying = true;
        debugPrint('▶️ Background music resumed');
      }
    } catch (e) {
      debugPrint('❌ Error resuming background music: $e');
    }
  }

  /// Start or resume background music depending on current player state.
  /// - If a source is already loaded (paused), resume from current position.
  /// - If idle (stopped or never started), start from the beginning.
  Future<void> startOrResume() async {
    if (!_wasStartedThisSession) {
      await start();
      return;
    }
    if (_player.processingState != ProcessingState.idle) {
      await resume();
    } else {
      await start();
    }
  }

  /// Set background music volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    // Clamp volume to valid range
    _volume = volume.clamp(0.0, 1.0);

    if (_isInitialized) {
      await _player.setVolume(_volume);
    }
    debugPrint('🔊 Background music volume set to: $_volume');
  }

  /// Get current background music volume
  double get volume => _volume;

  /// Check if background music is playing
  bool get isPlaying => _isPlaying;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose the service. Always stop first so no music plays after dispose.
  Future<void> dispose() async {
    try {
      await stop();
      await _player.dispose();
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

  /// Get current background music URL
  String? get currentMusicUrl => _primaryMusicUrl;
}
