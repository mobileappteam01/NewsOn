import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/models/region_model.dart';
import 'package:newson/features/article_feedback/domain/v2_article_feedback.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_controller.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_display_page.dart';
import 'package:newson/features/news/data/v2_feed_item_mapper.dart';

NewsArticle _article(String id) =>
    NewsArticle(title: 'Story $id', articleId: id);

List<String> _ids(V2ReaderController c) =>
    [for (final a in c.state.articles) a.articleId!];

/// `GET /api/v2/home` stand-in. [pages] maps page number to article ids;
/// set [gate] to hold the next response until it is completed.
class _Backend {
  Map<int, List<String>> pages = {};
  Set<int> morePages = {};
  Completer<void>? gate;
  final List<({int page, HomeFilterState filter})> requests = [];

  Future<V2FeedPage> call({
    required int page,
    required int limit,
    required String language,
    required HomeFilterState filter,
  }) async {
    requests.add((page: page, filter: filter));
    final hold = gate;
    if (hold != null) {
      gate = null;
      await hold.future;
    }
    return V2FeedPage(
      articles: [for (final id in pages[page] ?? const <String>[]) _article(id)],
      page: page,
      hasMore: morePages.contains(page),
    );
  }
}

/// Controllable `POST /not-interested`.
class _Sender {
  final List<String> sent = [];
  final List<Completer<void>> pending = [];

  Future<void> call(String articleId) {
    sent.add(articleId);
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }

  void succeed() => pending.removeAt(0).complete();
  void fail() => pending.removeAt(0).completeError(Exception('HTTP 500'));
}

void main() {
  late _Backend backend;
  late _Sender sender;
  late HomeFilterState filter;
  late V2ReaderController reader;

  setUp(() {
    backend = _Backend()
      ..pages = {
        1: [for (var i = 0; i < 6; i++) 'a$i'],
        2: [for (var i = 6; i < 12; i++) 'a$i'],
      };
    sender = _Sender();
    filter = const HomeFilterState();
    reader = V2ReaderController(
      newsLanguageCode: () => 'en',
      appliedRegion: () => const SavedRegion(),
      homeFilter: () => filter,
      homeLoader: backend.call,
      notInterested: sender.call,
    );
  });

  tearDown(() => reader.dispose());

  Future<void> settle() => pumpEventQueue();

  test('removes the article immediately, before the server answers', () async {
    await reader.loadInitial();
    expect(reader.state.current!.articleId, 'a0');
    final revision = reader.feedEditRevision;

    final result = reader.hideNotInterested(reader.state.current!);

    expect(_ids(reader), isNot(contains('a0')));
    expect(reader.state.current!.articleId, 'a1');
    expect(reader.isHidePending('a0'), isTrue);
    expect(reader.feedEditRevision, revision + 1);
    expect(sender.sent, ['a0']);

    sender.succeed();
    expect(await result, V2HideResult.hidden);
    expect(reader.isHidePending('a0'), isFalse);
    expect(_ids(reader), isNot(contains('a0')));
  });

  test('the next article takes the place of a mid-feed article', () async {
    await reader.loadInitial();
    reader.setIndex(3);
    unawaited(reader.hideNotInterested(reader.state.current!));

    expect(reader.state.index, 3);
    expect(reader.state.current!.articleId, 'a4');
    sender.succeed();
  });

  test('failure restores the article at its position', () async {
    await reader.loadInitial();
    reader.setIndex(2);
    final result = reader.hideNotInterested(reader.state.current!);
    expect(reader.state.current!.articleId, 'a3');

    sender.fail();
    expect(await result, V2HideResult.failed);

    expect(_ids(reader), ['a0', 'a1', 'a2', 'a3', 'a4', 'a5']);
    expect(reader.state.current!.articleId, 'a2');
    expect(reader.isHidePending('a2'), isFalse);
  });

  test('restore keeps the article the user moved on to', () async {
    await reader.loadInitial();
    final result = reader.hideNotInterested(reader.state.current!);
    reader.setIndex(2); // now on a3
    sender.fail();
    await result;

    expect(reader.state.current!.articleId, 'a3');
    expect(_ids(reader).first, 'a0');
  });

  test('duplicate taps send one request', () async {
    await reader.loadInitial();
    final article = reader.state.current!;

    final first = reader.hideNotInterested(article);
    final second = await reader.hideNotInterested(article);
    expect(second, V2HideResult.duplicate);
    expect(sender.sent, ['a0']);

    sender.succeed();
    await first;
    expect(await reader.hideNotInterested(article), V2HideResult.duplicate);
    expect(sender.sent, ['a0']);
  });

  test('article outside the feed is not sent', () async {
    await reader.loadInitial();
    expect(
      await reader.hideNotInterested(_article('zzz')),
      V2HideResult.unavailable,
    );
    expect(
      await reader.hideNotInterested(NewsArticle(title: 'no id')),
      V2HideResult.unavailable,
    );
    expect(sender.sent, isEmpty);
  });

  test('loadMore cannot reinsert a hidden article (pending or accepted)',
      () async {
    backend.morePages = {1};
    // Server has not processed the hide yet and returns it again on page 2.
    backend.pages[2] = ['a0', 'a6', 'a7', 'a1'];
    await reader.loadInitial();
    unawaited(reader.hideNotInterested(reader.state.current!));

    reader.unawaitedLoadMore();
    await settle();

    expect(_ids(reader), ['a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7']);
    expect(_ids(reader).toSet().length, _ids(reader).length);

    sender.succeed();
    await settle();
    expect(_ids(reader), isNot(contains('a0')));
  });

  test('refresh cannot reinsert a hidden article (pending or accepted)',
      () async {
    await reader.loadInitial();
    unawaited(reader.hideNotInterested(reader.state.current!));

    await reader.refresh();
    // a1 was on screen when the refresh landed: ranked after unseen ones.
    expect(_ids(reader), ['a2', 'a3', 'a4', 'a5', 'a1']);

    sender.succeed();
    await settle();
    await reader.refresh();
    expect(_ids(reader), ['a3', 'a4', 'a5', 'a1', 'a2']);
    expect(_ids(reader), isNot(contains('a0')));
  });

  test('a page-1 response requested before the hide cannot reinsert it',
      () async {
    await reader.loadInitial();
    final gate = Completer<void>();
    backend.gate = gate;
    final refresh = reader.refresh();

    unawaited(reader.hideNotInterested(reader.state.current!));
    gate.complete();
    await refresh;

    expect(_ids(reader), isNot(contains('a0')));
    expect(reader.state.current, isNotNull);
    sender.succeed();
  });

  test('failure after a refresh restores once, with no duplicate ids',
      () async {
    await reader.loadInitial();
    final result = reader.hideNotInterested(reader.state.current!);
    await reader.refresh();

    sender.fail();
    await result;

    expect(_ids(reader).where((id) => id == 'a0'), hasLength(1));
    expect(_ids(reader).toSet().length, _ids(reader).length);
  });

  test('failure after switching filters does not insert into the new feed',
      () async {
    await reader.loadInitial();
    final result = reader.hideNotInterested(reader.state.current!);

    filter = const HomeFilterState(selectedCategorySlugs: ['sports']);
    backend.pages[1] = ['s1', 's2'];
    await reader.refresh();

    sender.fail();
    await result;
    expect(_ids(reader), ['s1', 's2']);
  });

  test('hiding the only article reloads instead of leaving a blank page',
      () async {
    backend.pages = {
      1: ['only'],
    };
    await reader.loadInitial();
    expect(_ids(reader), ['only']);

    backend.pages[1] = ['only', 'b1', 'b2'];
    final gate = Completer<void>();
    backend.gate = gate;
    unawaited(reader.hideNotInterested(reader.state.current!));

    // Reload in progress: loading state, never "ready" with nothing to show.
    expect(reader.state.status, V2ReaderStatus.loading);
    gate.complete();
    await settle();

    expect(reader.state.status, V2ReaderStatus.ready);
    expect(_ids(reader), ['b1', 'b2']);
    sender.succeed();
  });

  test('display index follows the current article across ad pages', () {
    final pages = V2ReaderDisplayPages.build(9, adsEnabled: true);
    // a0 a1 a2 a3 [ad] a4 a5 a6 a7 [ad] a8
    expect(V2ReaderDisplayPages.displayIndexOf(pages, 0), 0);
    expect(V2ReaderDisplayPages.displayIndexOf(pages, 4), 5);
    expect(V2ReaderDisplayPages.displayIndexOf(pages, 8), 10);
    expect(V2ReaderDisplayPages.displayIndexOf(pages, 99), 0);
    final noAds = V2ReaderDisplayPages.build(9, adsEnabled: false);
    expect(V2ReaderDisplayPages.displayIndexOf(noAds, 4), 4);
  });

  test('Home wires ⋮ and the V2 sender into the reader', () {
    final home = File(
      'lib/features/home_v2/presentation/v2_reader_home.dart',
    ).readAsStringSync();
    expect(home, contains('notInterested: _feedback.api.markNotInterested'));
    expect(home, contains('onMore: () => _openArticleMenu(current)'));
    expect(home, contains('hide: _controller.hideNotInterested'));
    expect(home, contains('_pager.sync('));
    final pager = File(
      'lib/features/home_v2/presentation/v2_reader_pager_session.dart',
    ).readAsStringSync();
    expect(pager, contains('controller.feedEditRevision'));
  });

  test('response arriving after dispose does not throw', () async {
    await reader.loadInitial();
    final result = reader.hideNotInterested(reader.state.current!);
    reader.dispose();
    sender.fail();
    expect(await result, V2HideResult.failed);
    // tearDown disposes again; recreate so it has something to dispose.
    reader = V2ReaderController(
      newsLanguageCode: () => 'en',
      appliedRegion: () => const SavedRegion(),
    );
  });
}
