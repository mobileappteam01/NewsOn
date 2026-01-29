import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Background Music Service
/// Manages background music playback with mild volume
class BackgroundMusicService {
  static final BackgroundMusicService _instance = BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  
  // Background music URLs - using the provided URL as primary
  static const String _primaryMusicUrl = 'https://www.chosic.com/wp-content/uploads/2022/10/True-Patriot(chosic.com).mp3';
  static const double _backgroundVolume = 0.15; // 15% volume for mild background music
  
  /// Initialize the background music service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set initial volume to mild level
      await _player.setVolume(_backgroundVolume);
      await _player.setLoopMode(LoopMode.one); // Loop the background music
      _isInitialized = true;
      debugPrint('🎵 BackgroundMusicService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundMusicService: $e');
    }
  }
  
  /// Start playing background music
  Future<void> start() async {
    if (!_isInitialized) await initialize();
    
    try {
      if (!_isPlaying) {
        await _player.setUrl(_primaryMusicUrl);
        await _player.play();
        _isPlaying = true;
        debugPrint('🎵 Background music started');
      }
    } catch (e) {
      debugPrint('❌ Error starting background music: $e');
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
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
      debugPrint('🔊 Background music volume set to: $clampedVolume');
    } catch (e) {
      debugPrint('❌ Error setting background music volume: $e');
    }
  }
  
  /// Check if background music is playing
  bool get isPlaying => _isPlaying;
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get current volume
  double get volume => _player.volume;
  
  /// Dispose the service
  Future<void> dispose() async {
    try {
      await _player.dispose();
      _isPlaying = false;
      _isInitialized = false;
      debugPrint('🗑️ BackgroundMusicService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing BackgroundMusicService: $e');
    }
  }
}
