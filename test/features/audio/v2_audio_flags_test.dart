import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_events.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/audio/data/audio_api.dart';
import 'package:newson/features/audio/data/audio_repository.dart';
import 'package:newson/features/audio/domain/article_audio.dart';

class _FakeAudioApi extends AudioApi {
  _FakeAudioApi(this._onFetch);

  final ArticleAudio Function() _onFetch;
  int fetches = 0;
  int requests = 0;

  @override
  Future<ArticleAudio> fetchStatus({
    required String articleId,
    String? language,
  }) async {
    fetches++;
    return _onFetch();
  }

  @override
  Future<ArticleAudio> requestGeneration({
    required String articleId,
    String? language,
  }) async {
    requests++;
    return ArticleAudio(
      articleId: articleId,
      status: ArticleAudioStatus.processing,
    );
  }
}

void main() {
  test('V2 audio flags default OFF', () {
    final c = RemoteConfigModel();
    expect(V2FeatureFlags.audio(c), isFalse);
    expect(V2FeatureFlags.audioGeneration(c), isFalse);
  });

  test('audio_click event name is stable', () {
    expect(AnalyticsEvents.audioClick, 'audio_click');
  });

  test('cache-first skips network for ready TTL hit', () async {
    final api = _FakeAudioApi(
      () => const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.ready,
        audioUrl: 'https://cdn.example/a.mp3',
      ),
    );
    final repo = AudioRepository(api: api);
    await repo.getStatus(articleId: 'a1');
    await repo.getStatus(articleId: 'a1');
    expect(api.fetches, 1);
  });

  test('bypassCache forces refetch', () async {
    final api = _FakeAudioApi(
      () => const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.ready,
        audioUrl: 'https://cdn.example/a.mp3',
      ),
    );
    final repo = AudioRepository(api: api);
    await repo.getStatus(articleId: 'a1');
    await repo.getStatus(articleId: 'a1', bypassCache: true);
    expect(api.fetches, 2);
  });

  test('requestGeneration increments request counter once', () async {
    final api = _FakeAudioApi(
      () => const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.unavailable,
      ),
    );
    final repo = AudioRepository(api: api);
    await repo.requestGeneration(articleId: 'a1');
    expect(api.requests, 1);
  });
}
