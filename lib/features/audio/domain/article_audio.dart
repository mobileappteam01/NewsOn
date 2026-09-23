/// Backend client statuses for V2 article audio (Phase 8).
enum ArticleAudioStatus {
  ready,
  processing,
  unavailable,
  failed,
  unknown;

  static ArticleAudioStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'ready':
        return ArticleAudioStatus.ready;
      case 'processing':
      case 'queued':
      case 'generating':
        return ArticleAudioStatus.processing;
      case 'unavailable':
        return ArticleAudioStatus.unavailable;
      case 'failed':
        return ArticleAudioStatus.failed;
      default:
        return ArticleAudioStatus.unknown;
    }
  }
}

/// Normalized V2 audio payload — no provider/S3 internals.
class ArticleAudio {
  const ArticleAudio({
    required this.articleId,
    required this.status,
    this.audioUrl,
    this.durationMs,
    this.language,
    this.voiceId,
  });

  final String articleId;
  final ArticleAudioStatus status;
  final String? audioUrl;
  final int? durationMs;
  final String? language;
  final String? voiceId;

  bool get canPlay =>
      status == ArticleAudioStatus.ready &&
      audioUrl != null &&
      audioUrl!.trim().isNotEmpty;

  factory ArticleAudio.fromJson(
    String articleId,
    Map<String, dynamic> json,
  ) {
    return ArticleAudio(
      articleId: articleId,
      status: ArticleAudioStatus.parse(json['status'] as String?),
      audioUrl: json['audioUrl'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      language: json['language'] as String?,
      voiceId: json['voiceId'] as String?,
    );
  }

  ArticleAudio copyWith({
    ArticleAudioStatus? status,
    String? audioUrl,
    int? durationMs,
  }) {
    return ArticleAudio(
      articleId: articleId,
      status: status ?? this.status,
      audioUrl: audioUrl ?? this.audioUrl,
      durationMs: durationMs ?? this.durationMs,
      language: language,
      voiceId: voiceId,
    );
  }
}
