import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/audio_api.dart';
import '../data/audio_repository.dart';
import '../data/v2_audio_playback_service.dart';
import '../domain/article_audio.dart';
import '../domain/audio_state.dart';

/// V2 audio controller — cache-first GET, conditional POST, bounded poll, single player.
class V2AudioController extends ChangeNotifier {
  V2AudioController({
    AudioRepository? repository,
    V2AudioPlaybackService? playback,
    this.pollInterval = const Duration(seconds: 3),
    this.pollTimeout = const Duration(seconds: 60),
  })  : _repo = repository ?? AudioRepository(),
        _playback = playback ?? V2AudioPlaybackService() {
    _posSub = _playback.positionStream.listen((p) {
      _state = _state.copyWith(position: p);
      notifyListeners();
    });
    _durSub = _playback.durationStream.listen((d) {
      if (d != null) {
        _state = _state.copyWith(duration: d);
        notifyListeners();
      }
    });
    _playerSub = _playback.playerStateStream.listen((ps) {
      if (_state.articleId == null) return;
      if (ps.processingState == ProcessingState.completed) {
        _state = _state.copyWith(
          phase: V2AudioUiPhase.ready,
          position: Duration.zero,
        );
        notifyListeners();
        return;
      }
      if (ps.playing) {
        _state = _state.copyWith(
          phase: V2AudioUiPhase.playing,
          isBuffering: ps.processingState == ProcessingState.buffering ||
              ps.processingState == ProcessingState.loading,
        );
      } else if (_state.phase == V2AudioUiPhase.playing) {
        _state = _state.copyWith(
          phase: V2AudioUiPhase.paused,
          isBuffering: false,
        );
      }
      notifyListeners();
    });
  }

  final AudioRepository _repo;
  final V2AudioPlaybackService _playback;
  final Duration pollInterval;
  final Duration pollTimeout;

  V2AudioViewState _state = const V2AudioViewState();
  V2AudioViewState get state => _state;

  Timer? _pollTimer;
  DateTime? _pollStartedAt;
  int _pollTicks = 0;
  bool _listenInFlight = false;
  bool _requestInFlight = false;
  bool _disposed = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _playerSub;

  static const int maxPollTicks = 20; // ~60s at 3s

  /// User tapped Listen — emit analytics outside before calling.
  Future<void> onListenTap({
    required String articleId,
    String? language,
    required bool generationEnabled,
  }) async {
    if (_disposed || _listenInFlight) return;
    final id = articleId.trim();
    if (id.isEmpty) return;

    // Pause other article if switching.
    if (_state.articleId != null &&
        _state.articleId != id &&
        (_state.phase == V2AudioUiPhase.playing ||
            _state.phase == V2AudioUiPhase.paused)) {
      await _playback.stop();
    }

    _listenInFlight = true;
    _state = _state.copyWith(
      articleId: id,
      phase: V2AudioUiPhase.loadingStatus,
    );
    notifyListeners();

    try {
      final status = await _repo.getStatus(
        articleId: id,
        language: language,
      );
      if (_disposed) return;
      await _handleStatus(
        status,
        language: language,
        generationEnabled: generationEnabled,
        allowRequest: true,
      );
    } on AudioApiException {
      if (_disposed) return;
      _state = _state.copyWith(phase: V2AudioUiPhase.softError);
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _state = _state.copyWith(phase: V2AudioUiPhase.softError);
      notifyListeners();
    } finally {
      _listenInFlight = false;
    }
  }

  Future<void> retry({
    required String articleId,
    String? language,
    required bool generationEnabled,
  }) {
    _repo.invalidate(articleId, language: language);
    return onListenTap(
      articleId: articleId,
      language: language,
      generationEnabled: generationEnabled,
    );
  }

  Future<void> pause() async {
    await _playback.pause();
    _state = _state.copyWith(phase: V2AudioUiPhase.paused);
    notifyListeners();
  }

  Future<void> resume() async {
    await _playback.resume();
    _state = _state.copyWith(phase: V2AudioUiPhase.playing);
    notifyListeners();
  }

  Future<void> seek(Duration position) => _playback.seek(position);

  Future<void> stopAndClear() async {
    _stopPolling();
    await _playback.stop();
    _state = const V2AudioViewState();
    notifyListeners();
  }

  Future<void> _handleStatus(
    ArticleAudio status, {
    required String? language,
    required bool generationEnabled,
    required bool allowRequest,
  }) async {
    switch (status.status) {
      case ArticleAudioStatus.ready:
        _stopPolling();
        if (!status.canPlay) {
          _state = _state.copyWith(phase: V2AudioUiPhase.failed);
          notifyListeners();
          return;
        }
        _state = _state.copyWith(
          phase: V2AudioUiPhase.ready,
          audioUrl: status.audioUrl,
          duration: status.durationMs != null
              ? Duration(milliseconds: status.durationMs!)
              : _state.duration,
        );
        notifyListeners();
        await _playback.playUrl(
          articleId: status.articleId,
          url: status.audioUrl!,
        );
        _state = _state.copyWith(phase: V2AudioUiPhase.playing);
        notifyListeners();
        break;

      case ArticleAudioStatus.processing:
        _state = _state.copyWith(phase: V2AudioUiPhase.preparing);
        notifyListeners();
        _startPolling(
          articleId: status.articleId,
          language: language,
          generationEnabled: generationEnabled,
        );
        break;

      case ArticleAudioStatus.unavailable:
        if (allowRequest && generationEnabled && !_requestInFlight) {
          await _requestOnce(
            articleId: status.articleId,
            language: language,
            generationEnabled: generationEnabled,
          );
        } else {
          _stopPolling();
          _state = _state.copyWith(phase: V2AudioUiPhase.unavailable);
          notifyListeners();
        }
        break;

      case ArticleAudioStatus.failed:
        if (allowRequest && generationEnabled && !_requestInFlight) {
          await _requestOnce(
            articleId: status.articleId,
            language: language,
            generationEnabled: generationEnabled,
          );
        } else {
          _stopPolling();
          _state = _state.copyWith(phase: V2AudioUiPhase.failed);
          notifyListeners();
        }
        break;

      case ArticleAudioStatus.unknown:
        _state = _state.copyWith(phase: V2AudioUiPhase.softError);
        notifyListeners();
        break;
    }
  }

  Future<void> _requestOnce({
    required String articleId,
    String? language,
    required bool generationEnabled,
  }) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    _state = _state.copyWith(phase: V2AudioUiPhase.preparing);
    notifyListeners();
    try {
      final result = await _repo.requestGeneration(
        articleId: articleId,
        language: language,
      );
      if (_disposed) return;
      await _handleStatus(
        result,
        language: language,
        generationEnabled: generationEnabled,
        allowRequest: false, // never POST loop
      );
    } on AudioApiException {
      if (_disposed) return;
      _state = _state.copyWith(phase: V2AudioUiPhase.softError);
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _state = _state.copyWith(phase: V2AudioUiPhase.softError);
      notifyListeners();
    } finally {
      _requestInFlight = false;
    }
  }

  void _startPolling({
    required String articleId,
    String? language,
    required bool generationEnabled,
  }) {
    _stopPolling();
    _pollStartedAt = DateTime.now();
    _pollTicks = 0;
    _pollTimer = Timer.periodic(pollInterval, (_) async {
      if (_disposed) {
        _stopPolling();
        return;
      }
      _pollTicks++;
      final elapsed = DateTime.now().difference(_pollStartedAt!);
      if (_pollTicks > maxPollTicks || elapsed > pollTimeout) {
        _stopPolling();
        _state = _state.copyWith(phase: V2AudioUiPhase.softError);
        notifyListeners();
        return;
      }
      try {
        final status = await _repo.getStatus(
          articleId: articleId,
          language: language,
          bypassCache: true,
        );
        if (_disposed) return;
        if (status.status == ArticleAudioStatus.processing) {
          return; // keep polling
        }
        _stopPolling();
        await _handleStatus(
          status,
          language: language,
          generationEnabled: generationEnabled,
          allowRequest: false,
        );
      } catch (_) {
        // Soft: keep polling until timeout
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollStartedAt = null;
    _pollTicks = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    _posSub?.cancel();
    _durSub?.cancel();
    _playerSub?.cancel();
    // Do not dispose shared playback if singleton — stop only for this article.
    if (_state.articleId != null &&
        _playback.activeArticleId == _state.articleId) {
      _playback.stop();
    }
    super.dispose();
  }
}
