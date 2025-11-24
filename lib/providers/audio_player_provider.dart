import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/news_article.dart';
import '../data/services/elevenlabs_service.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/audio_background_service.dart';

/// Audio Player Provider - Manages ElevenLabs audio playback with Spotify-like features
class AudioPlayerProvider with ChangeNotifier {
  final ElevenLabsService _elevenLabsService;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  // State
  NewsArticle? _currentArticle;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  String? _error;

  // Stream subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  AudioPlayerProvider({String? elevenLabsApiKey})
    : _elevenLabsService = ElevenLabsService(apiKey: elevenLabsApiKey) {
    _initializeListeners();
    _initializeBackgroundService();
  }

  Future<void> _initializeBackgroundService() async {
    try {
      await AudioBackgroundService.init();
    } catch (e) {
      debugPrint('Failed to initialize background audio service: $e');
    }
  }

  void _initializeListeners() {
    // Listen to position updates
    _positionSubscription = _audioPlayerService.positionStream.listen((
      position,
    ) {
      _position = position;
      notifyListeners();
    });

    // Listen to duration updates
    _durationSubscription = _audioPlayerService.durationStream.listen((
      duration,
    ) {
      _duration = duration;
      notifyListeners();
    });

    // Listen to buffered position
    _bufferedSubscription = _audioPlayerService.bufferedPositionStream.listen((
      buffered,
    ) {
      _bufferedPosition = buffered;
      notifyListeners();
    });

    // Listen to player state
    _stateSubscription = _audioPlayerService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isPaused =
          state.processingState == ProcessingState.ready && !state.playing;
      notifyListeners();
    });
  }

  // Getters
  NewsArticle? get currentArticle => _currentArticle;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  double get playbackSpeed => _playbackSpeed;
  double get volume => _volume;
  String? get error => _error;
  bool get hasCurrentArticle => _currentArticle != null;

  /// Set ElevenLabs API key
  void setApiKey(String apiKey) {
    _elevenLabsService.setApiKey(apiKey);
    debugPrint(
      '✅ ElevenLabs API key set in provider: ${apiKey.isNotEmpty ? "Key set (${apiKey.length} chars)" : "Empty"}',
    );
  }

  /// Set voice ID
  void setVoiceId(String voiceId) {
    _elevenLabsService.setVoiceId(voiceId);
  }

  /// Play article using ElevenLabs TTS
  Future<void> playArticle(NewsArticle article) async {
    try {
      // If same article is playing, just resume
      if (_currentArticle != null &&
          (_currentArticle!.articleId ?? _currentArticle!.title) ==
              (article.articleId ?? article.title)) {
        if (_isPaused) {
          await resume();
        }
        return;
      }

      _isLoading = true;
      _error = null;
      _currentArticle = article;
      notifyListeners();

      // Prepare text for speech
      final textToSpeak = _prepareTextForSpeech(article);

      debugPrint('🎵 Preparing to play article: ${article.title}');
      debugPrint('📝 Text length: ${textToSpeak.length} characters');

      // Generate audio using ElevenLabs
      final audioBytes = await _elevenLabsService.textToSpeech(
        text: textToSpeak,
        stability: 0.5,
        similarityBoost: 0.75,
        style: 0.0,
        useSpeakerBoost: true,
      );

      // Audio generated successfully - hide loader immediately
      debugPrint('✅ Audio generated successfully (${audioBytes.length} bytes)');
      _isLoading = false;
      notifyListeners(); // Update UI to hide loader

      // Play the generated audio
      debugPrint('▶️ Starting playback...');
      await _audioPlayerService.playFromBytes(audioBytes);

      // Also play in background service for notification controls
      try {
        final handler = AudioBackgroundService.handler;
        if (handler != null && handler is NewsAudioHandler) {
          await handler.playArticle(article, audioBytes);
        }
      } catch (e) {
        debugPrint('Failed to start background service: $e');
        // Continue with regular playback even if background service fails
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isPlaying = false;
      _currentArticle = null;
      debugPrint('❌ Error playing article: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      notifyListeners();
      rethrow;
    }
  }

  /// Prepare article text for speech
  String _prepareTextForSpeech(NewsArticle article) {
    final buffer = StringBuffer();

    // Add title
    buffer.write(article.title);
    buffer.write('. ');

    // // Add author if available
    // if (article.creator != null && article.creator!.isNotEmpty) {
    //   buffer.write('By ${article.creator!.first}. ');
    // }

    // // Add description or content
    // if (article.content != null && article.content!.isNotEmpty) {
    //   buffer.write(article.content);
    // } else if (article.description != null && article.description!.isNotEmpty) {
    //   buffer.write(article.description);
    // }

    return buffer.toString();
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _audioPlayerService.pause();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _audioPlayerService.play();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _audioPlayerService.stop();
      _currentArticle = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else if (_isPaused || _currentArticle != null) {
      await resume();
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayerService.seek(position);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      _playbackSpeed = speed.clamp(0.25, 2.0);
      await _audioPlayerService.setSpeed(_playbackSpeed);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayerService.setVolume(_volume);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Check if specific article is currently playing
  bool isArticlePlaying(NewsArticle article) {
    if (_currentArticle == null) return false;

    final currentKey = _currentArticle!.articleId ?? _currentArticle!.title;
    final articleKey = article.articleId ?? article.title;
    return currentKey == articleKey && _isPlaying;
  }

  /// Format duration to MM:SS
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferedSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioPlayerService.dispose();
    super.dispose();
  }
}
