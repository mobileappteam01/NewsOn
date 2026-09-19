import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_api_config.dart';
import 'package:newson/data/models/for_you_response.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/news_response.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/data/services/api_service.dart';
import 'package:newson/data/services/v2_api_config_service.dart';
import 'package:newson/features/for_you/data/for_you_repository.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';

void main() {
  group('V2ApiConfig', () {
    test('parses Firestore map with baseUrl + enabled', () {
      final config = V2ApiConfig.fromFirestoreMap({
        'baseUrl': 'https://v2-api.newson.app/',
        'enabled': true,
      });
      expect(config.baseUrl, 'https://v2-api.newson.app');
      expect(config.enabled, isTrue);
      expect(config.isUsable, isTrue);
    });

    test('accepts base_url alias and string enabled', () {
      final config = V2ApiConfig.fromFirestoreMap({
        'base_url': 'https://v2-api.newson.app',
        'enabled': 'true',
      });
      expect(config.isUsable, isTrue);
    });

    test('disabled config is not usable', () {
      final config = V2ApiConfig.fromFirestoreMap({
        'baseUrl': 'https://v2-api.newson.app',
        'enabled': false,
      });
      expect(config.isUsable, isFalse);
    });

    test('relative baseUrl is not usable', () {
      final config = V2ApiConfig.fromFirestoreMap({
        'baseUrl': 'api.newson.app',
        'enabled': true,
      });
      expect(config.isUsable, isFalse);
    });
  });

  group('V2ApiConfigService readiness', () {
    test('request before config ready waits correctly', () async {
      final gate = Completer<V2ApiConfig?>();
      var fetchCount = 0;
      final service = V2ApiConfigService(
        fetcher: () async {
          fetchCount++;
          return gate.future;
        },
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );

      final pending = service.requireReadyBaseUrl();
      await Future<void>.delayed(Duration.zero);
      expect(service.isInitialized, isFalse);
      expect(fetchCount, 1);

      gate.complete(
        const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
      );

      expect(await pending, 'https://v2-api.newson.app');
      expect(service.isInitialized, isTrue);
      expect(fetchCount, 1);
    });

    test('request after config ready works immediately', () async {
      final service = V2ApiConfigService(
        fetcher: () async => const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      await service.ensureReady();
      expect(service.requireBaseUrl(), 'https://v2-api.newson.app');
      expect(await service.requireReadyBaseUrl(), 'https://v2-api.newson.app');
    });

    test('concurrent ensureReady shares one Firebase fetch', () async {
      final gate = Completer<V2ApiConfig?>();
      var fetchCount = 0;
      final service = V2ApiConfigService(
        fetcher: () async {
          fetchCount++;
          return gate.future;
        },
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );

      final a = service.ensureReady();
      final b = service.ensureReady();
      final c = service.ready;
      expect(fetchCount, 1);

      gate.complete(
        const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
      );
      await Future.wait([a, b, c]);
      expect(fetchCount, 1);
      expect(service.requireBaseUrl(), 'https://v2-api.newson.app');
    });

    test('loads config from fetcher and resolves baseUrl', () async {
      final service = V2ApiConfigService(
        fetcher: () async => const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );

      await service.initialize();

      expect(service.baseUrlIfEnabled, 'https://v2-api.newson.app');
      expect(service.requireBaseUrl(), 'https://v2-api.newson.app');
    });

    test('uses last-known-good cache when remote fetch fails', () async {
      var wrote = false;
      final service = V2ApiConfigService(
        fetcher: () async => throw Exception('network down'),
        cacheReader: () => const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
        cacheWriter: (_) async {
          wrote = true;
        },
      );

      await service.initialize();

      expect(service.requireBaseUrl(), 'https://v2-api.newson.app');
      expect(wrote, isFalse);
    });

    test('dart-define style override wins over fetcher', () async {
      final service = V2ApiConfigService(
        dartDefineOverride: 'https://v2-api.newson.app',
        fetcher: () async => const V2ApiConfig(
          baseUrl: 'https://should-not-use.example',
          enabled: true,
        ),
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );

      await service.initialize();
      expect(service.requireBaseUrl(), 'https://v2-api.newson.app');
    });

    test('config disabled blocks request — no V1 fallback', () async {
      final service = V2ApiConfigService(
        fetcher: () async => const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: false,
        ),
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      await service.ensureReady();

      expect(
        () => service.requireBaseUrl(),
        throwsA(isA<V2ApiConfigException>()),
      );
      await expectLater(
        service.requireReadyBaseUrl(),
        throwsA(isA<V2ApiConfigException>()),
      );
      expect(service.baseUrlIfEnabled, isNull);
    });

    test('config missing blocks request — no V1 fallback', () async {
      final service = V2ApiConfigService(
        fetcher: () async => null,
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      await service.ensureReady();

      expect(
        () => service.requireBaseUrl(),
        throwsA(isA<V2ApiConfigException>()),
      );
      expect(service.baseUrlIfEnabled, isNull);
    });

    test('V1 and V2 configs can coexist independently', () async {
      const v1Base = 'https://api.newson.app';
      final v2 = V2ApiConfigService(
        fetcher: () async => const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      await v2.initialize();

      final v1Url = ApiService.joinApiBaseAndPath(v1Base, '/api/user/login');
      final v2Url = ApiService.joinApiBaseAndPath(
        v2.requireBaseUrl(),
        '/api/v2/search',
      );

      expect(v1Url, 'https://api.newson.app/api/user/login');
      expect(v2Url, 'https://v2-api.newson.app/api/v2/search');
      expect(v1Url, isNot(contains('v2-api.newson.app')));
      expect(v2Url, isNot(contains('api.newson.app/api/user')));
    });
  });

  group('For You / Search readiness behavior', () {
    test('ForYouRepository does not cold-start to V1 on V2ApiConfigException',
        () async {
      var coldStartCalled = false;
      final repo = ForYouRepository(
        forYouFetcher: ({
          required page,
          required limit,
          language,
          region,
        }) async =>
            throw V2ApiConfigException('missing'),
        todayFetcher: ({
          required language,
          required limit,
          country,
          state,
          district,
        }) async {
          coldStartCalled = true;
          return NewsResponse(
            status: 'ok',
            totalResults: 1,
            results: [
              NewsArticle(articleId: 'v1', newsId: 'v1', title: 'V1'),
            ],
          );
        },
      );

      await expectLater(
        repo.fetchPage(
          page: 1,
          newsLanguageCode: 'en',
          appliedRegion: const SavedRegion(),
        ),
        throwsA(isA<V2ApiConfigException>()),
      );
      expect(coldStartCalled, isFalse);
    });
  });

  group('V2ReaderController config race', () {
    NewsArticle article(String id) => NewsArticle(
          articleId: id,
          newsId: id,
          title: 'T $id',
          link: 'https://example.com/$id',
        );

    test('initial load succeeds after config becomes ready', () async {
      final gate = Completer<V2ApiConfig?>();
      final config = V2ApiConfigService(
        fetcher: () => gate.future,
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      final repo = ForYouRepository(
        forYouFetcher: ({
          required page,
          required limit,
          language,
          region,
        }) async {
          final base = await config.requireReadyBaseUrl();
          expect(base, 'https://v2-api.newson.app');
          return ForYouResponse(
            message: 'personalized',
            pagination: ForYouPagination(
              total: 1,
              page: 1,
              limit: limit,
              totalPages: 1,
            ),
            articles: [article('a1')],
          );
        },
        todayFetcher: ({
          required language,
          required limit,
          country,
          state,
          district,
        }) async =>
            NewsResponse(status: 'ok', totalResults: 0, results: const []),
      );

      final controller = V2ReaderController(
        repository: repo,
        configService: config,
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
      );

      final load = controller.loadInitial();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, V2ReaderStatus.loading);

      gate.complete(
        const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
      );
      await load;

      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.articles.single.newsId, 'a1');
      expect(controller.fetchAttempts, 1);
    });

    test('single retry after config-ordering failure; no permanent empty',
        () async {
      var attempts = 0;
      final config = V2ApiConfigService(
        fetcher: () async => const V2ApiConfig(
          baseUrl: 'https://v2-api.newson.app',
          enabled: true,
        ),
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      final repo = ForYouRepository(
        forYouFetcher: ({
          required page,
          required limit,
          language,
          region,
        }) async {
          attempts++;
          if (attempts == 1) {
            throw V2ApiConfigException('startup race');
          }
          return ForYouResponse(
            message: 'personalized',
            pagination: ForYouPagination(
              total: 1,
              page: 1,
              limit: limit,
              totalPages: 1,
            ),
            articles: [article('retry-ok')],
          );
        },
        todayFetcher: ({
          required language,
          required limit,
          country,
          state,
          district,
        }) async =>
            NewsResponse(status: 'ok', totalResults: 0, results: const []),
      );

      final controller = V2ReaderController(
        repository: repo,
        configService: config,
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
      );

      await controller.loadInitial();

      expect(controller.state.status, V2ReaderStatus.ready);
      expect(controller.state.current?.newsId, 'retry-ok');
      expect(controller.fetchAttempts, 2);
      expect(attempts, 2);
    });

    test('does not retry beyond the intended single config retry', () async {
      var attempts = 0;
      final config = V2ApiConfigService(
        fetcher: () async => null,
        cacheReader: () => null,
        cacheWriter: (_) async {},
      );
      final repo = ForYouRepository(
        forYouFetcher: ({
          required page,
          required limit,
          language,
          region,
        }) async {
          attempts++;
          throw V2ApiConfigException('still missing');
        },
        todayFetcher: ({
          required language,
          required limit,
          country,
          state,
          district,
        }) async =>
            NewsResponse(status: 'ok', totalResults: 0, results: const []),
      );

      final controller = V2ReaderController(
        repository: repo,
        configService: config,
        newsLanguageCode: () => 'en',
        appliedRegion: () => const SavedRegion(),
      );

      await controller.loadInitial();

      expect(controller.state.status, V2ReaderStatus.error);
      expect(controller.state.status, isNot(V2ReaderStatus.empty));
      expect(controller.fetchAttempts, lessThanOrEqualTo(2));
      expect(attempts, lessThanOrEqualTo(2));
    });
  });

  group('ApiService.joinApiBaseAndPath', () {
    test('V2 request uses V2 base URL', () {
      final url = ApiService.joinApiBaseAndPath(
        'https://v2-api.newson.app',
        '/api/v2/for-you',
      );
      expect(url, 'https://v2-api.newson.app/api/v2/for-you');
    });

    test('V1 request uses V1 base URL', () {
      final url = ApiService.joinApiBaseAndPath(
        'https://api.newson.app',
        'api/latestnews/getActiveNewsMobile',
      );
      expect(url, 'https://api.newson.app/api/latestnews/getActiveNewsMobile');
    });

    test('preserves staging port on base', () {
      final url = ApiService.joinApiBaseAndPath(
        'http://127.0.0.1:8010',
        '/api/v2/search',
      );
      expect(url, 'http://127.0.0.1:8010/api/v2/search');
    });

    test('absolute path is unchanged (no accidental host swap)', () {
      final url = ApiService.joinApiBaseAndPath(
        'https://api.newson.app',
        'https://v2-api.newson.app/api/v2/search',
      );
      expect(url, 'https://v2-api.newson.app/api/v2/search');
    });
  });
}
