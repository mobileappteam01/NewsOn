import 'package:flutter_test/flutter_test.dart';
import 'package:newson/providers/audio_player_provider.dart';
import 'package:newson/data/services/background_music_service.dart';
import 'package:newson/data/models/news_article.dart';

/// Full integration tests for background music across all pages
/// Tests complete synchronization between speech audio and background music
void main() {
  group('Background Music Full Integration Tests', () {
    late AudioPlayerProvider audioProvider;
    late BackgroundMusicService backgroundService;

    setUp(() async {
      audioProvider = AudioPlayerProvider();
      backgroundService = BackgroundMusicService();
    });

    tearDown(() async {
      audioProvider.dispose();
      await backgroundService.dispose();
    });

    group('Speech Audio Synchronization', () {
      testWidgets('should start background music when speech starts',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Test Article',
          description: 'Test Description',
          content: 'Test Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing article
        await audioProvider.playArticleFromUrl(article, playTitle: true);

        // Wait for background music delay (800ms)
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify both are playing
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        print('✅ Background music starts with speech audio');
      });

      testWidgets('should pause background music when speech pauses',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Test Article',
          description: 'Test Description',
          content: 'Test Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify both are playing
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        // Pause speech
        await audioProvider.pause();
        await tester.pump();

        // Verify both are paused
        expect(audioProvider.isPlaying, isFalse);
        expect(audioProvider.isPaused, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        print('✅ Background music pauses with speech audio');
      });

      testWidgets('should resume background music when speech resumes',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Test Article',
          description: 'Test Description',
          content: 'Test Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Pause
        await audioProvider.pause();
        await tester.pump();

        // Verify both are paused
        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        // Resume speech
        await audioProvider.resume();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify both are playing
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        print('✅ Background music resumes with speech audio');
      });

      testWidgets('should stop background music when speech stops',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Test Article',
          description: 'Test Description',
          content: 'Test Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify both are playing
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        // Stop speech
        await audioProvider.stop();
        await tester.pump();

        // Verify both are stopped
        expect(audioProvider.isPlaying, isFalse);
        expect(audioProvider.isPaused, isFalse);
        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        print('✅ Background music stops with speech audio');
      });

      testWidgets('should toggle play/pause correctly',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Test Article',
          description: 'Test Description',
          content: 'Test Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify both are playing
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        // Toggle pause
        await audioProvider.togglePlayPause();
        await tester.pump();

        // Verify both are paused
        expect(audioProvider.isPlaying, isFalse);
        expect(audioProvider.isPaused, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        // Toggle resume
        await audioProvider.togglePlayPause();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify both are playing
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        print('✅ Background music toggles correctly with speech audio');
      });
    });

    group('Page Integration Tests', () {
      testWidgets('should work correctly on home screen (title mode)',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Home Screen Article',
          description: 'Home Description',
          content: 'Home Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          descriptionAudioUrl: 'https://example.com/description.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Simulate home screen play (title mode)
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify background music starts
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);
        expect(audioProvider.playTitleMode, isTrue);

        print('✅ Home screen integration works correctly');
      });

      testWidgets('should work correctly on detail screen (content mode)',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Detail Screen Article',
          description: 'Detail Description',
          content: 'Detail Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          descriptionAudioUrl: 'https://example.com/description.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Simulate detail screen play (content mode)
        await audioProvider.playArticleFromUrl(article, playTitle: false);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify background music starts
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);
        expect(audioProvider.playTitleMode, isFalse);

        print('✅ Detail screen integration works correctly');
      });

      testWidgets('should work correctly with playlist auto-advance',
          (WidgetTester tester) async {
        final articles = [
          NewsArticle(
            title: 'Article 1',
            description: 'Description 1',
            content: 'Content 1',
            pubDate: DateTime.now().toIso8601String(),
            titleAudioUrl: 'https://example.com/title1.mp3',
            contentAudioUrl: 'https://example.com/content1.mp3',
          ),
          NewsArticle(
            title: 'Article 2',
            description: 'Description 2',
            content: 'Content 2',
            pubDate: DateTime.now().toIso8601String(),
            titleAudioUrl: 'https://example.com/title2.mp3',
            contentAudioUrl: 'https://example.com/content2.mp3',
          ),
        ];

        // Set up playlist
        await audioProvider.setPlaylistAndPlay(articles, 0, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify first article playing with background music
        expect(audioProvider.isPlaying, isTrue);
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);
        expect(audioProvider.currentPlaylistIndex, equals(0));

        // Simulate completion and auto-advance
        // Note: In real app, this would be triggered by audio completion
        // For testing, we'll skip to next article manually
        await audioProvider.skipToNext();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify background music continues with next article
        expect(audioProvider.currentPlaylistIndex, equals(1));
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        print('✅ Playlist auto-advance works correctly with background music');
      });
    });

    group('Volume Control Tests', () {
      testWidgets('should control volumes independently',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Volume Test Article',
          description: 'Volume Description',
          content: 'Volume Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Set different volumes
        await audioProvider.setVolume(0.8); // Speech volume
        await audioProvider
            .setBackgroundMusicVolume(0.3); // Background music volume

        // Verify volumes are independent
        expect(audioProvider.volume, equals(0.8));
        expect(audioProvider.backgroundMusicVolume, equals(0.3));

        print('✅ Independent volume control works correctly');
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should handle background music start failure gracefully',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Error Test Article',
          description: 'Error Description',
          content: 'Error Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing (background music might fail)
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester
            .pump(const Duration(milliseconds: 2000)); // Wait for retries

        // Speech should still work even if background music fails
        expect(audioProvider.isPlaying, isTrue);

        print('✅ Background music failure handled gracefully');
      });

      testWidgets('should dispose background music properly',
          (WidgetTester tester) async {
        final article = NewsArticle(
          title: 'Dispose Test Article',
          description: 'Dispose Description',
          content: 'Dispose Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify background music is playing
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        // Dispose background music
        audioProvider.disposeBackgroundMusic();

        // Verify background music is stopped
        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        print('✅ Background music disposal works correctly');
      });
    });

    group('State Management Tests', () {
      testWidgets('should track background music state correctly',
          (WidgetTester tester) async {
        // Initial state
        expect(audioProvider.isBackgroundMusicPlaying, isFalse);
        expect(audioProvider.isBackgroundMusicInitialized, isTrue);
        expect(audioProvider.backgroundMusicVolume, equals(0.19));

        final article = NewsArticle(
          title: 'State Test Article',
          description: 'State Description',
          content: 'State Content',
          pubDate: DateTime.now().toIso8601String(),
          titleAudioUrl: 'https://example.com/title.mp3',
          contentAudioUrl: 'https://example.com/content.mp3',
        );

        // Start playing
        await audioProvider.playArticleFromUrl(article, playTitle: true);
        await tester.pump(const Duration(milliseconds: 1000));

        // Verify state changes
        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        // Pause
        await audioProvider.pause();
        await tester.pump();

        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        // Resume
        await audioProvider.resume();
        await tester.pump(const Duration(milliseconds: 500));

        expect(audioProvider.isBackgroundMusicPlaying, isTrue);

        // Stop
        await audioProvider.stop();
        await tester.pump();

        expect(audioProvider.isBackgroundMusicPlaying, isFalse);

        print('✅ Background music state tracking works correctly');
      });
    });
  });
}
