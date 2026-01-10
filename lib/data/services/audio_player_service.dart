import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Audio Player Service using just_audio
/// Handles audio playback with Spotify-like features
class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Stream controllers for state updates
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  
  // Current audio source
  String? _currentAudioPath;

  AudioPlayerService() {
    _initialize();
  }

  void _initialize() {
    // Listen to position updates
    _audioPlayer.positionStream.listen((position) {
      _positionController.add(position);
    });

    // Listen to duration updates
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _durationController.add(duration);
      }
    });

    // Listen to buffered position
    _audioPlayer.bufferedPositionStream.listen((buffered) {
      _bufferedPositionController.add(buffered);
    });

    // Listen to player state
    _audioPlayer.playerStateStream.listen((state) {
      _playerStateController.add(state);
    });
  }

  /// Play audio from file path
  Future<void> playFromPath(String filePath) async {
    try {
      _currentAudioPath = filePath;
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio from path: $e');
      rethrow;
    }
  }

  /// Play audio from bytes (Uint8List)
  Future<void> playFromBytes(Uint8List audioBytes) async {
    try {
      // Save bytes to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes);
      
      _currentAudioPath = tempFile.path;
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio from bytes: $e');
      rethrow;
    }
  }

  /// Play audio from URL
  Future<void> playFromUrl(String url) async {
    try {
      _currentAudioPath = url;
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio from URL: $e');
      rethrow;
    }
  }

  /// Set audio source (for concatenating multiple sources)
  Future<void> setAudioSource(AudioSource source) async {
    try {
      await _audioPlayer.setAudioSource(source);
    } catch (e) {
      debugPrint('Error setting audio source: $e');
      rethrow;
    }
  }

  /// Play audio from asset
  Future<void> playFromAsset(String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio from asset: $e');
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  /// Resume playback
  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _currentAudioPath = null;
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Seek to specific position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  /// Set playback speed (0.25x to 2.0x)
  Future<void> setSpeed(double speed) async {
    try {
      // Clamp speed between 0.25 and 2.0
      final clampedSpeed = speed.clamp(0.25, 2.0);
      await _audioPlayer.setSpeed(clampedSpeed);
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(clampedVolume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  /// Get current position
  Duration get position => _audioPlayer.position;

  /// Get total duration
  Duration? get duration => _audioPlayer.duration;

  /// Get buffered position
  Duration get bufferedPosition => _audioPlayer.bufferedPosition;

  /// Get current playback state
  PlayerState get playerState => _audioPlayer.playerState;

  /// Check if playing
  bool get isPlaying => _audioPlayer.playing;

  /// Get playback speed
  double get speed => _audioPlayer.speed;

  /// Get volume
  double get volume => _audioPlayer.volume;

  /// Streams
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<Duration> get bufferedPositionStream => _bufferedPositionController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  /// Get current audio path/URL
  String? get currentAudioPath => _currentAudioPath;

  /// Dispose resources
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _playerStateController.close();
    await _audioPlayer.dispose();
  }
}

