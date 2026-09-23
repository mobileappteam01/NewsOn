import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/audio/domain/article_audio.dart';

void main() {
  group('ArticleAudioStatus.parse', () {
    test('maps ready/processing/unavailable/failed', () {
      expect(ArticleAudioStatus.parse('ready'), ArticleAudioStatus.ready);
      expect(ArticleAudioStatus.parse('processing'), ArticleAudioStatus.processing);
      expect(ArticleAudioStatus.parse('queued'), ArticleAudioStatus.processing);
      expect(ArticleAudioStatus.parse('generating'), ArticleAudioStatus.processing);
      expect(
        ArticleAudioStatus.parse('unavailable'),
        ArticleAudioStatus.unavailable,
      );
      expect(ArticleAudioStatus.parse('failed'), ArticleAudioStatus.failed);
      expect(ArticleAudioStatus.parse('nope'), ArticleAudioStatus.unknown);
    });
  });

  group('ArticleAudio.fromJson', () {
    test('ready with url canPlay', () {
      final a = ArticleAudio.fromJson('id1', {
        'status': 'ready',
        'audioUrl': 'https://cdn.example/a.mp3',
        'durationMs': 12000,
      });
      expect(a.canPlay, isTrue);
      expect(a.durationMs, 12000);
    });

    test('ready without url cannot play', () {
      final a = ArticleAudio.fromJson('id1', {'status': 'ready'});
      expect(a.canPlay, isFalse);
    });
  });
}
