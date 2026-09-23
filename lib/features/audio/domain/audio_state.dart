/// UI / controller playback states for V2 audio (distinct from backend status).
enum V2AudioUiPhase {
  idle,
  loadingStatus,
  preparing,
  ready,
  playing,
  paused,
  failed,
  unavailable,
  softError,
}

class V2AudioViewState {
  const V2AudioViewState({
    this.phase = V2AudioUiPhase.idle,
    this.articleId,
    this.audioUrl,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isBuffering = false,
  });

  final V2AudioUiPhase phase;
  final String? articleId;
  final String? audioUrl;
  final Duration position;
  final Duration duration;
  final bool isBuffering;

  bool get showListen =>
      phase == V2AudioUiPhase.idle ||
      phase == V2AudioUiPhase.ready ||
      phase == V2AudioUiPhase.paused ||
      phase == V2AudioUiPhase.failed ||
      phase == V2AudioUiPhase.softError;

  V2AudioViewState copyWith({
    V2AudioUiPhase? phase,
    String? articleId,
    String? audioUrl,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    bool clearArticle = false,
  }) {
    return V2AudioViewState(
      phase: phase ?? this.phase,
      articleId: clearArticle ? null : (articleId ?? this.articleId),
      audioUrl: audioUrl ?? this.audioUrl,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
    );
  }
}
