import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/providers/news_provider.dart';
import 'package:newson/screens/home/home_screen.dart';

/// Records V1 breaking-news requests (`getActiveNewsMobile`) instead of
/// hitting the network. Any other NewsProvider call fails the test.
class _RecordingNewsProvider implements NewsProvider {
  int breakingCalls = 0;

  @override
  Future<void> fetchBreakingNews({
    int limit = 10,
    int page = 1,
    bool forceNetwork = false,
  }) async {
    breakingCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('Unexpected NewsProvider call: ${invocation.memberName}');
}

void main() {
  group('Home startup V1 breaking-news preload', () {
    test('V2 Reader Home does not request V1 breaking news', () async {
      final news = _RecordingNewsProvider();
      await preloadHomeBreakingNews(
        RemoteConfigModel(v2HomeReaderEnabled: true),
        news,
      );
      expect(news.breakingCalls, 0);
    });

    test('V2 News Cuts Home does not request it from HomeScreen', () async {
      final news = _RecordingNewsProvider();
      await preloadHomeBreakingNews(
        RemoteConfigModel(v2NewsCutsEnabled: true),
        news,
      );
      expect(news.breakingCalls, 0);
    });

    test('V1 Home (V2 flags off) still preloads breaking news once', () async {
      final news = _RecordingNewsProvider();
      await preloadHomeBreakingNews(RemoteConfigModel(), news);
      expect(news.breakingCalls, 1);
    });

    test('preload gate matches the surface HomeScreen renders', () {
      expect(usesV2HomeSurface(RemoteConfigModel()), isFalse);
      expect(
        usesV2HomeSurface(RemoteConfigModel(v2HomeReaderEnabled: true)),
        isTrue,
      );
      expect(
        usesV2HomeSurface(RemoteConfigModel(v2NewsCutsEnabled: true)),
        isTrue,
      );
    });
  });

  group('no V2 startup path depends on fetchBreakingNews', () {
    final homeScreen =
        File('lib/screens/home/home_screen.dart').readAsStringSync();

    test('HomeScreen only reaches it through the gated preload', () {
      expect(
        RegExp(r'fetchBreakingNews\(').allMatches(homeScreen).length,
        1,
        reason: 'single call, inside preloadHomeBreakingNews',
      );
      expect(homeScreen.contains('await preloadHomeBreakingNews('), isTrue);
      expect(homeScreen.contains('final v2Home = usesV2HomeSurface(config)'),
          isTrue);
    });

    test('V2 Reader Home never uses NewsProvider breaking news', () {
      for (final f in Directory('lib/features/home_v2')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        expect(src.contains('fetchBreakingNews'), isFalse, reason: f.path);
        expect(src.contains('breakingNews'), isFalse, reason: f.path);
        expect(src.contains('NewsProvider'), isFalse, reason: f.path);
      }
    });
  });
}
