import 'v2_reader_controller.dart';
import 'v2_reader_display_page.dart';

enum V2PagerChange {
  none,
  newFeed,
  feedMerged,
  feedEdited,
  pagesAdded,
  pagesDeferred,
}

/// Which TurnablePage book Home shows and the display page it opens on.
///
/// TurnablePage fixes its page collection when the book is created, so a new
/// feed needs a new book ([epoch] is the pager key), never a jump inside the
/// old one. Pages appended by load-more keep the same book, which grows in
/// place.
class V2ReaderPagerSession {
  int _epoch = 0;
  int _seenFeedSession = 0;
  int _seenFeedMerge = 0;
  int _seenFeedEdit = 0;
  int _bookPageCount = 0;

  /// Key of the current book.
  int get epoch => _epoch;

  /// Display page (ads included) of the current book.
  int displayIndex = 0;

  /// Display pages the current book was created with.
  int get bookPageCount => _bookPageCount;

  /// Applies controller changes. One page-1 replacement is one [epoch] step
  /// and starts at the first page; a refresh merged around the reader's
  /// position and a hidden/restored article rebuild the book on the
  /// controller's current article; appended pages keep the book and
  /// [displayIndex]. While [turning], appended pages wait
  /// ([V2PagerChange.pagesDeferred]) so a page turn is not cut off.
  V2PagerChange sync(
    V2ReaderController controller, {
    required bool adsEnabled,
    bool turning = false,
  }) {
    final pages = V2ReaderDisplayPages.build(
      controller.state.articles.length,
      adsEnabled: adsEnabled,
    );
    if (controller.feedSessionRevision != _seenFeedSession) {
      _seenFeedSession = controller.feedSessionRevision;
      // The new feed replaces any merge or article edit of the previous one.
      _seenFeedMerge = controller.feedMergeRevision;
      _seenFeedEdit = controller.feedEditRevision;
      _epoch++;
      _bookPageCount = pages.length;
      displayIndex = 0;
      return V2PagerChange.newFeed;
    }
    if (controller.feedMergeRevision != _seenFeedMerge) {
      _seenFeedMerge = controller.feedMergeRevision;
      _seenFeedEdit = controller.feedEditRevision;
      _epoch++;
      _bookPageCount = pages.length;
      displayIndex = V2ReaderDisplayPages.displayIndexOf(
        pages,
        controller.state.index,
      );
      return V2PagerChange.feedMerged;
    }
    if (controller.feedEditRevision != _seenFeedEdit) {
      _seenFeedEdit = controller.feedEditRevision;
      _epoch++;
      _bookPageCount = pages.length;
      displayIndex = V2ReaderDisplayPages.displayIndexOf(
        pages,
        controller.state.index,
      );
      return V2PagerChange.feedEdited;
    }
    if (pages.length > _bookPageCount && _bookPageCount > 0) {
      if (turning) return V2PagerChange.pagesDeferred;
      // Appended pages come after every existing page (ads included), so
      // [displayIndex] still shows the same article or ad, and the current
      // book grows in place (see V2PageTurn).
      _bookPageCount = pages.length;
      return V2PagerChange.pagesAdded;
    }
    return V2PagerChange.none;
  }
}
