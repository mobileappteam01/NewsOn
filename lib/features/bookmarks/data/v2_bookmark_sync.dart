import '../../../data/models/news_article.dart';
import '../../../data/services/bookmark_api_service.dart';
import '../../../data/services/storage_service.dart';

/// V2 bookmark routes on the V2 host. The server list is the source of truth.
abstract class V2BookmarkRemote {
  /// `POST /api/v2/bookmarks`. Throws when the bookmark was not stored.
  Future<void> addV2Bookmark(String newsId);

  /// `DELETE /api/v2/bookmarks/{newsId}`. Returns normally when the server
  /// no longer holds the bookmark (including "already removed").
  Future<void> deleteV2Bookmark(String newsId);

  /// `GET /api/v2/bookmarks`. Null only for transport/server/parse failures;
  /// an explicit `items: []` is an empty response, never null.
  Future<BookmarkListResponse?> tryGetV2BookmarkList({
    int page = 1,
    int limit = 20,
  });
}

/// Device copy of the last V2 bookmark list. Written from the server list and
/// from confirmed writes only; an empty list is stored as empty.
abstract class V2BookmarkStore {
  List<NewsArticle> readList();
  Future<void> writeList(List<NewsArticle> bookmarks);
}

class StorageV2BookmarkStore implements V2BookmarkStore {
  const StorageV2BookmarkStore();

  @override
  List<NewsArticle> readList() => StorageService.getBookmarkListCache();

  @override
  Future<void> writeList(List<NewsArticle> bookmarks) async {
    await StorageService.saveBookmarkListCache(bookmarks);
    await StorageService.replaceAllBookmarks(bookmarks);
  }
}

String? v2BookmarkId(NewsArticle article) {
  final id = (article.newsId ?? article.articleId)?.trim();
  if (id == null || id.isEmpty) return null;
  return id;
}

class V2BookmarkEdit {
  V2BookmarkEdit._({required this.removed, this.article});

  final bool removed;
  final NewsArticle? article;

  /// Clock tick when the server confirmed this write; null while in flight.
  int? settledAt;
}

/// Local V2 bookmark writes a list request may not have seen.
///
/// A list request that started before a write was confirmed can return the
/// pre-write server state. [reconcile] re-applies those writes to the
/// response, so a stale list never brings back a removed bookmark.
class V2BookmarkPendingEdits {
  int _clock = 0;
  final Map<String, V2BookmarkEdit> _edits = <String, V2BookmarkEdit>{};

  int beginLoad() => ++_clock;

  V2BookmarkEdit beginRemove(String id) {
    final edit = V2BookmarkEdit._(removed: true);
    _edits[id.trim()] = edit;
    return edit;
  }

  V2BookmarkEdit beginAdd(String id, NewsArticle article) {
    final edit = V2BookmarkEdit._(removed: false, article: article);
    _edits[id.trim()] = edit;
    return edit;
  }

  void settle(String id, V2BookmarkEdit edit) {
    if (identical(_edits[id.trim()], edit)) edit.settledAt = ++_clock;
  }

  void cancel(String id, V2BookmarkEdit edit) {
    if (identical(_edits[id.trim()], edit)) _edits.remove(id.trim());
  }

  bool isAddInFlight(String id) {
    final edit = _edits[id.trim()];
    return edit != null && !edit.removed && edit.settledAt == null;
  }

  Set<String> get removedIds => {
        for (final e in _edits.entries)
          if (e.value.removed) e.key,
      };

  bool get isEmpty => _edits.isEmpty;

  /// [server] with every write not yet visible to a load started at
  /// [loadStartedAt] applied. Writes confirmed before that load started are
  /// already in [server] and are forgotten.
  List<NewsArticle> reconcile(List<NewsArticle> server, int loadStartedAt) {
    final out = _apply(server, loadStartedAt);
    _edits.removeWhere(
      (_, e) => e.settledAt != null && e.settledAt! <= loadStartedAt,
    );
    return out;
  }

  /// [list] with every known write applied. Used for the cached list painted
  /// before the network answers.
  List<NewsArticle> applyAll(List<NewsArticle> list) => _apply(list, -1);

  List<NewsArticle> _apply(List<NewsArticle> list, int loadStartedAt) {
    final unseen = <String, V2BookmarkEdit>{
      for (final e in _edits.entries)
        if (e.value.settledAt == null || e.value.settledAt! > loadStartedAt)
          e.key: e.value,
    };
    if (unseen.isEmpty) return List<NewsArticle>.from(list);
    final out = list.where((a) {
      final id = v2BookmarkId(a);
      return id == null || unseen[id]?.removed != true;
    }).toList();
    final present = {for (final a in out) v2BookmarkId(a)};
    for (final e in unseen.entries) {
      final article = e.value.article;
      if (!e.value.removed && article != null && !present.contains(e.key)) {
        out.insert(0, article);
      }
    }
    return out;
  }
}
