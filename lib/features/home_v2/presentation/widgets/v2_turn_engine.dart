// turnable_page's license forbids copying or patching the package, so its
// gesture bugs are fixed through the runtime objects it exposes. These
// imports pin the internals of the exact version in pubspec.yaml.
// ignore_for_file: implementation_imports
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:turnable_page/src/collection/page_collection_impl.dart';
import 'package:turnable_page/src/enums/book_orientation.dart';
import 'package:turnable_page/src/enums/flip_direction.dart';
import 'package:turnable_page/src/enums/flipping_state.dart';
import 'package:turnable_page/src/flip/flip_process.dart';
import 'package:turnable_page/src/model/point.dart';
import 'package:turnable_page/src/page/page_flip.dart';
import 'package:turnable_page/src/render/render_turnable_book.dart';

export 'package:turnable_page/src/page/page_flip.dart' show PageFlip;

/// V2 control of a turnable_page book.
abstract final class V2TurnEngine {
  /// Uses [V2FlipProcess] for drags on [book]. No-op until the book has been
  /// laid out, while a turn is in progress, or when already installed.
  static void install(PageFlip book) {
    if (!book.hasRender || book.flipProcess is V2FlipProcess) return;
    if (book.getState() != FlippingState.read) return;
    book.flipProcess = V2FlipProcess(book, book.render);
  }

  /// A turn animation (released drag or arrow button) is running.
  static bool isAnimating(PageFlip book) =>
      book.hasRender &&
      !book.isUserTouch &&
      book.getState() != FlippingState.read;

  /// [PageFlipEvent.changeState] data for a book back at rest.
  static bool isRestState(Object? state) => state == FlippingState.read;

  /// Jumps a running turn animation to its end, committing its page change,
  /// so the next touch starts on the page that is about to be shown.
  static void settle(PageFlip book) {
    if (isAnimating(book)) book.abortFlip();
  }

  /// Extends [book] to [pageCount] pages in place, staying on its current
  /// page. turnable_page fixes the page list when a book is created, so
  /// without this appended pages need a new book. Returns false when the
  /// book cannot grow yet (mid-turn, or its new pages are not built).
  static bool grow(PageFlip book, int pageCount) {
    final render = book.renderNullable;
    if (render is! RenderTurnableBook) return false;
    if (book.getState() != FlippingState.read || book.isUserTouch) {
      return false;
    }
    if (book.getPageCount() >= pageCount) return true;
    if (render.childCount < pageCount) return false;
    final current = book.getCurrentPageIndex();
    final pages = PageCollectionImpl(book, render, pageCount)..loadBookPages();
    render.collection = pages;
    book.pages = pages;
    pages.show(current);
    return true;
  }
}

/// turnable_page's flip process with two drag fixes for the single-page
/// (portrait) book:
///
/// * Direction comes from the swipe: left turns forward, right turns back.
///   The package picks it from where the finger lands (left 40% of the page
///   is "back"), so a left swipe started on the left side turned back or
///   did nothing. When the landing side disagrees with the swipe, the drag
///   is tracked from the page edge that direction turns from.
/// * A drag never starts on top of an unfinished turn: the previous turn is
///   finished first, so its animation frames and end callback cannot write
///   into the new drag's calculation.
class V2FlipProcess extends FlipProcess {
  V2FlipProcess(super.app, super.render);

  Point? _origin;
  double _shift = 0;

  @override
  void fold(Point globalPos) {
    if (render.getOrientation() != BookOrientation.portrait) {
      super.fold(globalPos);
      return;
    }
    if (!app.isUserMove) {
      // PageFlip.startUserTouch: a new drag, at its touch-down point.
      render.finishAnimation();
      if (calc != null) abortFlip();
      _origin = globalPos;
      _shift = 0;
      return;
    }
    final origin = _origin;
    if (origin == null) {
      super.fold(globalPos);
      return;
    }
    if (calc == null && !_begin(origin, globalPos.x - origin.x)) return;
    setState(FlippingState.userFold);
    doCalculation(
      render.convertToPage(Point(globalPos.x + _shift, globalPos.y)),
    );
  }

  bool _begin(Point origin, double dx) {
    final landed = getDirectionByPoint(render.convertToBook(origin));
    final direction = dx.abs() < 1
        ? landed
        : dx < 0
            ? FlipDirection.forward
            : FlipDirection.back;
    if (!checkDirection(direction)) return false;
    var shift = 0.0;
    if (direction != landed) {
      final rect = getBoundsRect();
      final edge = direction == FlipDirection.forward
          ? rect.left + rect.width - 1
          : rect.left + rect.pageWidth;
      shift = edge - origin.x;
    }
    if (!start(Point(origin.x + shift, origin.y))) return false;
    _shift = shift;
    return true;
  }
}

/// Sits directly above a turnable_page book.
///
/// * A touch that lands while a turn is still animating first calls
///   [beforeTouch] (which settles the turn), so the touch, and any page
///   widget it hits, belongs to the page about to be on screen.
/// * While one finger is on the book, further fingers do not reach it; the
///   package keeps a single drag state that a second finger would reset.
class V2TurnGate extends SingleChildRenderObjectWidget {
  const V2TurnGate({super.key, required this.beforeTouch, super.child});

  final VoidCallback beforeTouch;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderV2TurnGate(beforeTouch);

  @override
  void updateRenderObject(BuildContext context, RenderV2TurnGate renderObject) {
    renderObject.beforeTouch = beforeTouch;
  }
}

/// Render object for [V2TurnGate].
class RenderV2TurnGate extends RenderProxyBox {
  RenderV2TurnGate(this.beforeTouch);

  VoidCallback beforeTouch;
  final Set<int> _pointers = <int>{};

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || _pointers.isNotEmpty) return false;
    beforeTouch();
    return super.hitTest(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pointers.add(event.pointer);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    }
  }

  @override
  void detach() {
    _pointers.clear();
    super.detach();
  }
}
