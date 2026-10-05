import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_page_turn.dart';
import 'package:turnable_page/turnable_page.dart';

/// Hosts a [V2PageTurn] the way Home does: the parent owns the page index
/// and rebuilds with it on every page change.
class _Book extends StatefulWidget {
  const _Book({required this.flip, required this.pages, this.start = 0});

  final PageFlipController flip;
  final int pages;
  final int start;

  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> {
  late int index = widget.start;
  late int pages = widget.pages;
  final changes = <int>[];

  void grow(int to) => setState(() => pages = to);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 400,
        height: 700,
        child: V2PageTurn(
          controller: widget.flip,
          itemCount: pages,
          index: index,
          onIndexChanged: (i) => setState(() {
            changes.add(i);
            index = i;
          }),
          itemBuilder: (context, i) => ColoredBox(
            key: ValueKey('page-$i'),
            color: Colors.white,
            child: Center(child: Text('page $i')),
          ),
        ),
      ),
    );
  }
}

Future<_BookState> _pump(
  WidgetTester tester,
  PageFlipController flip, {
  int pages = 8,
  int start = 0,
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: _Book(flip: flip, pages: pages, start: start)),
    ),
  );
  await tester.pump();
  return tester.state<_BookState>(find.byType(_Book));
}

Rect _page(WidgetTester tester) => tester.getRect(find.byType(TurnablePage));

/// Quick horizontal swipe. [from] is the touch-down x as a fraction of the
/// page width; [left] swipes toward the left edge (next page).
Future<void> _swipe(
  WidgetTester tester, {
  required bool left,
  double from = 0.5,
  double distance = 0.45,
  int ms = 120,
}) async {
  final box = _page(tester);
  final start = Offset(box.left + box.width * from, box.center.dy);
  final dx = (left ? -1 : 1) * box.width * distance;
  await tester.timedDragFrom(start, Offset(dx, 0), Duration(milliseconds: ms));
}

Future<void> _frames(WidgetTester tester, [int n = 1]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _settle(WidgetTester tester) => _frames(tester, 90);

void _expectSettled(_BookState book, PageFlipController flip, int page) {
  expect(V2PageTurn.isTurning(flip), isFalse, reason: 'turn finished');
  expect(flip.currentPageIndex, page, reason: 'book page');
  expect(book.index, page, reason: 'Home index matches the book');
}

void main() {
  group('direction follows the swipe, not where it started', () {
    testWidgets('left swipe from the left side of the page goes next',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 3);
      await _swipe(tester, left: true, from: 0.25);
      await _settle(tester);
      _expectSettled(book, flip, 4);
      expect(book.changes, [4]);
    });

    testWidgets('right swipe from the right side of the page goes back',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 3);
      await _swipe(tester, left: false, from: 0.75);
      await _settle(tester);
      _expectSettled(book, flip, 2);
      expect(book.changes, [2]);
    });

    testWidgets('usual swipes still turn both ways', (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 3);
      await _swipe(tester, left: true, from: 0.85);
      await _settle(tester);
      _expectSettled(book, flip, 4);
      await _swipe(tester, left: false, from: 0.2);
      await _settle(tester);
      _expectSettled(book, flip, 3);
      expect(book.changes, [4, 3]);
    });

    testWidgets('right swipe on the first page and left swipe on the last '
        'page stay put', (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, pages: 3);
      await _swipe(tester, left: false, from: 0.75);
      await _settle(tester);
      _expectSettled(book, flip, 0);
      flip.jumpToPage(2);
      await _frames(tester, 3);
      await _swipe(tester, left: true, from: 0.25);
      await _settle(tester);
      _expectSettled(book, flip, 2);
    });
  });

  group('a new swipe during a turn animation', () {
    testWidgets('rapid forward swipes each turn one page', (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip);
      for (var i = 0; i < 4; i++) {
        await _swipe(tester, left: true, from: i.isEven ? 0.8 : 0.3);
        await _frames(tester, 3); // next swipe lands mid-animation
      }
      await _settle(tester);
      _expectSettled(book, flip, 4);
      expect(book.changes, [1, 2, 3, 4]);
    });

    testWidgets('rapid backward swipes each turn one page', (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 6);
      for (var i = 0; i < 4; i++) {
        await _swipe(tester, left: false, from: i.isEven ? 0.2 : 0.7);
        await _frames(tester, 3);
      }
      await _settle(tester);
      _expectSettled(book, flip, 2);
      expect(book.changes, [5, 4, 3, 2]);
    });

    testWidgets('forward then immediately backward returns to the page',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 2);
      await _swipe(tester, left: true, from: 0.8);
      await _frames(tester, 2);
      expect(V2PageTurn.isTurning(flip), isTrue);
      await _swipe(tester, left: false, from: 0.3);
      await _settle(tester);
      _expectSettled(book, flip, 2);
      expect(book.changes, [3, 2]);
    });

    testWidgets('backward then immediately forward returns to the page',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 2);
      await _swipe(tester, left: false, from: 0.2);
      await _frames(tester, 2);
      expect(V2PageTurn.isTurning(flip), isTrue);
      await _swipe(tester, left: true, from: 0.7);
      await _settle(tester);
      _expectSettled(book, flip, 2);
      expect(book.changes, [1, 2]);
    });

    testWidgets('alternating swipes during animations never skip or stick',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 4);
      final lefts = [true, false, true, true, false, true];
      for (final left in lefts) {
        await _swipe(tester, left: left, from: left ? 0.35 : 0.65, ms: 90);
        await _frames(tester, 1);
      }
      await _settle(tester);
      _expectSettled(book, flip, 6);
      expect(book.changes, [5, 4, 5, 6, 5, 6]);
    });

    testWidgets('swipe during an arrow-button turn settles it first',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 2);
      final arrow = flip.nextPage();
      await _frames(tester, 3);
      expect(V2PageTurn.isTurning(flip), isTrue);
      await _swipe(tester, left: false, from: 0.7);
      await _settle(tester);
      expect(await arrow, isTrue);
      _expectSettled(book, flip, 2);
      expect(book.changes, [3, 2]);
    });

    testWidgets('a second finger cannot hijack a drag', (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, start: 2);
      final box = _page(tester);
      final first = await tester.startGesture(
        Offset(box.left + box.width * 0.8, box.center.dy),
      );
      for (var i = 0; i < 6; i++) {
        await first.moveBy(const Offset(-25, 0));
        await _frames(tester);
      }
      final second = await tester.startGesture(
        Offset(box.left + box.width * 0.3, box.center.dy + 100),
        pointer: 7,
      );
      await second.moveBy(const Offset(120, 0));
      await _frames(tester);
      await second.up();
      for (var i = 0; i < 6; i++) {
        await first.moveBy(const Offset(-25, 0));
        await _frames(tester);
      }
      await first.up();
      await _settle(tester);
      _expectSettled(book, flip, 3);
      expect(book.changes, [3]);
    });
  });

  group('load-more', () {
    testWidgets('appended pages are reachable in the same book',
        (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, pages: 5, start: 4);
      final engine = flip.pageFlipInstance;
      expect(flip.hasNextPage, isFalse);

      book.grow(9);
      await _frames(tester, 3);
      expect(flip.pageFlipInstance, same(engine), reason: 'book kept');
      expect(flip.pageCount, 9);
      expect(flip.currentPageIndex, 4);

      await _swipe(tester, left: true, from: 0.3);
      await _frames(tester, 2);
      await _swipe(tester, left: true, from: 0.8);
      await _settle(tester);
      _expectSettled(book, flip, 6);
      expect(book.changes, [5, 6]);
    });

    testWidgets('pages appended mid-turn join after the turn', (tester) async {
      final flip = PageFlipController();
      final book = await _pump(tester, flip, pages: 5, start: 3);
      await _swipe(tester, left: true, from: 0.8);
      await _frames(tester, 2);
      expect(V2PageTurn.isTurning(flip), isTrue);
      book.grow(8);
      await _settle(tester);
      _expectSettled(book, flip, 4);
      expect(flip.pageCount, 8);
      await _swipe(tester, left: true, from: 0.8);
      await _settle(tester);
      _expectSettled(book, flip, 5);
    });
  });
}
