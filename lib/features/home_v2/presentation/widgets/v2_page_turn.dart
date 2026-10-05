import 'dart:async';

import 'package:flutter/material.dart';
import 'package:turnable_page/turnable_page.dart';

import 'v2_turn_engine.dart';

/// V2 reader pager backed by [TurnablePage] (realistic paper curl).
///
/// Product gesture (LTR book):
/// - Swipe **left** → next article
/// - Swipe **right** → previous article
///
/// Uses [TextDirection.ltr] so TurnablePage’s natural book direction matches
/// that mapping. Do **not** add horizontal mirror transforms.
///
/// A larger [itemCount] for the same widget (load-more) grows the current
/// book in place once no turn is in progress.
class V2PageTurn extends StatefulWidget {
  const V2PageTurn({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.index,
    required this.itemBuilder,
    required this.onIndexChanged,
    this.canGoNext = true,
    this.canGoPrevious = true,
  });

  final PageFlipController controller;
  final int itemCount;
  final int index;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onIndexChanged;
  final bool canGoNext;
  final bool canGoPrevious;

  /// Corner zone size as a fraction of the page diagonal. A touch starting in
  /// a corner zone is claimed by the page curl after 10px of movement in any
  /// direction (vertical included), before a scroll view's drag slop, and
  /// never reaches the page content. Kept to the physical page tips so pulls
  /// to refresh and article scrolls near the top corners are not captured;
  /// horizontal swipes turn pages from anywhere on the page.
  static const double cornerTriggerAreaSize = 0.04;

  /// True while the book attached to [controller] is being dragged or is
  /// animating a turn. Only call after a [V2PageTurn] using [controller] has
  /// been built (the controller is attached when its book is created).
  static bool isTurning(PageFlipController controller) =>
      (controller.pageFlipInstance?.getState()?.name ?? 'read') != 'read';

  @override
  State<V2PageTurn> createState() => _V2PageTurnState();
}

class _V2PageTurnState extends State<V2PageTurn> {
  PageFlip? _waitingBook;

  PageFlip? get _book {
    final book = widget.controller.pageFlipInstance;
    return book != null && book.hasRender ? book : null;
  }

  void _beforeTouch() {
    final book = _book;
    if (book == null) return;
    V2TurnEngine.settle(book);
    V2TurnEngine.install(book);
  }

  @override
  void didUpdateWidget(V2PageTurn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount > oldWidget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _grow());
    }
  }

  void _grow() {
    final book = mounted ? _book : null;
    if (book == null || book.getPageCount() >= widget.itemCount) return;
    if (V2TurnEngine.grow(book, widget.itemCount)) return;
    if (V2PageTurn.isTurning(widget.controller)) {
      _growAfterTurn(book);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _grow());
    }
  }

  void _growAfterTurn(PageFlip book) {
    if (_waitingBook != null) return;
    _waitingBook = book;
    book.on(PageFlipEvent.changeState, _onBookState);
  }

  void _onBookState(WidgetEvent event) {
    if (!V2TurnEngine.isRestState(event.data)) return;
    _stopWaiting();
    scheduleMicrotask(_grow);
  }

  void _stopWaiting() {
    _waitingBook?.off(PageFlipEvent.changeState, _onBookState);
    _waitingBook = null;
  }

  @override
  void dispose() {
    _stopWaiting();
    super.dispose();
  }

  void _onPageChanged(int leftIndex, int rightIndex) {
    final next = leftIndex;
    final index = widget.index;
    if (next < 0 || next >= widget.itemCount) return;
    if (next == index) return;
    if (next > index && !widget.canGoNext) return;
    if (next < index && !widget.canGoPrevious) return;
    widget.onIndexChanged(next);
  }

  PaperBoundaryDecoration _paperEdge(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return PaperBoundaryDecoration.custom(
      baseColor: isDark ? const Color(0xFF1C1915) : const Color(0xFFF5EBDC),
      shadowColor: Colors.black,
      borderColor: isDark ? const Color(0xFF3A342C) : const Color(0xFFD2C2A6),
      borderRadius: 3,
      borderWidth: 0.35,
      shadowBlurRadius: 10,
      shadowOpacity: isDark ? 0.35 : 0.16,
      baseOpacity: 0.22,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.itemCount;
    if (itemCount <= 0) return const SizedBox.shrink();

    final start = widget.index.clamp(0, itemCount - 1);
    final brightness = Theme.of(context).brightness;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the reading stage; tiny inset keeps a natural paper edge/shadow.
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final pageW = maxW * 0.965;
        final pageH = maxH;
        final aspectRatio = pageH > 0 ? pageW / pageH : 2 / 3;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: pageW,
            height: pageH,
            child: V2TurnGate(
              beforeTouch: _beforeTouch,
              child: TurnablePage(
                controller: widget.controller,
                pageCount: itemCount,
                pageViewMode: PageViewMode.single,
                paperBoundaryDecoration: _paperEdge(brightness),
                textDirection: TextDirection.ltr,
                aspectRatio: aspectRatio,
                settings: FlipSettings(
                  startPageIndex: start,
                  flippingTime: 680,
                  swipeDistance: 70,
                  cornerTriggerAreaSize: V2PageTurn.cornerTriggerAreaSize,
                  drawShadow: true,
                  showCenterShadow: true,
                  enableEasing: true,
                  enableInertia: true,
                  mobileScrollSupport: true,
                  swipeAngleThreshold: 1.45,
                ),
                onPageChanged: _onPageChanged,
                builder: (context, pageIndex, pageConstraints) {
                  return widget.itemBuilder(context, pageIndex);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
