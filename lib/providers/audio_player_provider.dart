import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/news_article.dart';
import '../data/services/elevenlabs_service.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/audio_background_service.dart';
import '../main.dart';

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

  // Playlist system for auto-play
  List<NewsArticle> _playlist = [];
  int _currentPlaylistIndex = -1;
  bool _playTitleMode = true; // true for home screen, false for detail screen
  bool _isAutoAdvancing = false; // Prevent duplicate auto-advance calls
  StreamSubscription<PlayerState>? _completionSubscription;

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
      // If position reaches duration, ensure completion state is set
      // This handles cases where position stream detects completion before state stream
      if (_duration > Duration.zero && position >= _duration) {
        _position = _duration; // Ensure position equals duration
        // Completion state will be handled by state subscription
      }
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

    // Listen to player state - handles all state updates including completion
    _stateSubscription = _audioPlayerService.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      
      // Handle completion state - ensure UI updates properly
      if (state.processingState == ProcessingState.completed && !state.playing) {
        _isPlaying = false;
        _isPaused = false;
        // Reset position to duration when completed to show progress bar at end
        if (_duration > Duration.zero && _position < _duration) {
          _position = _duration;
        }
        debugPrint('✅ Audio playback completed - UI state updated: isPlaying=$_isPlaying, position=${_position.inSeconds}s/${_duration.inSeconds}s');
        // Notify listeners immediately when completion is detected
        notifyListeners();
      } else {
        // Normal state updates (playing, paused, loading, etc.)
        _isPlaying = state.playing;
        _isPaused =
            state.processingState == ProcessingState.ready && !state.playing;
        
        // Notify listeners on state changes
        if (wasPlaying != _isPlaying) {
          notifyListeners();
        }
      }
    });

    // Listen for completion to auto-advance to next article (separate from state updates)
    _completionSubscription = _audioPlayerService.playerStateStream.listen((state) {
      // Check if audio has completed
      if (state.processingState == ProcessingState.completed && !state.playing) {
        // Ensure UI state is updated (already done in _stateSubscription, but ensure consistency)
        _isPlaying = false;
        _isPaused = false;
        if (_duration > Duration.zero && _position < _duration) {
          _position = _duration;
        }
        
        // Check if we have a playlist and should auto-advance
        if (_playlist.isNotEmpty &&
            _currentPlaylistIndex >= 0 &&
            _currentPlaylistIndex < _playlist.length - 1 &&
            !_isAutoAdvancing) {
          _isAutoAdvancing = true;
          debugPrint('🔄 Auto-advancing to next article in playlist...');
          // Small delay to ensure state is stable and UI has updated
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_playlist.isNotEmpty && _currentPlaylistIndex >= 0 && _isAutoAdvancing) {
              // Auto-advance to next article in playlist
              _playNextInPlaylist();
            }
            _isAutoAdvancing = false;
          });
        } else {
          // No playlist or last item - audio completed
          debugPrint('✅ Audio playback completed - no auto-advance needed (playlist: ${_playlist.length}, index: $_currentPlaylistIndex)');
          // Ensure state is properly updated for UI
          notifyListeners();
        }
      }
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
  List<NewsArticle> get playlist => List.unmodifiable(_playlist);
  int get currentPlaylistIndex => _currentPlaylistIndex;
  int get playlistLength => _playlist.length;

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

  /// Play article using ElevenLabs TTS (legacy method - kept for backward compatibility)
  Future<void> playArticle(NewsArticle article) async {
    // Check if article has audio URLs - if yes, use URL playback
    if (article.titleAudioUrl != null && article.titleAudioUrl!.isNotEmpty) {
      // Play from title audio URL (for home screen)
      await playArticleFromUrl(article, playTitle: true);
      return;
    }
    
    // Fallback to TTS generation if no audio URLs
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

      final audioBytes = await _elevenLabsService.textToSpeech(
        text: textToSpeak,
        voiceId: elevenLabsVoiceId,
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

  /// Set playlist and start playing from a specific article
  /// [articles] - list of articles to play sequentially
  /// [startIndex] - index to start playing from (default: 0)
  /// [playTitle] - if true, plays only title_audio_url (for home screen)
  /// if false, plays description_audio_url then content_audio_url (for detail screen)
  Future<void> setPlaylistAndPlay(
    List<NewsArticle> articles,
    int startIndex, {
    bool playTitle = true,
  }) async {
    if (articles.isEmpty) {
      debugPrint('⚠️ Cannot set empty playlist');
      return;
    }

    if (startIndex < 0 || startIndex >= articles.length) {
      debugPrint('⚠️ Invalid start index: $startIndex');
      return;
    }

    _playlist = List.from(articles);
    _currentPlaylistIndex = startIndex;
    _playTitleMode = playTitle;

    debugPrint('📋 Playlist set with ${_playlist.length} articles, starting at index $startIndex');
    
    // Start playing the article at startIndex
    await playArticleFromUrl(_playlist[startIndex], playTitle: playTitle);
  }

  /// Play article from audio URL(s)
  /// [playTitle] - if true, plays only title_audio_url (for home screen)
  /// if false, plays description_audio_url then content_audio_url (for detail screen)
  Future<void> playArticleFromUrl(
    NewsArticle article, {
    bool playTitle = false,
  }) async {
    try {
      // If same article is playing and same mode, just resume
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

      if (playTitle) {
        // Home screen: Play only title audio
        final titleUrl = article.titleAudioUrl;
        if (titleUrl == null || titleUrl.isEmpty) {
          throw Exception('Title audio URL not available');
        }

        debugPrint('🎵 Playing title audio from URL: $titleUrl');
        _isLoading = false;
        notifyListeners();

        await _audioPlayerService.playFromUrl(titleUrl);
      } else {
        // Detail screen: Play description then content sequentially
        final descriptionUrl = article.descriptionAudioUrl;
        final contentUrl = article.contentAudioUrl;

        if (descriptionUrl == null || descriptionUrl.isEmpty) {
          throw Exception('Description audio URL not available');
        }

        debugPrint('🎵 Playing description then content audio');
        _isLoading = false;
        notifyListeners();

        // Create a list of URLs to play sequentially
        final List<String> urlsToPlay = [descriptionUrl];
        if (contentUrl != null && contentUrl.isNotEmpty) {
          urlsToPlay.add(contentUrl);
        }

        // Play sequentially using concatenating audio source
        await _playSequentialUrls(urlsToPlay);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isPlaying = false;
      _currentArticle = null;
      debugPrint('❌ Error playing article from URL: $e');
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

  /// Stop playback and clear playlist
  Future<void> stop() async {
    try {
      await _audioPlayerService.stop();
      _isPlaying = false;
      _isPaused = false;
      _currentArticle = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _playlist.clear();
      _currentPlaylistIndex = -1;
      debugPrint('🛑 Playback stopped - UI state cleared');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
    }
  }

  /// Play next article in playlist (called automatically on completion)
  Future<void> _playNextInPlaylist() async {
    if (_playlist.isEmpty || _currentPlaylistIndex < 0) {
      _isAutoAdvancing = false;
      // Ensure state is updated when no playlist
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return;
    }

    final nextIndex = _currentPlaylistIndex + 1;
    if (nextIndex >= _playlist.length) {
      debugPrint('✅ Playlist completed - reached end');
      _isAutoAdvancing = false;
      // Playlist finished, ensure UI state is updated before stopping
      _isPlaying = false;
      _isPaused = false;
      if (_duration > Duration.zero) {
        _position = _duration;
      }
      notifyListeners();
      await stop();
      return;
    }

    debugPrint('⏭️ Auto-advancing to next article: ${nextIndex + 1}/${_playlist.length}');
    _currentPlaylistIndex = nextIndex;
    
    try {
      await playArticleFromUrl(_playlist[nextIndex], playTitle: _playTitleMode);
      _isAutoAdvancing = false;
    } catch (e) {
      debugPrint('❌ Error playing next article: $e');
      _isAutoAdvancing = false;
      // Ensure state is updated on error
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      // Try to continue with next article after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (_playlist.isNotEmpty && _currentPlaylistIndex < _playlist.length - 1) {
          _playNextInPlaylist();
        } else {
          // No more articles, ensure state is updated
          _isPlaying = false;
          _isPaused = false;
          notifyListeners();
        }
      });
    }
  }

  /// Skip to next article in playlist (manual skip)
  Future<void> skipToNext() async {
    await _playNextInPlaylist();
  }

  /// Skip to previous article in playlist
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty || _currentPlaylistIndex <= 0) {
      return;
    }

    final prevIndex = _currentPlaylistIndex - 1;
    debugPrint('⏮️ Skipping to previous article: ${prevIndex + 1}/${_playlist.length}');
    _currentPlaylistIndex = prevIndex;
    
    try {
      await playArticleFromUrl(_playlist[prevIndex], playTitle: _playTitleMode);
    } catch (e) {
      debugPrint('❌ Error playing previous article: $e');
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

  /// Play multiple audio URLs sequentially
  Future<void> _playSequentialUrls(List<String> urls) async {
    try {
      // Create concatenating audio source
      final List<AudioSource> audioSources = urls
          .map((url) => AudioSource.uri(Uri.parse(url)))
          .toList();

      final concatenatedSource = ConcatenatingAudioSource(
        children: audioSources,
      );

      // Set the concatenated source and play
      await _audioPlayerService.setAudioSource(concatenatedSource);
      await _audioPlayerService.play();
    } catch (e) {
      debugPrint('❌ Error playing sequential URLs: $e');
      rethrow;
    }
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
    _completionSubscription?.cancel();
    _audioPlayerService.dispose();
    super.dispose();
  }
}
