import '../../../data/models/news_article.dart';

/// Bookmark list after a refresh. Error never becomes an empty success.
enum BookmarkListPhase { loading, withData, empty, error }

class BookmarkRefreshResult {
  const BookmarkRefreshResult._({
    required this.items,
    required this.phase,
    this.error,
  });

  final List<NewsArticle> items;
  final BookmarkListPhase phase;
  final String? error;

  bool get isError => phase == BookmarkListPhase.error;

  /// Authoritative backend page. An empty list is a successful empty state.
  factory BookmarkRefreshResult.success(List<NewsArticle> authoritative) {
    final items = List<NewsArticle>.from(authoritative);
    return BookmarkRefreshResult._(
      items: items,
      phase: items.isEmpty ? BookmarkListPhase.empty : BookmarkListPhase.withData,
    );
  }

  /// Failed reload. [visible] stays on screen.
  factory BookmarkRefreshResult.failure({
    required List<NewsArticle> visible,
    required String error,
  }) {
    return BookmarkRefreshResult._(
      items: List<NewsArticle>.from(visible),
      phase: BookmarkListPhase.error,
      error: error,
    );
  }
}

/// One in-flight toggle per article. A second tap does not start another request.
class BookmarkToggleGuard {
  final Set<String> _inFlight = <String>{};

  bool tryBegin(String articleId) {
    final id = articleId.trim();
    if (id.isEmpty) return false;
    return _inFlight.add(id);
  }

  void end(String articleId) {
    _inFlight.remove(articleId.trim());
  }

  bool isInFlight(String articleId) => _inFlight.contains(articleId.trim());
}

/// Optimistic bookmark list edits with rollback snapshots.
class BookmarkListEdits {
  static List<NewsArticle> add(List<NewsArticle> items, NewsArticle article) {
    final id = _id(article);
    final next = items.where((a) => _id(a) != id).toList();
    return [article, ...next];
  }

  static List<NewsArticle> remove(List<NewsArticle> items, String articleId) {
    final id = articleId.trim();
    return items.where((a) => _id(a) != id).toList();
  }

  static String _id(NewsArticle article) =>
      (article.newsId ?? article.articleId ?? article.title).trim();
}
