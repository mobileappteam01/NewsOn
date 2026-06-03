import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_background_service.dart';
import 'news_audio_cache_service.dart';

/// Audio Player Service using just_audio
/// Handles audio playback with Spotify-like features
/// Now uses NewsAudioHandler for background playback support
class AudioPlayerService {
  // Use the AudioPlayer from NewsAudioHandler for unified playback
  AudioPlayer? _audioPlayer;
  
  // Stream controllers for state updates (forwarded from handler)
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  
  // Stream subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Current audio source
  String? _currentAudioPath;

  AudioPlayerService() {
    _initialize();
  }

  /// Get the AudioPlayer instance from the handler
  AudioPlayer get _player {
    if (_audioPlayer != null) return _audioPlayer!;
    
    // Try to get from handler
    final handler = AudioBackgroundService.handler;
    if (handler != null) {
      _audioPlayer = handler.player;
      _setupStreamForwarding();
      return _audioPlayer!;
    }
    
    // CRITICAL FALLBACK: this should never happen since init is awaited in main.dart
    debugPrint('❌ CRITICAL ERROR: AudioBackgroundService.handler is null!');
    _audioPlayer = AudioPlayer();
    _setupStreamForwarding();
    return _audioPlayer!;
  }

  void _initialize() {
    // Defer stream setup until player is available
    debugPrint('🎵 AudioPlayerService initialized');
  }
  
  /// Setup stream forwarding from the player
  void _setupStreamForwarding() {
    if (_audioPlayer == null) return;
    
    // Cancel existing subscriptions
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferedSubscription?.cancel();
    _playerStateSubscription?.cancel();
    
    // Listen to position updates
    _positionSubscription = _audioPlayer!.positionStream.listen((position) {
      _positionController.add(position);
    });

    // Listen to duration updates
    _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
      if (duration != null) {
        _durationController.add(duration);
      }
    });

    // Listen to buffered position
    _bufferedSubscription = _audioPlayer!.bufferedPositionStream.listen((buffered) {
      _bufferedPositionController.add(buffered);
    });

    // Listen to player state
    _playerStateSubscription = _audioPlayer!.playerStateStream.listen((state) {
      _playerStateController.add(state);
    });
    
    debugPrint('🎵 AudioPlayerService: Stream forwarding setup complete');
  }

  /// Play audio from file path
  Future<void> playFromPath(String filePath) async {
    try {
      _currentAudioPath = filePath;
      await _player.setFilePath(filePath);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio from path: $e');
      rethrow;
    }
  }

  /// Play audio from bytes (Uint8List)
  Future<void> playFromBytes(Uint8List audioBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // Cleanup old temporary audio files to prevent storage leak
      try {
        final dir = Directory(tempDir.path);
        final files = dir.listSync();
        for (var file in files) {
          if (file.path.contains('newson_tts_') && file.path.endsWith('.mp3')) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to clean up old temp audio files: $e');
      }

      final tempFile = File('${tempDir.path}/newson_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes);
      
      _currentAudioPath = tempFile.path;
      await _player.setFilePath(tempFile.path);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio from bytes: $e');
      rethrow;
    }
  }

  /// Resolve a remote news MP3 URL to a source usable offline after cache (local file) or online stream.
  Future<AudioSource> resolveNewsAudioSource(String url) {
    return NewsAudioCacheService.instance.resolvePlaybackSource(url);
  }

  /// Play audio from URL (uses persistent cache when possible for offline replay).
  Future<void> playFromUrl(String url) async {
    try {
      final source = await resolveNewsAudioSource(url);
      _currentAudioPath = url.trim();
      await _player.setAudioSource(source);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio from URL: $e');
      rethrow;
    }
  }

  /// Set audio source (for concatenating multiple sources)
  Future<void> setAudioSource(AudioSource source) async {
    try {
      await _player.setAudioSource(source);
    } catch (e) {
      debugPrint('Error setting audio source: $e');
      rethrow;
    }
  }

  /// Play audio from asset
  Future<void> playFromAsset(String assetPath) async {
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio from asset: $e');
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  /// Resume playback
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentAudioPath = null;
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Seek to specific position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  /// Set playback speed (0.25x to 2.0x)
  Future<void> setSpeed(double speed) async {
    try {
      // Clamp speed between 0.25 and 2.0
      final clampedSpeed = speed.clamp(0.25, 2.0);
      await _player.setSpeed(clampedSpeed);
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  /// Get current position
  Duration get position => _player.position;

  /// Get total duration
  Duration? get duration => _player.duration;

  /// Get buffered position
  Duration get bufferedPosition => _player.bufferedPosition;

  /// Get current playback state
  PlayerState get playerState => _player.playerState;

  /// Check if playing
  bool get isPlaying => _player.playing;

  /// Get playback speed
  double get speed => _player.speed;

  /// Get volume
  double get volume => _player.volume;

  /// Streams
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<Duration> get bufferedPositionStream => _bufferedPositionController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  /// Get current audio path/URL
  String? get currentAudioPath => _currentAudioPath;

  /// Dispose resources
  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _playerStateController.close();
    // Don't dispose the player here - it's managed by NewsAudioHandler
  }
}

