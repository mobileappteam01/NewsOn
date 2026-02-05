import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

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
  String? _primaryMusicUrl;
  double _volume = 0.19; // Store volume separately

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
    }
  }

  /// Start background music
  Future<void> start() async {
    if (!_isInitialized) await initialize();

    // Ensure we have a valid URL
    if (_primaryMusicUrl == null || _primaryMusicUrl!.isEmpty) {
      debugPrint('❌ No background music URL available');
      return;
    }

    try {
      if (!_isPlaying) {
        debugPrint('🎵 Starting background music with URL: $_primaryMusicUrl');

        // Set the URL and wait for it to load
        await _player.setUrl(_primaryMusicUrl!);

        // Wait a bit to ensure the URL is loaded
        await Future.delayed(const Duration(milliseconds: 300));

        // Start playback
        await _player.play();
        _isPlaying = true;
        debugPrint('🎵 Background music started successfully');

        // Verify playback started
        await Future.delayed(const Duration(milliseconds: 200));
        if (!_player.playing) {
          _isPlaying = false;
          debugPrint('❌ Background music failed to start playing');
          throw Exception('Background music failed to start');
        }
      }
    } catch (e) {
      debugPrint('❌ Error starting background music: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// Stop background music
  Future<void> stop() async {
    try {
      if (_isPlaying) {
        await _player.stop();
        _isPlaying = false;
        debugPrint('🛑 Background music stopped');
      }
    } catch (e) {
      debugPrint('❌ Error stopping background music: $e');
    }
  }

  /// Pause background music
  Future<void> pause() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
        debugPrint('⏸️ Background music paused');
      }
    } catch (e) {
      debugPrint('❌ Error pausing background music: $e');
    }
  }

  /// Resume background music
  Future<void> resume() async {
    try {
      if (!_isPlaying) {
        await _player.play();
        _isPlaying = true;
        debugPrint('▶️ Background music resumed');
      }
    } catch (e) {
      debugPrint('❌ Error resuming background music: $e');
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

  /// Dispose the service
  Future<void> dispose() async {
    try {
      await _player.dispose();
      _isPlaying = false;
      _isInitialized = false;
      _primaryMusicUrl = null;
      debugPrint('🗑️ BackgroundMusicService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing BackgroundMusicService: $e');
    }
  }

  /// Fetch background music URL from Firebase Realtime Database
  Future<void> _fetchBackgroundMusicUrl() async {
    try {
      final DatabaseReference ref = FirebaseDatabase.instance.ref();
      final DataSnapshot snapshot = await ref.child('bgMusicUrl').get();

      if (snapshot.exists && snapshot.value != null) {
        _primaryMusicUrl = snapshot.value as String;
        debugPrint(
            '🎵 Fetched background music URL from Firebase: $_primaryMusicUrl');
      } else {
        throw Exception('bgMusicUrl not found in Firebase');
      }
    } catch (e) {
      debugPrint('❌ Error fetching background music URL from Firebase: $e');
      rethrow;
    }
  }

  /// Get current background music URL
  String? get currentMusicUrl => _primaryMusicUrl;
}
