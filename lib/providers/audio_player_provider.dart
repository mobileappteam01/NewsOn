import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../data/models/news_article.dart';
import '../data/services/elevenlabs_service.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/audio_background_service.dart';
import '../data/services/background_music_service.dart';
import '../data/services/news_audio_cache_service.dart';
import '../data/services/storage_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/voice_features.dart';
import '../main.dart';

/// Audio Player Provider - Manages ElevenLabs audio playback with Spotify-like features
class AudioPlayerProvider with ChangeNotifier {
  final ElevenLabsService _elevenLabsService;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final BackgroundMusicService _backgroundMusicService =
      BackgroundMusicService();

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
  bool _hasCompleted = false; // Track if current audio has completed
  Timer? _autoAdvanceTimer; // Timer for delayed auto-advance (Spotify-like)
  int?
      _autoAdvanceFromIndex; // Store index when auto-advance timer was set (for validation)

  String _currentCategory = 'date';

  /// Callback when current audio finishes (for marking news as completed in Firestore).
  void Function(String newsId, String category)? onNewsCompleted;

  /// Invalidates in-flight background-music start chains (completion, switch, error).
  int _bgMusicGeneration = 0;

  // Stream subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  AudioPlayerProvider({String? elevenLabsApiKey})
      : _elevenLabsService = ElevenLabsService(apiKey: elevenLabsApiKey) {
    _initializeListeners();
    // Initialize background music service asynchronously
    _initializeBackgroundMusic();
    // Initialize background service callbacks asynchronously
    // Don't await - let it happen in the background to avoid blocking constructor
    _initializeBackgroundService().catchError((e) {
      debugPrint('⚠️ Background service callback setup failed: $e');
      // Non-critical - app can continue without notification callbacks
    });
  }

  /// Initialize background music service (waits for pre-init from main if in progress)
  Future<void> _initializeBackgroundMusic() async {
    try {
      debugPrint('🎵 Initializing background music service...');
      await _backgroundMusicService.ensureInitialized();
      debugPrint('✅ Background music service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize background music service: $e');
      // Continue without background music if initialization fails
    }
  }

  Future<void> _initializeBackgroundService() async {
    try {
      // AudioBackgroundService.init() is already called in main.dart
      // Wait for it to be ready (with retries)
      int attempts = 0;
      while (attempts < 10) {
        if (AudioBackgroundService.isInitialized &&
            AudioBackgroundService.handler != null) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 10));
        attempts++;
      }

      // Set up callbacks for notification controls (Previous/Next)
      final handler = AudioBackgroundService.handler;
      if (handler != null) {
        handler.onSkipToNext = () {
          debugPrint('⏭️ [Notification] Skip to next triggered');
          skipToNext();
        };
        handler.onSkipToPrevious = () {
          debugPrint('⏮️ [Notification] Skip to previous triggered');
          skipToPrevious();
        };

        // Listen to playback state changes from notification controls
        handler.playbackState.listen((state) {
          final isPlayingFromNotification = state.playing;
          final isPausedFromNotification = !state.playing &&
              state.processingState != AudioProcessingState.completed;

          // Sync UI state with notification state changes
          if (isPlayingFromNotification && !_isPlaying) {
            debugPrint('▶️ [Notification] Play detected - syncing UI state');
            if (_currentArticle != null) {
              _isPlaying = true;
              _isPaused = false;
              _hasCompleted = false;
              _syncBackgroundMusic();
              notifyListeners();
            }
          } else if (isPausedFromNotification && _isPlaying) {
            debugPrint('⏸️ [Notification] Pause detected - syncing UI state');
            _isPlaying = false;
            _isPaused = true;
            _pauseBackgroundMusic();
            notifyListeners();
          }
        });

        debugPrint('✅ Background service callbacks registered');
      } else {
        debugPrint(
          '⚠️ AudioBackgroundService handler is null after waiting - callbacks not registered',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to set up background service callbacks: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - app should continue without background service callbacks
    }
  }

  void _initializeListeners() {
    // Listen to position updates
    _positionSubscription = _audioPlayerService.positionStream.listen((
      position,
    ) {
      _position = position;

      // Log position every 10 seconds for debugging
      if (position.inSeconds > 0 &&
          position.inSeconds % 10 == 0 &&
          _isPlaying) {
        debugPrint(
          '📍 Position: ${position.inSeconds}s / ${_duration.inSeconds}s (isPlaying=$_isPlaying, hasCompleted=$_hasCompleted)',
        );
      }

      notifyListeners();
    });

    // Listen to duration updates
    // IMPORTANT: For ConcatenatingAudioSource, duration may update multiple times as each URL loads
    // The final duration will be the sum of all URLs, so we need to track duration updates
    _durationSubscription = _audioPlayerService.durationStream.listen((
      duration,
    ) {
      final previousDuration = _duration;
      _duration = duration;

      // Log duration updates for concatenated sources (helps debug)
      // Only log if duration actually increased (indicating more URLs loaded)
      if (duration > Duration.zero &&
          previousDuration > Duration.zero &&
          duration > previousDuration) {
        debugPrint(
          '📊 Duration updated: ${previousDuration.inSeconds}s → ${duration.inSeconds}s (concatenated source loading additional URLs)',
        );
      }

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
      final wasPaused = _isPaused;

      // Handle completion state - ensure UI updates properly
      if (state.processingState == ProcessingState.completed) {
        debugPrint('✅ [STATE] ProcessingState.completed detected');
        _handleAudioCompletion();
      } else if (state.processingState == ProcessingState.idle &&
          !state.playing) {
        // Handle idle state (stopped/completed but not explicitly stopped)
        if (_isPlaying || _isPaused) {
          _isPlaying = false;
          _isPaused = false;
          _hasCompleted = true; // Mark as completed if idle
          _stopBackgroundMusic();
          debugPrint(
            '🔄 Audio player idle - resetting state: isPlaying=$_isPlaying, isPaused=$_isPaused',
          );
          notifyListeners();
        }
      } else {
        // Normal state updates (playing, paused, loading, etc.)
        // CRITICAL: If we're in auto-advance mode (_isAutoAdvancing = true), ignore ALL state updates that might interfere
        // This prevents just_audio state stream from resetting completion flag after completion
        // The position/state stream already detected completion and set up the timer - don't let subsequent state updates interfere
        // We check _isAutoAdvancing first (which is set immediately) rather than waiting for timer to be created
        if (_isAutoAdvancing && _autoAdvanceFromIndex != null) {
          // We're in auto-advance delay period - ignore ALL state updates that might interfere
          // This prevents just_audio state stream from resetting completion flag after completion
          debugPrint(
            '⚠️ Ignoring state update during auto-advance delay: processingState=${state.processingState}, playing=${state.playing}, isAutoAdvancing=$_isAutoAdvancing, storedIndex=$_autoAdvanceFromIndex, hasCompleted=$_hasCompleted',
          );
          // Ensure state remains as completed (not playing, not paused) - don't let state stream change it
          // CRITICAL: Don't reset _hasCompleted here - let the timer handle auto-advance
          if (_isPlaying || (_isPaused && state.playing)) {
            _isPlaying = false;
            _isPaused = false;
            notifyListeners();
          }
          return; // Don't process this state update further - we're waiting for auto-advance
        } else if (state.playing &&
            _hasCompleted &&
            !_isAutoAdvancing &&
            state.processingState != ProcessingState.completed) {
          // Only reset completion flag when user actually resumed (player not in completed state).
          // Avoid treating spurious "playing" events right after last article completion as resume.
          _hasCompleted = false;
          _isPlaying = true;
          _isPaused = false;
          // Cancel any pending auto-advance timer when user manually resumes
          _autoAdvanceTimer?.cancel();
          _isAutoAdvancing = false;
          _autoAdvanceFromIndex = null;
          _syncBackgroundMusic();
          debugPrint(
            '🔄 Audio manually resumed after completion - resetting completion flag and cancelling auto-advance',
          );
          notifyListeners();
        } else if (_hasCompleted && !state.playing && !_isAutoAdvancing) {
          // Already completed and no auto-advance - ensure state remains false and BG is stopped
          if (_isPlaying || _isPaused) {
            _isPlaying = false;
            _isPaused = false;
            _stopBackgroundMusic();
            debugPrint(
              '⚠️ Preventing state reset after completion: isPlaying=$_isPlaying, isPaused=$_isPaused',
            );
            notifyListeners();
          }
        } else if (!_hasCompleted) {
          // Normal state update - not completed, process normally
          _isPlaying = state.playing;
          _isPaused =
              state.processingState == ProcessingState.ready && !state.playing;

          // Mirror BG to news: only while news is actively playing (not loading/completed/gap).
          if (wasPlaying != _isPlaying || wasPaused != _isPaused) {
            _syncBackgroundMusic();
          }

          // Notify listeners on state changes
          if (wasPlaying != _isPlaying || wasPaused != _isPaused) {
            debugPrint(
              '🔄 Audio state changed: isPlaying=$_isPlaying (was: $wasPlaying), isPaused=$_isPaused (was: $wasPaused), processingState=${state.processingState}',
            );
            notifyListeners();
          }
        }
        // If _hasCompleted is true and we're auto-advancing, we already handled it above with return
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
  bool get hasCompleted => _hasCompleted; // Expose completion state for UI
  List<NewsArticle> get playlist => List.unmodifiable(_playlist);
  int get currentPlaylistIndex => _currentPlaylistIndex;
  int get playlistLength => _playlist.length;
  bool get playTitleMode =>
      _playTitleMode; // Expose playTitleMode for detail page navigation check
  bool get isBackgroundMusicPlaying => _backgroundMusicService.isPlaying;

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
    if (!VoiceFeatures.isEnabled) return;

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
      _hasCompleted = false; // Reset completion flag when starting new audio
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

      // BG is started when player state transitions to playing (state listener)

      // Update background service with current article metadata
      try {
        final handler = AudioBackgroundService.handler;
        if (handler != null) {
          await handler.setCurrentArticle(article);
        }
      } catch (e) {
        debugPrint('Failed to update background service: $e');
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
  /// [playTitle] - if true, uses stored news reading preference (for home screen/list views)
  /// if false, plays only description_audio_url (for detail screen)
  Future<void> setPlaylistAndPlay(
    List<NewsArticle> articles,
    int startIndex, {
    bool playTitle = true,
    String category = 'date',
  }) async {
    if (!VoiceFeatures.isEnabled) return;

    if (articles.isEmpty) {
      debugPrint('⚠️ Cannot set empty playlist');
      return;
    }

    if (startIndex < 0 || startIndex >= articles.length) {
      debugPrint('⚠️ Invalid start index: $startIndex');
      return;
    }

    // Cancel any existing auto-advance timer when starting new playlist
    _autoAdvanceTimer?.cancel();
    _isAutoAdvancing = false;
    _autoAdvanceFromIndex = null;
    _hasCompleted = false;

    _playlist = List.from(articles);
    _currentPlaylistIndex = startIndex;
    _playTitleMode = playTitle;
    _currentCategory = category;

    debugPrint(
      '📋 Playlist set with ${_playlist.length} articles, starting at index $startIndex (mode: ${playTitle ? "list view" : "detail view"})',
    );

    unawaited(
      NewsAudioCacheService.instance.prefetchPlaylist(
        _playlist,
        playTitle: playTitle,
      ),
    );

    // Start playing the article at startIndex
    await playArticleFromUrl(_playlist[startIndex],
        playTitle: playTitle, category: category);
  }

  /// Play article from audio URL(s)
  /// [playTitle] - if true, uses stored news reading preference (for home screen/list views)
  /// if false, plays only description_audio_url (for detail screen)
  /// [forceMode] - optional parameter to override stored preference
  Future<void> playArticleFromUrl(
    NewsArticle article, {
    bool playTitle = false,
    String? forceMode,
    String category = 'date',
  }) async {
    if (!VoiceFeatures.isEnabled) return;

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

      // Stop current playback and background music before starting new audio
      await _stopBackgroundMusic();

      if (_audioPlayerService.isPlaying || _isPaused || _hasCompleted) {
        debugPrint(
          '🛑 Stopping current playback before starting new article...',
        );
        await _audioPlayerService.stop();
        // Wait a bit for stop to complete
        await Future.delayed(const Duration(milliseconds: 150));
      }

      _isLoading = true;
      _error = null;
      _currentArticle = article;
      _currentCategory = category;
      _hasCompleted = false; // Reset completion flag when starting new audio
      _isAutoAdvancing =
          false; // Reset auto-advance flag when starting new audio
      _autoAdvanceFromIndex = null; // Clear stored index
      _autoAdvanceTimer?.cancel(); // Cancel any pending auto-advance timer

      // IMPORTANT: Update background service metadata BEFORE starting playback
      // This ensures the notification shows the correct article immediately
      _updateBackgroundServiceMetadata(article);

      notifyListeners();

      final readingMode = forceMode ?? StorageService.getNewsReadingMode();
      final urlsToPlay = NewsAudioCacheService.playbackUrlsForArticle(
        article,
        playTitle: playTitle,
        readingMode: readingMode,
      );

      debugPrint('🎧 ========== AUDIO PLAYBACK MODE ==========');
      debugPrint('🎧 Reading Mode: "$readingMode" | playTitle: $playTitle');
      debugPrint('🎧 URLs to play: ${urlsToPlay.length}');

      if (urlsToPlay.isEmpty) {
        throw Exception(
          playTitle
              ? 'No audio available for this article. It may still be generating on the server.'
              : 'No audio URL available (content or description)',
        );
      }

      _isLoading = false;
      notifyListeners();

      if (urlsToPlay.length == 1) {
        await _audioPlayerService.playFromUrl(urlsToPlay[0]);
      } else {
        await _playSequentialUrls(urlsToPlay);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isPlaying = false;
      _isPaused = false;
      _hasCompleted = false; // Reset completion flag on error
      _currentArticle = null;
      await _stopBackgroundMusic();
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

  /// Update background service with article metadata for notification
  void _updateBackgroundServiceMetadata(NewsArticle article) {
    try {
      final handler = AudioBackgroundService.handler;
      if (handler != null) {
        handler.setCurrentArticle(article);
        debugPrint('🎵 Background service metadata updated: ${article.title}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update background service metadata: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      // Cancel any pending auto-advance timer when user manually pauses
      _autoAdvanceTimer?.cancel();
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;

      await _audioPlayerService.pause();

      await _pauseBackgroundMusic();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      // If we're resuming after completion, reset the completion flag
      if (_hasCompleted) {
        _hasCompleted = false;
        debugPrint('🔄 Resuming after completion - resetting completion flag');
      }
      await _audioPlayerService.play();

      await _resumeBackgroundMusic();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Stop playback and clear playlist
  Future<void> stop() async {
    try {
      // Cancel any pending auto-advance timer
      _autoAdvanceTimer?.cancel();
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;

      await _audioPlayerService.stop();

      await _stopBackgroundMusic();

      _isPlaying = false;
      _isPaused = false;
      _hasCompleted = false; // Reset completion flag
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
      _hasCompleted = false;
      _autoAdvanceTimer?.cancel();
      _isAutoAdvancing = false;
      notifyListeners();
    }
  }

  /// Handle audio completion - update UI and trigger auto-advance if needed
  void _handleAudioCompletion() {
    // Prevent duplicate handling
    if (_hasCompleted) {
      debugPrint('ℹ️ Audio completion already handled - skipping');
      return;
    }

    // Force state to completed (not playing, not paused)
    _isPlaying = false;
    _isPaused = false;
    _hasCompleted = true;

    // Reset position to duration when completed
    if (_duration > Duration.zero && _position < _duration) {
      _position = _duration;
    }

    debugPrint(
      '✅ Audio completed - isPlaying=$_isPlaying, playlist=${_playlist.length}, index=$_currentPlaylistIndex',
    );

    // Stop background music when news completes (BG mirrors news)
    _stopBackgroundMusic();

    // Notify completed-news so UI can show green tick and Firestore can persist
    final article = _currentArticle;
    if (article != null && onNewsCompleted != null) {
      final newsId = article.articleId ?? article.title;
      onNewsCompleted!(newsId, _currentCategory);
    }

    // Notify listeners immediately to update UI (pause icon → play icon)
    notifyListeners();

    // Check if we should auto-advance
    final shouldAutoAdvance = _playlist.isNotEmpty &&
        _currentPlaylistIndex >= 0 &&
        _currentPlaylistIndex < _playlist.length - 1 &&
        !_isAutoAdvancing;

    if (shouldAutoAdvance) {
      _isAutoAdvancing = true;
      _autoAdvanceFromIndex = _currentPlaylistIndex;

      debugPrint(
        '⏳ Will auto-advance to next article in ${AppConstants.autoAdvanceDelaySeconds} seconds...',
      );

      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(
        Duration(seconds: AppConstants.autoAdvanceDelaySeconds),
        () {
          if (_playlist.isNotEmpty &&
              _currentPlaylistIndex >= 0 &&
              _currentPlaylistIndex < _playlist.length - 1 &&
              _currentPlaylistIndex == _autoAdvanceFromIndex &&
              _isAutoAdvancing) {
            debugPrint('🔄 Auto-advancing to next article...');
            _autoAdvanceFromIndex = null;
            _playNextInPlaylist();
          } else {
            _isAutoAdvancing = false;
            _autoAdvanceFromIndex = null;
            debugPrint('⚠️ Auto-advance cancelled - conditions changed');
          }
        },
      );
    } else {
      debugPrint(
        '✅ No auto-advance needed (playlist: ${_playlist.length}, index: $_currentPlaylistIndex)',
      );
      _autoAdvanceTimer?.cancel();
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      // Last article completed: ensure BG is stopped (no next news)
      _stopBackgroundMusic();
    }
  }

  /// Play next article in playlist (called automatically on completion with Spotify-like delay)
  Future<void> _playNextInPlaylist() async {
    // Cancel any existing auto-advance timer before playing next
    _autoAdvanceTimer?.cancel();
    _autoAdvanceFromIndex = null;

    if (_playlist.isEmpty) {
      debugPrint('⚠️ Cannot auto-advance: playlist is empty');
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      // Ensure state is updated when no playlist
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return;
    }

    // Validate current index
    if (_currentPlaylistIndex < 0 ||
        _currentPlaylistIndex >= _playlist.length) {
      debugPrint(
        '⚠️ Cannot auto-advance: invalid current index ($_currentPlaylistIndex) for playlist length (${_playlist.length})',
      );
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return;
    }

    final nextIndex = _currentPlaylistIndex + 1;
    if (nextIndex >= _playlist.length) {
      debugPrint(
        '✅ Playlist completed - reached end (current index: $_currentPlaylistIndex, playlist length: ${_playlist.length})',
      );
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
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

    // Validate next index before accessing
    if (nextIndex < 0 || nextIndex >= _playlist.length) {
      debugPrint(
        '❌ Cannot auto-advance: invalid next index ($nextIndex) for playlist length (${_playlist.length})',
      );
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return;
    }

    debugPrint(
      '⏭️ Auto-advancing to next article: ${nextIndex + 1}/${_playlist.length}',
    );

    // Ensure BG stays off during the gap until the next article is actually playing.
    await _stopBackgroundMusic();

    try {
      // CRITICAL: Get the next article BEFORE updating index to avoid race conditions
      // Validate that nextIndex is valid one more time before accessing
      if (nextIndex < 0 || nextIndex >= _playlist.length) {
        debugPrint(
          '❌ Cannot auto-advance: invalid next index ($nextIndex) for playlist length (${_playlist.length}) after validation',
        );
        _isAutoAdvancing = false;
        _autoAdvanceFromIndex = null;
        _isPlaying = false;
        _isPaused = false;
        notifyListeners();
        return;
      }

      // Get the next article
      final nextArticle = _playlist[nextIndex];

      // Update index AFTER getting the article (safer)
      _currentPlaylistIndex = nextIndex;

      // Reset auto-advance flag before starting new audio (will be set again when this audio completes)
      _isAutoAdvancing = false;
      // Reset completion flag since we're starting new audio
      _hasCompleted = false;

      // CRITICAL: Reset position and duration for progress bar
      _position = Duration.zero;
      _duration = Duration.zero;
      debugPrint('🔄 Progress bar reset: position=0s, duration=0s');

      // IMPORTANT: Clear current article BEFORE calling playArticleFromUrl
      // This prevents the "same article" check from returning early
      _currentArticle = null;

      // Notify listeners to update UI
      notifyListeners();

      // Play next article using the same reading mode
      await playArticleFromUrl(nextArticle,
          playTitle: _playTitleMode, category: _currentCategory);

      debugPrint('✅ Next article started playing: ${nextArticle.title}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error playing next article: $e');
      debugPrint('Stack trace: $stackTrace');
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      // Ensure state is updated on error
      _isPlaying = false;
      _isPaused = false;
      _hasCompleted = false;
      notifyListeners();

      // Try to continue with next article after a delay (only if still valid)
      Future.delayed(const Duration(seconds: 2), () {
        if (_playlist.isNotEmpty &&
            _currentPlaylistIndex >= 0 &&
            _currentPlaylistIndex < _playlist.length - 1) {
          _playNextInPlaylist();
        } else {
          // No more articles, ensure state is updated
          debugPrint(
            '⚠️ Cannot retry auto-advance: playlist empty or invalid index',
          );
          _isPlaying = false;
          _isPaused = false;
          _hasCompleted = true;
          notifyListeners();
        }
      });
    }
  }

  /// Skip to next article in playlist (manual skip)
  Future<void> skipToNext() async {
    // Cancel any pending auto-advance timer when user manually skips
    _autoAdvanceTimer?.cancel();
    _isAutoAdvancing = false;
    _autoAdvanceFromIndex = null;
    await _playNextInPlaylist();
  }

  /// Skip to previous article in playlist
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty || _currentPlaylistIndex <= 0) {
      return;
    }

    // Cancel any pending auto-advance timer when user manually skips
    _autoAdvanceTimer?.cancel();
    _isAutoAdvancing = false;
    _autoAdvanceFromIndex = null;

    final prevIndex = _currentPlaylistIndex - 1;
    debugPrint(
      '⏮️ Skipping to previous article: ${prevIndex + 1}/${_playlist.length}',
    );
    _currentPlaylistIndex = prevIndex;

    try {
      await playArticleFromUrl(_playlist[prevIndex],
          playTitle: _playTitleMode, category: _currentCategory);
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

  /// Set background music volume (0.0–1.0) and persist to settings
  Future<void> setBackgroundMusicVolume(double volume) async {
    try {
      final clamped = volume.clamp(0.0, 1.0);
      await _backgroundMusicService.setVolume(clamped);
      await StorageService.saveBackgroundMusicVolume(clamped);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get background music volume
  double get backgroundMusicVolume => _backgroundMusicService.volume;

  /// Check if background music is initialized
  bool get isBackgroundMusicInitialized =>
      _backgroundMusicService.isInitialized;

  /// Dispose background music service separately
  void disposeBackgroundMusic() {
    if (_backgroundMusicService.isPlaying) {
      debugPrint('🗑️ Disposing background music service');
      _stopBackgroundMusic();
      _backgroundMusicService.dispose();
    }
  }

  /// True only while news audio is actively playing (not gap between articles).
  bool _shouldBackgroundMusicPlay() {
    return _currentArticle != null &&
        _isPlaying &&
        !_isPaused &&
        !_hasCompleted &&
        !_isAutoAdvancing &&
        !_isLoading &&
        StorageService.getBackgroundMusicEnabled();
  }

  void _invalidateBackgroundMusicStarts() {
    _bgMusicGeneration++;
  }

  Future<void> _stopBackgroundMusic() async {
    _invalidateBackgroundMusicStarts();
    await _backgroundMusicService.stop();
  }

  Future<void> _pauseBackgroundMusic() async {
    await _backgroundMusicService.pause();
  }

  Future<void> _resumeBackgroundMusic() async {
    if (_currentArticle == null || _hasCompleted || _isAutoAdvancing) return;
    if (!StorageService.getBackgroundMusicEnabled()) return;
    await _backgroundMusicService.resume();
  }

  /// Keep background music in sync with news: play / pause / stop.
  void _syncBackgroundMusic() {
    if (_shouldBackgroundMusicPlay()) {
      _startBackgroundMusicWhenPlaying();
    } else if (_isPaused &&
        _currentArticle != null &&
        !_hasCompleted &&
        !_isAutoAdvancing) {
      _pauseBackgroundMusic();
    } else {
      _stopBackgroundMusic();
    }
  }

  /// Start background music when news is playing. Only starts if user has enabled BG in settings.
  /// BG mirrors news: play with news, pause with news, stop with news.
  void _startBackgroundMusicWhenPlaying() {
    if (!_shouldBackgroundMusicPlay()) return;

    final token = _bgMusicGeneration;
    final volume = StorageService.getBackgroundMusicVolume();
    unawaited(_runBackgroundMusicStart(token, volume));
  }

  Future<void> _runBackgroundMusicStart(int token, double volume) async {
    try {
      await _backgroundMusicService.ensureInitialized();
      if (token != _bgMusicGeneration || !_shouldBackgroundMusicPlay()) {
        return;
      }
      await _backgroundMusicService.setVolume(volume);
      if (token != _bgMusicGeneration || !_shouldBackgroundMusicPlay()) {
        return;
      }
      await _backgroundMusicService.startOrResume();
      if (token != _bgMusicGeneration || !_shouldBackgroundMusicPlay()) {
        await _backgroundMusicService.stop();
        return;
      }
      debugPrint('✅ Background music started (in parallel with news)');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Background music start failed: $e');
    }
  }

  /// Check if specific article is currently playing
  bool isArticlePlaying(NewsArticle article) {
    if (_currentArticle == null) return false;

    final currentKey = _currentArticle!.articleId ?? _currentArticle!.title;
    final articleKey = article.articleId ?? article.title;
    return currentKey == articleKey && _isPlaying;
  }

  /// Play multiple audio URLs sequentially using ConcatenatingAudioSource
  Future<void> _playSequentialUrls(List<String> urls) async {
    try {
      if (urls.isEmpty) {
        throw Exception('No URLs provided for sequential playback');
      }

      // Filter out empty URLs
      final validUrls = urls.where((url) => url.isNotEmpty).toList();

      if (validUrls.isEmpty) {
        throw Exception('No valid URLs found for sequential playback');
      }

      debugPrint(
        '🎵 Setting up sequential playback with ${validUrls.length} URLs',
      );

      // Create AudioSource URIs for each URL
      final List<AudioSource> audioSources = [];
      for (final url in validUrls) {
        debugPrint('🎵 Creating AudioSource for: $url');
        audioSources.add(await _audioPlayerService.resolveNewsAudioSource(url));
      }

      // Create ConcatenatingAudioSource which will play URLs sequentially
      final concatenatedSource = ConcatenatingAudioSource(
        children: audioSources,
      );

      debugPrint(
        '🎵 Created ConcatenatingAudioSource with ${audioSources.length} sources',
      );

      // IMPORTANT: ConcatenatingAudioSource requires the player to be stopped first
      // Stop current playback to ensure clean state
      if (_audioPlayerService.isPlaying) {
        await _audioPlayerService.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Set the concatenated source - this will load all URLs
      // ConcatenatingAudioSource automatically plays them sequentially
      await _audioPlayerService.setAudioSource(concatenatedSource);
      debugPrint('🎵 Concatenated source set - starting playback immediately');

      // IMPORTANT: For ConcatenatingAudioSource, don't wait for duration to be accurate
      // Duration initially reports only the first URL's duration, then updates as more URLs load
      // The duration stream will update automatically as each URL loads
      // ProcessingState.completed will fire when ALL URLs are done, not when position reaches duration
      // So we can start playing immediately without waiting for duration

      // Play immediately - ConcatenatingAudioSource will automatically load and play each URL in sequence
      // Duration will update in the background as URLs load, but we don't need to wait for it
      await _audioPlayerService.play();
      debugPrint(
        '🎵 Started playing concatenated source - will play ${validUrls.length} URLs sequentially (duration updates automatically as URLs load)',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error playing sequential URLs: $e');
      debugPrint('Stack trace: $stackTrace');
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

  /// Refresh state to ensure UI synchronization after lifecycle changes
  void refreshState() {
    // Force notify listeners to update UI with current state
    notifyListeners();

    // Log current state for debugging
    debugPrint(
        '🔄 Audio state refreshed - Playing: $_isPlaying, Paused: $_isPaused, Position: ${_position.inSeconds}s, Duration: ${_duration.inSeconds}s');

    // Ensure background service metadata is up to date
    _updateBackgroundMetadata();
  }

  /// Update background service metadata to ensure notification consistency
  void _updateBackgroundMetadata() {
    final handler = AudioBackgroundService.handler;
    if (handler != null && _currentArticle != null) {
      // Update media item with current state
      final mediaItem = MediaItem(
        id: _currentArticle!.articleId ?? _currentArticle!.title ?? 'unknown',
        title: _currentArticle!.title ?? 'Unknown Article',
        artist: 'NewsOn',
        album: 'News Audio',
        duration: _duration,
        artUri: _currentArticle!.imageUrl?.isNotEmpty == true
            ? Uri.parse(_currentArticle!.imageUrl!)
            : null,
      );

      handler.mediaItem.add(mediaItem);
      debugPrint('🔄 Background metadata updated');
    }
  }

  @override
  void dispose() {
    // Cancel any pending auto-advance timer
    _autoAdvanceTimer?.cancel();
    _isAutoAdvancing = false;
    _autoAdvanceFromIndex = null;
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferedSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioPlayerService.dispose();
    _backgroundMusicService.dispose();
    super.dispose();
  }
}
