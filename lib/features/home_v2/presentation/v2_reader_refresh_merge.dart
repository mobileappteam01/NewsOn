import 'dart:math' as math;

import '../../../data/models/news_article.dart';
import '../../news/domain/news_summary.dart';

/// Where the reader opens after a same-feed refresh.
enum V2RefreshMergeMode {
  /// The reader was near the top: the refreshed feed opens on its first
  /// article.
  top,

  /// The reader was deeper in the feed: every article up to the current one
  /// stays where it was and the refreshed articles follow it.
  inPlace,
}

class V2RefreshMergeResult {
  const V2RefreshMergeResult({
    required this.mode,
    required this.articles,
    required this.index,
    required this.page,
    required this.hasMore,
    required this.newCount,
  });

  final V2RefreshMergeMode mode;
  final List<NewsArticle> articles;
  final int index;
  final int page;
  final bool hasMore;

  /// Page-1 articles that were not in the feed before this refresh.
  final int newCount;
}

/// Reconciles a refreshed Home page 1 (newest first) with the feed on screen.
///
/// Ranking of the refreshed page: unseen articles published within the
/// freshness windows first (window by window, articles new to the feed
/// before already-loaded ones, publishers alternated inside a window), then
/// older unseen articles, then articles the reader has already viewed. Only
/// the order of page-1 articles changes; nothing older is pulled in.
class V2ReaderRefreshMerge {
  V2ReaderRefreshMerge._();

  /// Upper bounds (minutes) of the freshness windows: 0–15, 15–30, 30–60,
  /// 60–120.
  static const List<int> freshnessWindowsMinutes = [15, 30, 60, 120];

  /// Reader positions at or above this index count as "near the top".
  static const int nearTopIndex = 2;

  static V2RefreshMergeResult merge({
    required List<NewsArticle> current,
    required int currentIndex,
    required int currentPage,
    required bool currentHasMore,
    required List<NewsArticle> fresh,
    required int freshPage,
    required bool freshHasMore,
    required Set<String> seenIds,
    required DateTime now,
  }) {
    final freshUnique = _dedupe(fresh);
    final currentIds = {for (final a in current) _id(a)}..remove('');
    final freshIds = {for (final a in freshUnique) _id(a)};
    final ranked = rank(
      freshUnique,
      seenIds: seenIds,
      knownIds: currentIds,
      now: now,
    );
    final newCount = freshUnique
        .where((a) => !currentIds.contains(_id(a)))
        .length;

    // Older loaded pages continue page 1 only when the two overlap; without
    // overlap there is a gap between them, so pagination restarts after
    // page 1 instead.
    final contiguous = freshIds.any(currentIds.contains);
    final tail = contiguous
        ? [
            for (final a in current)
              if (!freshIds.contains(_id(a))) a,
          ]
        : const <NewsArticle>[];
    final page = contiguous ? math.max(currentPage, freshPage) : freshPage;
    final hasMore = contiguous
        ? freshHasMore && (currentPage <= freshPage || currentHasMore)
        : freshHasMore;

    if (current.isEmpty || currentIndex <= nearTopIndex) {
      return V2RefreshMergeResult(
        mode: V2RefreshMergeMode.top,
        articles: _dedupe([...ranked, ...tail]),
        index: 0,
        page: page,
        hasMore: hasMore,
        newCount: newCount,
      );
    }
    final index = currentIndex.clamp(0, current.length - 1);
    return V2RefreshMergeResult(
      mode: V2RefreshMergeMode.inPlace,
      articles: _dedupe([...current.sublist(0, index + 1), ...ranked, ...tail]),
      index: index,
      page: page,
      hasMore: hasMore,
      newCount: newCount,
    );
  }

  /// Orders a refreshed page 1 (backend order: newest first).
  static List<NewsArticle> rank(
    List<NewsArticle> fresh, {
    required Set<String> seenIds,
    required Set<String> knownIds,
    required DateTime now,
  }) {
    final windows = freshnessWindowsMinutes.length;
    final newInWindow = List.generate(windows, (_) => <NewsArticle>[]);
    final knownInWindow = List.generate(windows, (_) => <NewsArticle>[]);
    final olderUnseen = <NewsArticle>[];
    final seen = <NewsArticle>[];
    for (final a in fresh) {
      final id = _id(a);
      if (seenIds.contains(id)) {
        seen.add(a);
        continue;
      }
      final window = freshnessWindow(a, now);
      if (window == null) {
        olderUnseen.add(a);
      } else if (knownIds.contains(id)) {
        knownInWindow[window].add(a);
      } else {
        newInWindow[window].add(a);
      }
    }
    return [
      for (var w = 0; w < windows; w++) ...[
        ..._alternatePublishers(newInWindow[w]),
        ..._alternatePublishers(knownInWindow[w]),
      ],
      ...olderUnseen,
      ...seen,
    ];
  }

  /// Index into [freshnessWindowsMinutes], or null when the article is older
  /// than the last window or has no parsable publish time.
  static int? freshnessWindow(NewsArticle article, DateTime now) {
    final raw = article.pubDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    final published = DateTime.tryParse(raw);
    if (published == null) return null;
    final age = now.difference(published);
    for (var i = 0; i < freshnessWindowsMinutes.length; i++) {
      final limit = Duration(minutes: freshnessWindowsMinutes[i]);
      final last = i == freshnessWindowsMinutes.length - 1;
      if (last ? age <= limit : age < limit) return i;
    }
    return null;
  }

  /// Stable reorder that avoids the same publisher twice in a row when
  /// another publisher is available.
  static List<NewsArticle> _alternatePublishers(List<NewsArticle> items) {
    if (items.length < 3) return items;
    final remaining = List<NewsArticle>.of(items);
    final out = <NewsArticle>[];
    String? last;
    while (remaining.isNotEmpty) {
      var pick = remaining.indexWhere((a) {
        final key = a.publisherRouteKey;
        return key.isEmpty || key != last;
      });
      if (pick < 0) pick = 0;
      final next = remaining.removeAt(pick);
      out.add(next);
      last = next.publisherRouteKey;
    }
    return out;
  }

  static String _id(NewsArticle a) => a.analyticsNewsId.trim();

  static List<NewsArticle> _dedupe(List<NewsArticle> items) {
    final seen = <String>{};
    return [
      for (final a in items)
        if (_id(a).isNotEmpty && seen.add(_id(a))) a,
    ];
  }
}
