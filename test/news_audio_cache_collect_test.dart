import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/app_constants.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/services/news_audio_cache_service.dart';

void main() {
  test('collectAudioUrls dedupes and respects maxUrls', () {
    final a = NewsArticle(
      title: 't1',
      titleAudioUrl: 'https://example.com/a.mp3',
      descriptionAudioUrl: 'https://example.com/a.mp3',
      contentAudioUrl: 'https://example.com/b.mp3',
    );
    final b = NewsArticle(
      title: 't2',
      titleAudioUrl: 'https://example.com/c.mp3',
    );

    final urls = NewsAudioCacheService.collectAudioUrls([a, b], maxUrls: 10);
    expect(urls.length, 3);

    final capped = NewsAudioCacheService.collectAudioUrls([a, b], maxUrls: 2);
    expect(capped.length, 2);
  });

  test('playbackUrlsForArticle matches reading modes', () {
    final article = NewsArticle(
      title: 't',
      titleAudioUrl: 'https://example.com/t.mp3',
      descriptionAudioUrl: 'https://example.com/d.mp3',
      contentAudioUrl: 'https://example.com/c.mp3',
    );

    expect(
      NewsAudioCacheService.playbackUrlsForArticle(
        article,
        playTitle: true,
        readingMode: AppConstants.readingModeTitleOnly,
      ),
      ['https://example.com/t.mp3'],
    );

    expect(
      NewsAudioCacheService.playbackUrlsForArticle(
        article,
        playTitle: true,
        readingMode: AppConstants.readingModeDescriptionOnly,
      ),
      ['https://example.com/d.mp3'],
    );

    expect(
      NewsAudioCacheService.playbackUrlsForArticle(
        article,
        playTitle: true,
        readingMode: AppConstants.readingModeFullNews,
      ),
      ['https://example.com/c.mp3'],
    );

    expect(
      NewsAudioCacheService.playbackUrlsForArticle(
        article,
        playTitle: false,
      ),
      ['https://example.com/c.mp3'],
    );
  });

  test('playbackUrlsForArticle description fallback to title', () {
    final article = NewsArticle(
      title: 't',
      titleAudioUrl: 'https://example.com/t.mp3',
    );

    expect(
      NewsAudioCacheService.playbackUrlsForArticle(
        article,
        playTitle: true,
        readingMode: AppConstants.readingModeDescriptionOnly,
      ),
      ['https://example.com/t.mp3'],
    );
  });
}
