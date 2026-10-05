import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/services/api_service.dart';
import 'package:newson/data/services/bookmark_api_service.dart';
import 'package:newson/features/bookmarks/data/v2_bookmark_sync.dart';
import 'package:newson/providers/bookmark_provider.dart';

String _id(int n) => n.toRadixString(16).padLeft(24, 'a');

NewsArticle _article(int n) => NewsArticle.fromJson({
      '_id': _id(n),
      'articleId': _id(n),
      'title': 'Story $n',
    });

/// In-memory V2 bookmark backend with the same semantics as
/// `V2BookmarkService`: user+news unique, newest first, DELETE of a missing
/// row answers "already removed".
class FakeV2Server implements V2BookmarkRemote {
  final List<String> rows = <String>[];
  final Map<String, String> titles = <String, String>{};
  final List<String> deleteCalls = <String>[];
  final List<String> addCalls = <String>[];
  int listCalls = 0;

  Set<String> failDeletes = <String>{};
  bool failList = false;
  Completer<void>? listGate;
  Completer<void>? deleteGate;

  void seed(Iterable<int> ns) {
    for (final n in ns) {
      rows.add(_id(n));
      titles[_id(n)] = 'Story $n';
    }
  }

  @override
  Future<void> addV2Bookmark(String newsId) async {
    addCalls.add(newsId);
    if (!rows.contains(newsId)) rows.insert(0, newsId);
    titles.putIfAbsent(newsId, () => 'Story');
  }

  @override
  Future<void> deleteV2Bookmark(String newsId) async {
    deleteCalls.add(newsId);
    final gate = deleteGate;
    if (gate != null) await gate.future;
    if (failDeletes.contains(newsId)) {
      throw Exception('Connection error. Please check your internet connection.');
    }
    rows.remove(newsId);
  }

  @override
  Future<BookmarkListResponse?> tryGetV2BookmarkList({
    int page = 1,
    int limit = 20,
  }) async {
    listCalls++;
    // Server state is read when the request is handled, before the
    // response travels back.
    final start = (page - 1) * limit;
    final snapshot = rows.skip(start).take(limit).toList();
    final hasNext = rows.length > start + limit;
    final gate = listGate;
    if (gate != null) await gate.future;
    if (failList) return null;
    return BookmarkListResponse.fromV2Data({
      'items': [
        for (final id in snapshot)
          {'articleId': id, '_id': id, 'title': titles[id] ?? 'Story'},
      ],
      'page': page,
      'limit': limit,
      'hasNextPage': hasNext,
    });
  }
}

/// Device storage that survives an app kill: JSON round trip like Hive.
class FakeDisk implements V2BookmarkStore {
  List<Map<String, dynamic>> saved = <Map<String, dynamic>>[];
  int writes = 0;

  void seed(Iterable<int> ns) {
    saved = [for (final n in ns) _article(n).toJson()];
  }

  List<String?> get ids => [for (final a in readList()) a.newsId];

  @override
  List<NewsArticle> readList() =>
      [for (final json in saved) NewsArticle.fromJson(json)];

  @override
  Future<void> writeList(List<NewsArticle> bookmarks) async {
    writes++;
    saved = [for (final a in bookmarks) a.toJson()];
  }
}

BookmarkProvider _launch(
  FakeV2Server server,
  FakeDisk disk, {
  bool loggedIn = true,
}) {
  return BookmarkProvider(
    v2Remote: server,
    v2Store: disk,
    isLoggedIn: () => loggedIn,
    prefetchAudio: (_) {},
  );
}

List<String?> _ids(BookmarkProvider p) => [for (final a in p.bookmarks) a.newsId];

void main() {
  late FakeV2Server server;
  late FakeDisk disk;

  setUp(() {
    server = FakeV2Server();
    disk = FakeDisk();
  });

  group('restart after removal', () {
    test('bookmark → remove → kill → reopen → zero bookmarks', () async {
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      expect(await app.toggleBookmarkV2(_article(1)), isTrue);
      expect(server.rows, [_id(1)]);
      expect(disk.ids, [_id(1)]);

      expect(await app.toggleBookmarkV2(_article(1)), isFalse);
      expect(server.rows, isEmpty, reason: 'backend confirmed delete');
      expect(disk.ids, isEmpty, reason: 'local copy persisted as empty');
      expect(app.bookmarks, isEmpty);

      final reopened = _launch(server, disk);
      await reopened.loadBookmarks(v2List: true);
      expect(reopened.bookmarks, isEmpty);
      expect(reopened.isBookmarked(_article(1)), isFalse);
      expect(reopened.error, isNull);
    });

    test('remove all (one by one) stays empty after restart', () async {
      server.seed([1, 2, 3]);
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);
      expect(_ids(app), [_id(1), _id(2), _id(3)]);

      for (final n in [1, 2, 3]) {
        await app.toggleBookmarkV2(_article(n));
      }
      expect(app.bookmarks, isEmpty);
      expect(server.rows, isEmpty);
      expect(disk.ids, isEmpty);

      final reopened = _launch(server, disk);
      await reopened.loadBookmarks(refresh: true, v2List: true);
      expect(reopened.bookmarks, isEmpty);
    });

    test('remove one of many keeps exactly the rest after restart', () async {
      server.seed([1, 2, 3]);
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);
      await app.toggleBookmarkV2(_article(2));

      expect(_ids(app), [_id(1), _id(3)]);
      expect(disk.ids, [_id(1), _id(3)]);

      final reopened = _launch(server, disk);
      await reopened.loadBookmarks(v2List: true);
      expect(_ids(reopened), [_id(1), _id(3)]);
      expect(reopened.isBookmarked(_article(2)), isFalse);
    });

    test('Clear all deletes every V2 row, including unloaded pages', () async {
      server.seed(List<int>.generate(25, (i) => i + 1));
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);
      expect(app.bookmarks.length, 20);

      expect(await app.clearAllBookmarksV2(), isTrue);
      expect(server.rows, isEmpty);
      expect(server.deleteCalls.toSet().length, 25);
      expect(app.bookmarks, isEmpty);
      expect(disk.ids, isEmpty);

      final reopened = _launch(server, disk);
      await reopened.loadBookmarks(v2List: true);
      expect(reopened.bookmarks, isEmpty);
    });

    test('Clear all keeps only bookmarks whose delete failed', () async {
      server.seed([1, 2, 3]);
      server.failDeletes = {_id(2)};
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      expect(await app.clearAllBookmarksV2(), isFalse);
      expect(server.rows, [_id(2)]);
      expect(_ids(app), [_id(2)]);
      expect(disk.ids, [_id(2)]);
      expect(app.error, isNotNull);
    });
  });

  group('server list is authoritative', () {
    test('explicit empty items replaces stale local copy and persists empty',
        () async {
      disk.seed([1, 2]);
      final app = _launch(server, disk);
      await app.loadBookmarks(v2List: true);

      expect(app.bookmarks, isEmpty);
      expect(app.error, isNull);
      expect(disk.saved, isEmpty);
    });

    test('stale removed IDs in cache are dropped by the server list', () async {
      server.seed([3]);
      disk.seed([1, 2, 3]);
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      expect(_ids(app), [_id(3)]);
      expect(disk.ids, [_id(3)]);
      expect(app.isBookmarked(_article(1)), isFalse);
    });

    test('failed list request keeps the local copy (no false empty)', () async {
      disk.seed([1, 2]);
      server.failList = true;
      final app = _launch(server, disk);
      await app.loadBookmarks(v2List: true);

      expect(_ids(app), [_id(1), _id(2)]);
      expect(app.error, isNotNull);
      expect(disk.ids, [_id(1), _id(2)]);
    });

    test('signed-out V2 load never reads device copies', () async {
      disk.seed([1, 2]);
      final app = _launch(server, disk, loggedIn: false);
      await app.loadBookmarks(v2List: true);

      expect(app.bookmarks, isEmpty);
      expect(server.listCalls, 0);
    });

    test('empty items parse to an empty list; missing items is a failure', () {
      final empty = BookmarkListResponse.tryFromV2Data({
        'items': <dynamic>[],
        'page': 1,
        'limit': 20,
        'hasNextPage': false,
      });
      expect(empty, isNotNull);
      expect(empty!.data, isEmpty);
      expect(BookmarkListResponse.tryFromV2Data({'page': 1}), isNull);
      expect(BookmarkListResponse.tryFromV2Data({'items': null}), isNull);
    });
  });

  group('failures and races', () {
    test('network failure during removal rolls back to the server state',
        () async {
      server.seed([1]);
      server.failDeletes = {_id(1)};
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      await expectLater(app.toggleBookmarkV2(_article(1)), throwsException);
      expect(server.rows, [_id(1)]);
      expect(_ids(app), [_id(1)]);
      expect(app.isBookmarked(_article(1)), isTrue);
      expect(disk.ids, [_id(1)]);

      final reopened = _launch(server, disk);
      await reopened.loadBookmarks(v2List: true);
      expect(_ids(reopened), [_id(1)]);
    });

    test('repeated taps send one DELETE', () async {
      server.seed([1]);
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      server.deleteGate = Completer<void>();
      final first = app.toggleBookmarkV2(_article(1));
      final second = app.toggleBookmarkV2(_article(1));
      final third = app.toggleBookmarkV2(_article(1));
      server.deleteGate!.complete();
      await Future.wait([first, second, third]);

      expect(server.deleteCalls, [_id(1)]);
      expect(server.addCalls, isEmpty);
      expect(app.bookmarks, isEmpty);
      expect(server.rows, isEmpty);
    });

    test('list response read before a delete does not bring the item back',
        () async {
      server.seed([1, 2]);
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      server.listGate = Completer<void>();
      final load = app.loadBookmarks(refresh: true, v2List: true);
      await Future<void>.delayed(Duration.zero);
      await app.toggleBookmarkV2(_article(1));
      expect(server.rows, [_id(2)]);

      server.listGate!.complete();
      await load;

      expect(_ids(app), [_id(2)]);
      expect(disk.ids, [_id(2)]);
      expect(app.isBookmarked(_article(1)), isFalse);

      server.listGate = null;
      final reopened = _launch(server, disk);
      await reopened.loadBookmarks(v2List: true);
      expect(_ids(reopened), [_id(2)]);
    });

    test('list arriving while a delete is in flight keeps the item hidden',
        () async {
      server.seed([1, 2]);
      final app = _launch(server, disk);
      await app.loadBookmarks(refresh: true, v2List: true);

      server.deleteGate = Completer<void>();
      final removal = app.toggleBookmarkV2(_article(1));
      await Future<void>.delayed(Duration.zero);
      await app.loadBookmarks(refresh: true, v2List: true);
      expect(_ids(app), [_id(2)]);
      expect(disk.ids, [_id(2)]);

      server.deleteGate!.complete();
      await removal;
      expect(_ids(app), [_id(2)]);
      expect(server.rows, [_id(2)]);
    });

    test('older load finishing last is ignored', () async {
      server.seed([1]);
      final app = _launch(server, disk);

      server.listGate = Completer<void>();
      final older = app.loadBookmarks(refresh: true, v2List: true);
      await Future<void>.delayed(Duration.zero);
      final olderGate = server.listGate!;

      server.rows.clear();
      server.listGate = null;
      await app.loadBookmarks(refresh: true, v2List: true);
      expect(app.bookmarks, isEmpty);

      olderGate.complete();
      await older;
      expect(app.bookmarks, isEmpty);
      expect(disk.saved, isEmpty);
    });
  });

  group('ids and API semantics', () {
    test('article with only articleId uses the same id for add and delete',
        () async {
      final feedItem = NewsArticle.fromJson({
        'article_id': _id(7),
        'title': 'Feed story',
      });
      final app = _launch(server, disk);
      await app.toggleBookmarkV2(feedItem);
      expect(server.addCalls, [_id(7)]);

      await app.loadBookmarks(refresh: true, v2List: true);
      expect(app.isBookmarked(feedItem), isTrue);

      await app.toggleBookmarkV2(feedItem);
      expect(server.deleteCalls, [_id(7)]);
      expect(server.rows, isEmpty);
      expect(app.isBookmarked(feedItem), isFalse);
    });

    test('404 "Bookmark not found" means already removed; others fail', () {
      bool gone(int status, dynamic data) =>
          BookmarkApiService.isV2BookmarkAlreadyRemoved(
            ApiResponse(
              success: false,
              data: data,
              error: 'x',
              statusCode: status,
            ),
          );
      expect(gone(404, {'success': false, 'message': 'Bookmark not found'}),
          isTrue);
      expect(gone(404, '<pre>Cannot DELETE /api/v2/bookmarks/x</pre>'),
          isFalse);
      expect(gone(400, {'message': 'Invalid newsId'}), isFalse);
      expect(gone(500, {'message': 'Bookmark not found'}), isFalse);
      expect(gone(0, null), isFalse);
    });
  });

  group('V2-only wiring', () {
    test('V2 Bookmarks tab Clear all uses the V2 route; V1 path unchanged', () {
      final tab =
          File('lib/screens/bookmarks/bookmarks_tab.dart').readAsStringSync();
      final dialog = tab.substring(tab.indexOf('void _showClearConfirmation'));
      final v2At = dialog.indexOf('if (useV2)');
      final v2Call = dialog.indexOf('_clearAllV2(provider, messenger)');
      final v1Call = dialog.indexOf('provider.clearAllBookmarks();');
      expect(v2At, greaterThan(0));
      expect(v2Call, greaterThan(v2At));
      expect(v1Call, greaterThan(v2Call));
      expect(tab.contains('provider.clearAllBookmarksV2()'), isTrue);
    });

    test('V2 bookmark code never calls V1 bookmark routes', () {
      final provider =
          File('lib/providers/bookmark_provider.dart').readAsStringSync();
      String body(String start, String end) {
        final s = provider.indexOf(start);
        return provider.substring(s, provider.indexOf(end, s + start.length));
      }

      for (final method in [
        body('Future<bool> toggleBookmarkV2', '// ignore: unused_element'),
        body('Future<bool> clearAllBookmarksV2', 'NewsArticle _v2Snapshot'),
        body('Future<void> _loadBookmarksV2', 'Future<void> _writeV2Local'),
      ]) {
        expect(method.contains('removeAllBookmarks'), isFalse);
        expect(method.contains('.removeBookmark('), isFalse);
        expect(method.contains('getBookmarkList('), isFalse);
        expect(method.contains('StorageService.getAllBookmarks'), isFalse);
      }
    });
  });
}
