import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/data/services/bookmark_api_service.dart';
import 'package:newson/data/services/completed_news_service.dart';
import 'package:newson/data/services/remote_config_service.dart';
import 'package:newson/features/bookmarks/data/v2_bookmark_sync.dart';
import 'package:newson/features/notifications/data/notification_service.dart';
import 'package:newson/providers/bookmark_provider.dart';
import 'package:newson/providers/completed_news_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:newson/data/models/news_article.dart';

class _BookmarkServer implements V2BookmarkRemote {
  int listCalls = 0;
  int failFirst = 0;
  Completer<void>? gate;

  @override
  Future<BookmarkListResponse?> tryGetV2BookmarkList({
    int page = 1,
    int limit = 20,
  }) async {
    final call = ++listCalls;
    final g = gate;
    if (g != null) await g.future;
    if (call <= failFirst) return null;
    return BookmarkListResponse.fromV2Data({
      'items': [
        {'articleId': 'a1', '_id': 'a1', 'title': 'Story'},
      ],
      'page': page,
      'limit': limit,
      'hasNextPage': false,
    });
  }

  @override
  Future<void> addV2Bookmark(String newsId) async {}

  @override
  Future<void> deleteV2Bookmark(String newsId) async {}
}

class _MemoryStore implements V2BookmarkStore {
  List<NewsArticle> saved = <NewsArticle>[];

  @override
  List<NewsArticle> readList() => saved;

  @override
  Future<void> writeList(List<NewsArticle> bookmarks) async {
    saved = List<NewsArticle>.of(bookmarks);
  }
}

class _FakeRemoteConfigService implements RemoteConfigService {
  int initializeCalls = 0;
  int fetchCalls = 0;
  int forceFetchCalls = 0;
  Completer<void>? gate;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final g = gate;
    if (g != null) await g.future;
  }

  @override
  Future<bool> fetchConfig() async {
    fetchCalls++;
    return true;
  }

  @override
  Future<bool> forceFetchConfig() async {
    forceFetchCalls++;
    return true;
  }

  @override
  RemoteConfigModel getConfig() => RemoteConfigModel(appName: 'remote');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCompletedService implements CompletedNewsService {
  int onceCalls = 0;
  final List<String> subscribedUsers = <String>[];
  final List<String> cancelledUsers = <String>[];
  final Map<String, StreamController<Set<String>>> streams = {};

  @override
  Stream<Set<String>> getCompletedNewsStream(String userId) {
    late final StreamController<Set<String>> controller;
    controller = StreamController<Set<String>>(
      onListen: () => subscribedUsers.add(userId),
      onCancel: () => cancelledUsers.add(userId),
    );
    streams[userId] = controller;
    return controller.stream;
  }

  @override
  Future<Set<String>> getCompletedNewsOnce(String userId) async {
    onceCalls++;
    return <String>{};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('V2 device registration', () {
    final enabled = RemoteConfigModel(v2NotificationsEnabled: true);
    late List<String> registered;
    late bool loggedIn;
    late String? auth;
    late String fcm;
    late bool succeed;
    late Completer<void>? gate;

    V2NotificationService service() => V2NotificationService.forTest(
          isLoggedIn: () => loggedIn,
          authToken: () => auth,
          fcmToken: () async => fcm,
          registerDevice: (token) async {
            registered.add(token);
            final g = gate;
            if (g != null) await g.future;
            return succeed;
          },
        );

    setUp(() {
      registered = <String>[];
      loggedIn = true;
      auth = 'auth-1';
      fcm = 'fcm-1';
      succeed = true;
      gate = null;
    });

    test('app start and Home open register the device once', () async {
      final svc = service();
      gate = Completer<void>();
      final appStart = svc.onUserAuthenticated(enabled);
      final homeOpen = svc.onUserAuthenticated(enabled);
      await pumpEventQueue();
      gate!.complete();
      await Future.wait([appStart, homeOpen]);
      expect(registered, ['fcm-1']);

      await svc.onUserAuthenticated(enabled);
      expect(registered, ['fcm-1'], reason: 'Home re-entry');
    });

    test('new login or rotated FCM token registers again', () async {
      final svc = service();
      await svc.onUserAuthenticated(enabled);
      auth = 'auth-2';
      await svc.onUserAuthenticated(enabled);
      fcm = 'fcm-2';
      await svc.onUserAuthenticated(enabled);
      expect(registered, ['fcm-1', 'fcm-1', 'fcm-2']);
    });

    test('a failed registration is retried', () async {
      final svc = service();
      succeed = false;
      await svc.onUserAuthenticated(enabled);
      succeed = true;
      await svc.onUserAuthenticated(enabled);
      await svc.onUserAuthenticated(enabled);
      expect(registered, ['fcm-1', 'fcm-1']);
    });

    test('signed out or flag off: no registration', () async {
      final svc = service();
      await svc.onUserAuthenticated(RemoteConfigModel());
      loggedIn = false;
      await svc.onUserAuthenticated(enabled);
      expect(registered, isEmpty);
    });
  });

  group('V2 Home-open bookmarks', () {
    late _BookmarkServer server;
    late String session;
    late bool loggedIn;

    BookmarkProvider provider() => BookmarkProvider(
          v2Remote: server,
          v2Store: _MemoryStore(),
          isLoggedIn: () => loggedIn,
          sessionKey: () => session,
          prefetchAudio: (_) {},
        );

    setUp(() {
      server = _BookmarkServer();
      session = 'user-1';
      loggedIn = true;
    });

    test('Bookmarks tab refresh + Home open send one request', () async {
      final p = provider();
      server.gate = Completer<void>();
      final tab = p.loadBookmarks(refresh: true, v2List: true);
      final home = p.ensureV2BookmarksLoaded();
      await pumpEventQueue();
      server.gate!.complete();
      await Future.wait([tab, home]);

      expect(server.listCalls, 1);
      expect(p.bookmarks.map((a) => a.newsId), ['a1']);
      expect(p.error, isNull);
    });

    test('Home open after a completed load does not refetch', () async {
      final p = provider();
      await p.loadBookmarks(refresh: true, v2List: true);
      await p.ensureV2BookmarksLoaded();
      expect(server.listCalls, 1);
    });

    test('explicit refresh still hits the network', () async {
      final p = provider();
      await p.loadBookmarks(refresh: true, v2List: true);
      await p.ensureV2BookmarksLoaded();
      await p.loadBookmarks(refresh: true, v2List: true);
      expect(server.listCalls, 2);
    });

    test('Home open loads when nothing ran yet', () async {
      final p = provider();
      await p.ensureV2BookmarksLoaded();
      expect(server.listCalls, 1);
      expect(p.bookmarks.map((a) => a.newsId), ['a1']);
    });

    test('a failed tab load is retried by Home open', () async {
      final p = provider();
      server
        ..failFirst = 1
        ..gate = Completer<void>();
      final tab = p.loadBookmarks(refresh: true, v2List: true);
      final home = p.ensureV2BookmarksLoaded();
      await pumpEventQueue();
      expect(server.listCalls, 1);
      server.gate!.complete();
      await Future.wait([tab, home]);
      expect(server.listCalls, 2);
      expect(p.bookmarks.map((a) => a.newsId), ['a1']);
    });

    test('account switch loads the new account list', () async {
      final p = provider();
      await p.loadBookmarks(refresh: true, v2List: true);
      session = 'user-2';
      await p.ensureV2BookmarksLoaded();
      expect(server.listCalls, 2);
    });

    test('logout then login loads again', () async {
      final p = provider();
      await p.loadBookmarks(refresh: true, v2List: true);
      loggedIn = false;
      await p.loadBookmarks(refresh: true, v2List: true);
      expect(p.bookmarks, isEmpty);
      loggedIn = true;
      await p.ensureV2BookmarksLoaded();
      expect(server.listCalls, 2);
    });
  });

  group('Remote Config initialization', () {
    late _FakeRemoteConfigService service;
    late DateTime now;

    setUp(() {
      service = _FakeRemoteConfigService();
      now = DateTime(2026, 10, 1, 9);
    });

    RemoteConfigProvider provider() =>
        RemoteConfigProvider.withService(service, now: () => now);

    test('app start (x2) + Home open fetch/activate once', () async {
      final p = provider();
      service.gate = Completer<void>();
      final first = p.initialize();
      final bootstrap = p.initialize();
      final home = p.initialize();
      await pumpEventQueue();
      expect(p.isInitialized, isTrue, reason: 'cache/defaults applied first');
      service.gate!.complete();
      await Future.wait([first, bootstrap, home]);

      expect(service.initializeCalls, 1);
      expect(service.fetchCalls, 0);
      expect(p.config.appName, 'remote');
    });

    test('later calls refresh only after the fetch interval', () async {
      final p = provider();
      await p.initialize();

      now = now.add(const Duration(seconds: 30));
      await p.initialize();
      expect(service.fetchCalls, 0);

      now = now.add(RemoteConfigService.minimumFetchInterval);
      await p.initialize();
      expect(service.initializeCalls, 1);
      expect(service.fetchCalls, 1);
    });

    test('forceRefresh still fetches and resets the interval', () async {
      final p = provider();
      await p.initialize();
      now = now.add(const Duration(minutes: 5));
      await p.forceRefresh();
      await p.initialize();
      expect(service.forceFetchCalls, 1);
      expect(service.fetchCalls, 0);
    });
  });

  group('Completed news Firestore listener', () {
    late _FakeCompletedService service;
    late String? userId;

    setUpAll(() {
      Hive.init(Directory.systemTemp.createTempSync('completed_news').path);
    });

    setUp(() {
      service = _FakeCompletedService();
      userId = 'user-1';
    });

    CompletedNewsProvider provider() => CompletedNewsProvider(
          completedService: service,
          currentUserId: () => userId,
        );

    test('app start + Home open: one listener, no extra get()', () async {
      final p = provider();
      await Future.wait([p.loadForCurrentUser(), p.loadForCurrentUser()]);
      await p.loadForCurrentUser();
      await pumpEventQueue();

      expect(service.subscribedUsers, ['user-1']);
      expect(service.onceCalls, 0);

      service.streams['user-1']!.add({'n1', 'n2'});
      await pumpEventQueue();
      expect(p.isCompleted('n1'), isTrue);
      expect(p.isLoading, isFalse);
      p.dispose();
    });

    test('account switch cancels the previous listener', () async {
      final p = provider();
      await p.loadForCurrentUser();
      userId = 'user-2';
      await p.loadForCurrentUser();
      await pumpEventQueue();

      expect(service.subscribedUsers, ['user-1', 'user-2']);
      expect(service.cancelledUsers, ['user-1']);
      expect(p.userId, 'user-2');
      p.dispose();
    });

    test('clearUser and dispose cancel the listener', () async {
      final p = provider();
      await p.loadForCurrentUser();
      await p.clearUser();
      expect(service.cancelledUsers, ['user-1']);

      await p.loadForCurrentUser();
      p.dispose();
      await pumpEventQueue();
      expect(service.cancelledUsers, ['user-1', 'user-1']);
    });

    test('logout during the local load does not attach a listener', () async {
      final p = provider();
      final load = p.loadForCurrentUser();
      await p.clearUser();
      await load;
      await pumpEventQueue();
      expect(service.subscribedUsers, isEmpty);
      expect(p.userId, isNull);
      p.dispose();
    });
  });

  group('Realtime DB ipAddress', () {
    test('startup reads ipAddress through the shared ApiService read', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains("fetchDBData('ipAddress')"), isFalse);
      expect(main.contains('ApiService().loadBaseUrl()'), isTrue);

      final api = File('lib/data/services/api_service.dart').readAsStringSync();
      expect(api.contains('await loadBaseUrl().timeout('), isTrue);
      expect(
        RegExp(r"child\('ipAddress'\)").allMatches(api).length,
        1,
        reason: 'one Realtime DB read site',
      );
    });
  });
}
