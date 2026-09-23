import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:newson/features/audio/data/audio_api.dart';
import 'package:newson/features/audio/data/audio_repository.dart';
import 'package:newson/features/audio/data/v2_audio_playback_service.dart';
import 'package:newson/features/audio/domain/article_audio.dart';
import 'package:newson/features/audio/domain/audio_state.dart';
import 'package:newson/features/audio/presentation/audio_controller.dart';

class _SeqApi extends AudioApi {
  _SeqApi(this.sequence);
  final List<ArticleAudio> sequence;
  int i = 0;
  int requests = 0;

  @override
  Future<ArticleAudio> fetchStatus({
    required String articleId,
    String? language,
  }) async {
    final idx = i < sequence.length ? i : sequence.length - 1;
    i++;
    return sequence[idx];
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

class _NoopPlayback extends V2AudioPlaybackService {
  _NoopPlayback() : super(player: null);

  int playCalls = 0;
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _state = StreamController<PlayerState>.broadcast();

  @override
  Stream<Duration> get positionStream => _pos.stream;

  @override
  Stream<Duration?> get durationStream => _dur.stream;

  @override
  Stream<PlayerState> get playerStateStream => _state.stream;

  @override
  Future<void> playUrl({required String articleId, required String url}) async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {
    await _pos.close();
    await _dur.close();
    await _state.close();
  }
}

void main() {
  test('ready status plays without POST', () async {
    final api = _SeqApi([
      const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.ready,
        audioUrl: 'https://cdn.example/a.mp3',
        durationMs: 1000,
      ),
    ]);
    final playback = _NoopPlayback();
    final controller = V2AudioController(
      repository: AudioRepository(api: api),
      playback: playback,
    );

    await controller.onListenTap(
      articleId: 'a1',
      generationEnabled: true,
    );
    expect(api.requests, 0);
    expect(playback.playCalls, 1);
    expect(controller.state.phase, V2AudioUiPhase.playing);
    controller.dispose();
    await playback.dispose();
  });

  test('unavailable without generation does not POST', () async {
    final api = _SeqApi([
      const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.unavailable,
      ),
    ]);
    final playback = _NoopPlayback();
    final controller = V2AudioController(
      repository: AudioRepository(api: api),
      playback: playback,
    );
    await controller.onListenTap(
      articleId: 'a1',
      generationEnabled: false,
    );
    expect(api.requests, 0);
    expect(controller.state.phase, V2AudioUiPhase.unavailable);
    controller.dispose();
    await playback.dispose();
  });

  test('unavailable with generation POSTs once', () async {
    final api = _SeqApi([
      const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.unavailable,
      ),
    ]);
    final playback = _NoopPlayback();
    final controller = V2AudioController(
      repository: AudioRepository(api: api),
      playback: playback,
      pollInterval: const Duration(hours: 1),
      pollTimeout: const Duration(hours: 1),
    );
    await controller.onListenTap(
      articleId: 'a1',
      generationEnabled: true,
    );
    expect(api.requests, 1);
    expect(controller.state.phase, V2AudioUiPhase.preparing);
    controller.dispose();
    await playback.dispose();
  });

  test('duplicate listen while in flight is ignored', () async {
    final api = _SeqApi([
      const ArticleAudio(
        articleId: 'a1',
        status: ArticleAudioStatus.ready,
        audioUrl: 'https://cdn.example/a.mp3',
      ),
    ]);
    final playback = _NoopPlayback();
    final controller = V2AudioController(
      repository: AudioRepository(api: api),
      playback: playback,
    );
    final f1 =
        controller.onListenTap(articleId: 'a1', generationEnabled: false);
    final f2 =
        controller.onListenTap(articleId: 'a1', generationEnabled: false);
    await Future.wait([f1, f2]);
    expect(playback.playCalls, 1);
    controller.dispose();
    await playback.dispose();
  });
}
