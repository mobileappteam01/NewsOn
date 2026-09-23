import '../domain/article_audio.dart';
import 'audio_api.dart';

/// Cache-first V2 audio repository. Backend remains source of truth.
class AudioRepository {
  AudioRepository({
    AudioApi? api,
  }) : _api = api ?? AudioApi();

  final AudioApi _api;

  /// Short-lived in-memory status cache (URL+status). Cleared on request/fail.
  final Map<String, _CacheEntry> _cache = {};

  static const cacheTtl = Duration(minutes: 5);

  Future<ArticleAudio> getStatus({
    required String articleId,
    String? language,
    bool bypassCache = false,
  }) async {
    final key = _key(articleId, language);
    if (!bypassCache) {
      final hit = _cache[key];
      if (hit != null &&
          DateTime.now().difference(hit.at) < cacheTtl &&
          hit.audio.status == ArticleAudioStatus.ready &&
          hit.audio.canPlay) {
        return hit.audio;
      }
    }

    final audio = await _api.fetchStatus(
      articleId: articleId,
      language: language,
    );
    _cache[key] = _CacheEntry(audio, DateTime.now());
    return audio;
  }

  Future<ArticleAudio> requestGeneration({
    required String articleId,
    String? language,
  }) async {
    final audio = await _api.requestGeneration(
      articleId: articleId,
      language: language,
    );
    final key = _key(articleId, language);
    _cache[key] = _CacheEntry(audio, DateTime.now());
    return audio;
  }

  void invalidate(String articleId, {String? language}) {
    _cache.remove(_key(articleId, language));
  }

  void clearCache() => _cache.clear();

  String _key(String articleId, String? language) =>
      '${articleId.trim()}::${(language ?? '').trim().toLowerCase()}';
}

class _CacheEntry {
  _CacheEntry(this.audio, this.at);
  final ArticleAudio audio;
  final DateTime at;
}
