import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/news_article.dart';
import '../data/services/elevenlabs_service.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/audio_background_service.dart';
import '../data/services/storage_service.dart';
import '../core/constants/app_constants.dart';
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
  bool _hasCompleted = false; // Track if current audio has completed
  Timer? _autoAdvanceTimer; // Timer for delayed auto-advance (Spotify-like)
  int? _autoAdvanceFromIndex; // Store index when auto-advance timer was set (for validation)

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
      
      // IMPORTANT: For concatenated sources (multiple URLs), duration initially reports only the first URL's duration
      // We should NOT detect completion based on position reaching duration for concatenated sources
      // Instead, ONLY rely on the state stream's ProcessingState.completed which properly detects when ALL URLs are done
      // The position stream should ONLY be used for updating the progress bar UI, not for completion detection
      
      // For single URLs, duration is accurate from the start
      // For concatenated sources, duration updates as more URLs load, but we can't reliably detect completion from position
      // So we disable position-based completion detection entirely and rely only on ProcessingState.completed
      
      // Just update the position and notify listeners for UI updates (progress bar)
      // Completion detection is handled by the state stream below
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
        debugPrint('📊 Duration updated: ${previousDuration.inSeconds}s → ${duration.inSeconds}s (concatenated source loading additional URLs)');
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
      // IMPORTANT: ProcessingState.completed is the ONLY reliable way to detect completion for concatenated sources
      // This fires when ALL URLs in a ConcatenatingAudioSource have finished playing
      if (state.processingState == ProcessingState.completed && !state.playing) {
        // Force state to completed (not playing, not paused)
        _isPlaying = false;
        _isPaused = false;
        _hasCompleted = true; // Mark as completed
        
        // IMPORTANT: Don't clear _currentArticle here - keep it so audio player bar stays visible during auto-advance delay
        // Only clear _currentArticle when stopping or starting new article
        
        // Reset position to duration when completed to show progress bar at end
        if (_duration > Duration.zero && _position < _duration) {
          _position = _duration;
        }
        debugPrint('✅ Audio playback completed (ALL URLs finished) - UI state updated: isPlaying=$_isPlaying, isPaused=$_isPaused, position=${_position.inSeconds}s/${_duration.inSeconds}s, currentArticle=${_currentArticle?.title}');
        
        // Notify listeners immediately to update UI (pause icon → play icon)
        // This ensures UI updates instantly when audio completes (like Spotify)
        // Audio player bar should remain visible because _currentArticle is still set
        notifyListeners();
        
        // Check if we have a playlist and should auto-advance
        final shouldAutoAdvance = _playlist.isNotEmpty &&
            _currentPlaylistIndex >= 0 &&
            _currentPlaylistIndex < _playlist.length - 1 &&
            !_isAutoAdvancing;
        
        if (shouldAutoAdvance) {
          // Only set up auto-advance timer if not already advancing (avoid duplicate timers)
          // This prevents restarting the delay if both position and state streams detect completion
          if (!_isAutoAdvancing) {
            _isAutoAdvancing = true;
            debugPrint('✅ Audio completed - UI updated to play icon. Will auto-advance to next article in ${AppConstants.autoAdvanceDelaySeconds} seconds...');
            
            // Cancel any existing auto-advance timer (safety check - in case timer exists but flag wasn't set)
            _autoAdvanceTimer?.cancel();
            
            // CRITICAL: Store the index when auto-advance timer is set
            // This ensures we can validate that we're still on the same article when timer fires
            _autoAdvanceFromIndex = _currentPlaylistIndex;
            
            // Spotify-like delay: Show play icon first, then auto-advance after delay
            _autoAdvanceTimer = Timer(Duration(seconds: AppConstants.autoAdvanceDelaySeconds), () {
              // Double-check conditions before auto-advancing (in case user stopped or changed playlist)
              // Note: We don't check _hasCompleted here because state stream might have reset it
              // Instead, we check if we're still in the same position in the playlist
              if (_playlist.isNotEmpty && 
                  _currentPlaylistIndex >= 0 && 
                  _currentPlaylistIndex < _playlist.length - 1 &&
                  _currentPlaylistIndex == _autoAdvanceFromIndex &&
                  _isAutoAdvancing) {
                debugPrint('🔄 Auto-advancing to next article in playlist (Spotify-like ${AppConstants.autoAdvanceDelaySeconds}s delay)...');
                _autoAdvanceFromIndex = null; // Clear stored index before advancing
                // Auto-advance to next article in playlist
                _playNextInPlaylist();
              } else {
                // Conditions changed, cancel auto-advance
                _isAutoAdvancing = false;
                _autoAdvanceFromIndex = null;
                debugPrint('⚠️ Auto-advance cancelled - conditions changed (playlist: ${_playlist.length}, index: $_currentPlaylistIndex, storedIndex: $_autoAdvanceFromIndex, autoAdvancing: $_isAutoAdvancing)');
              }
            });
          } else {
            debugPrint('ℹ️ Auto-advance already in progress - skipping duplicate setup');
          }
        } else {
          // No playlist or last item - audio completed, state is properly reset
          debugPrint('✅ Audio playback completed - no auto-advance needed (playlist: ${_playlist.length}, index: $_currentPlaylistIndex)');
          // Cancel any existing timer (in case it was set up by position stream)
          _autoAdvanceTimer?.cancel();
          _isAutoAdvancing = false;
          _autoAdvanceFromIndex = null;
        }
      } else if (state.processingState == ProcessingState.idle && !state.playing) {
        // Handle idle state (stopped/completed but not explicitly stopped)
        if (_isPlaying || _isPaused) {
          _isPlaying = false;
          _isPaused = false;
          _hasCompleted = true; // Mark as completed if idle
          debugPrint('🔄 Audio player idle - resetting state: isPlaying=$_isPlaying, isPaused=$_isPaused');
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
          debugPrint('⚠️ Ignoring state update during auto-advance delay: processingState=${state.processingState}, playing=${state.playing}, isAutoAdvancing=$_isAutoAdvancing, storedIndex=$_autoAdvanceFromIndex, hasCompleted=$_hasCompleted');
          // Ensure state remains as completed (not playing, not paused) - don't let state stream change it
          // CRITICAL: Don't reset _hasCompleted here - let the timer handle auto-advance
          if (_isPlaying || (_isPaused && state.playing)) {
            _isPlaying = false;
            _isPaused = false;
            notifyListeners();
          }
          return; // Don't process this state update further - we're waiting for auto-advance
        } else if (state.playing && _hasCompleted && !_isAutoAdvancing) {
          // Only reset completion flag if we're actually starting new playback (not during auto-advance delay)
          // This handles manual resume after completion (user taps play button)
          _hasCompleted = false;
          _isPlaying = true;
          _isPaused = false;
          // Cancel any pending auto-advance timer when user manually resumes
          _autoAdvanceTimer?.cancel();
          _isAutoAdvancing = false;
          _autoAdvanceFromIndex = null;
          debugPrint('🔄 Audio manually resumed after completion - resetting completion flag and cancelling auto-advance');
          notifyListeners();
        } else if (_hasCompleted && !state.playing && !_isAutoAdvancing) {
          // Already completed and no auto-advance - ensure state remains false
          if (_isPlaying || _isPaused) {
            _isPlaying = false;
            _isPaused = false;
            debugPrint('⚠️ Preventing state reset after completion: isPlaying=$_isPlaying, isPaused=$_isPaused');
            notifyListeners();
          }
        } else if (!_hasCompleted) {
          // Normal state update - not completed, process normally
          _isPlaying = state.playing;
          _isPaused =
              state.processingState == ProcessingState.ready && !state.playing;
          
          // Notify listeners on state changes
          if (wasPlaying != _isPlaying || wasPaused != _isPaused) {
            debugPrint('🔄 Audio state changed: isPlaying=$_isPlaying (was: $wasPlaying), isPaused=$_isPaused (was: $wasPaused), processingState=${state.processingState}');
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
  bool get playTitleMode => _playTitleMode; // Expose playTitleMode for detail page navigation check

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
  /// [playTitle] - if true, uses stored news reading preference (for home screen/list views)
  /// if false, plays only description_audio_url (for detail screen)
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

    // Cancel any existing auto-advance timer when starting new playlist
    _autoAdvanceTimer?.cancel();
    _isAutoAdvancing = false;
    _autoAdvanceFromIndex = null;
    _hasCompleted = false;

    _playlist = List.from(articles);
    _currentPlaylistIndex = startIndex;
    _playTitleMode = playTitle;

    debugPrint('📋 Playlist set with ${_playlist.length} articles, starting at index $startIndex (mode: ${playTitle ? "list view" : "detail view"})');
    
    // Start playing the article at startIndex
    await playArticleFromUrl(_playlist[startIndex], playTitle: playTitle);
  }

  /// Play article from audio URL(s)
  /// [playTitle] - if true, uses stored news reading preference (for home screen/list views)
  /// if false, plays only description_audio_url (for detail screen)
  /// [forceMode] - optional parameter to override stored preference
  Future<void> playArticleFromUrl(
    NewsArticle article, {
    bool playTitle = false,
    String? forceMode,
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

      // Stop current playback before starting new audio (important for concatenated sources)
      // This ensures clean state transition when switching articles
      if (_audioPlayerService.isPlaying || _isPaused || _hasCompleted) {
        debugPrint('🛑 Stopping current playback before starting new article...');
        await _audioPlayerService.stop();
        // Wait a bit for stop to complete
        await Future.delayed(const Duration(milliseconds: 150));
      }

      _isLoading = true;
      _error = null;
      _currentArticle = article;
      _hasCompleted = false; // Reset completion flag when starting new audio
      _isAutoAdvancing = false; // Reset auto-advance flag when starting new audio
      _autoAdvanceFromIndex = null; // Clear stored index
      _autoAdvanceTimer?.cancel(); // Cancel any pending auto-advance timer
      notifyListeners();

      if (playTitle) {
        // Home screen/list views: Use stored news reading preference
        final readingMode = forceMode ?? StorageService.getNewsReadingMode();
        final List<String> urlsToPlay = [];

        if (readingMode == AppConstants.readingModeTitleOnly) {
          // Play title only
          final titleUrl = article.titleAudioUrl;
          if (titleUrl == null || titleUrl.isEmpty) {
            throw Exception('Title audio URL not available');
          }
          urlsToPlay.add(titleUrl);
          debugPrint('🎵 Playing title only from URL: $titleUrl');
        } else if (readingMode == AppConstants.readingModeDescriptionOnly) {
          // Play description only
          final descriptionUrl = article.descriptionAudioUrl;
          if (descriptionUrl == null || descriptionUrl.isEmpty) {
            throw Exception('Description audio URL not available');
          }
          urlsToPlay.add(descriptionUrl);
          debugPrint('🎵 Playing description only from URL: $descriptionUrl');
        } else if (readingMode == AppConstants.readingModeFullNews) {
          // Play full news: title → content (if present) → description
          // Order: 1. Title (always), 2. Content (if available), 3. Description (if available)
          final titleUrl = article.titleAudioUrl;
          final contentUrl = article.contentAudioUrl;
          final descriptionUrl = article.descriptionAudioUrl;
          
          if (titleUrl == null || titleUrl.isEmpty) {
            throw Exception('Title audio URL not available');
          }
          
          // 1. Title (always first)
          urlsToPlay.add(titleUrl);
          debugPrint('🎵 [Full News] Adding title URL: $titleUrl');
          
          // 2. Content (if available, play after title)
          if (contentUrl != null && contentUrl.isNotEmpty) {
            urlsToPlay.add(contentUrl);
            debugPrint('🎵 [Full News] Adding content URL: $contentUrl');
          }
          
          // 3. Description (if available, play after content)
          if (descriptionUrl != null && descriptionUrl.isNotEmpty) {
            urlsToPlay.add(descriptionUrl);
            debugPrint('🎵 [Full News] Adding description URL: $descriptionUrl');
          }
          
          debugPrint('🎵 [Full News] Playlist order: Title → Content → Description (${urlsToPlay.length} URLs total)');
        } else {
          // Fallback to default (title only) - this should not happen if storage is working correctly
          // But if reading mode is invalid/null, default to title only as per user requirement
          final titleUrl = article.titleAudioUrl;
          if (titleUrl == null || titleUrl.isEmpty) {
            throw Exception('Title audio URL not available');
          }
          urlsToPlay.add(titleUrl);
          debugPrint('🎵 Playing title only (default fallback - reading mode: $readingMode)');
        }

        _isLoading = false;
        notifyListeners();

        if (urlsToPlay.length == 1) {
          // Single URL - play directly
          await _audioPlayerService.playFromUrl(urlsToPlay[0]);
        } else {
          // Multiple URLs - play sequentially
          await _playSequentialUrls(urlsToPlay);
        }
      } else {
        // Detail screen: Play ONLY description URL (no content)
        final descriptionUrl = article.descriptionAudioUrl;

        if (descriptionUrl == null || descriptionUrl.isEmpty) {
          throw Exception('Description audio URL not available');
        }

        debugPrint('🎵 Playing description only from URL (detail screen): $descriptionUrl');
        _isLoading = false;
        notifyListeners();

        // Play only description URL - single URL, direct play
        await _audioPlayerService.playFromUrl(descriptionUrl);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isPlaying = false;
      _isPaused = false;
      _hasCompleted = false; // Reset completion flag on error
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
      // Cancel any pending auto-advance timer when user manually pauses
      _autoAdvanceTimer?.cancel();
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      
      await _audioPlayerService.pause();
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
    if (_currentPlaylistIndex < 0 || _currentPlaylistIndex >= _playlist.length) {
      debugPrint('⚠️ Cannot auto-advance: invalid current index ($_currentPlaylistIndex) for playlist length (${_playlist.length})');
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return;
    }

    final nextIndex = _currentPlaylistIndex + 1;
    if (nextIndex >= _playlist.length) {
      debugPrint('✅ Playlist completed - reached end (current index: $_currentPlaylistIndex, playlist length: ${_playlist.length})');
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
      debugPrint('❌ Cannot auto-advance: invalid next index ($nextIndex) for playlist length (${_playlist.length})');
      _isAutoAdvancing = false;
      _autoAdvanceFromIndex = null;
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return;
    }

    debugPrint('⏭️ Auto-advancing to next article: ${nextIndex + 1}/${_playlist.length}');
    
    try {
      // CRITICAL: Get the next article BEFORE updating index to avoid race conditions
      // Validate that nextIndex is valid one more time before accessing
      if (nextIndex < 0 || nextIndex >= _playlist.length) {
        debugPrint('❌ Cannot auto-advance: invalid next index ($nextIndex) for playlist length (${_playlist.length}) after validation');
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
      
      // IMPORTANT: Update current article BEFORE starting playback
      // This ensures the audio player bar stays visible during the transition
      _currentArticle = nextArticle;
      
      // Reset auto-advance flag before starting new audio (will be set again when this audio completes)
      _isAutoAdvancing = false;
      // Reset completion flag since we're starting new audio
      _hasCompleted = false;
      
      // Notify listeners to update UI (audio player bar should now show new article)
      notifyListeners();
      
      // Play next article using the same reading mode
      await playArticleFromUrl(nextArticle, playTitle: _playTitleMode);
      
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
          debugPrint('⚠️ Cannot retry auto-advance: playlist empty or invalid index');
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
      
      debugPrint('🎵 Setting up sequential playback with ${validUrls.length} URLs');
      
      // Create AudioSource URIs for each URL
      final List<AudioSource> audioSources = validUrls.map((url) {
        debugPrint('🎵 Creating AudioSource for: $url');
        return AudioSource.uri(Uri.parse(url));
      }).toList();

      // Create ConcatenatingAudioSource which will play URLs sequentially
      final concatenatedSource = ConcatenatingAudioSource(
        children: audioSources,
      );

      debugPrint('🎵 Created ConcatenatingAudioSource with ${audioSources.length} sources');

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
      debugPrint('🎵 Started playing concatenated source - will play ${validUrls.length} URLs sequentially (duration updates automatically as URLs load)');
      
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
    super.dispose();
  }
}
