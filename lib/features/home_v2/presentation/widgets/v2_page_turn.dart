import 'package:flutter/material.dart';
import 'package:turnable_page/turnable_page.dart';

/// V2 reader pager backed by [TurnablePage] (realistic paper curl).
///
/// Product gesture (LTR book):
/// - Swipe **left** → next article
/// - Swipe **right** → previous article
///
/// Uses [TextDirection.ltr] so TurnablePage’s natural book direction matches
/// that mapping. Do **not** add horizontal mirror transforms.
class V2PageTurn extends StatelessWidget {
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

  PaperBoundaryDecoration _paperEdge(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return PaperBoundaryDecoration.custom(
      baseColor: isDark ? const Color(0xFF1C1915) : const Color(0xFFF5EBDC),
      shadowColor: Colors.black,
      borderColor: isDark
          ? const Color(0xFF3A342C)
          : const Color(0xFFD2C2A6),
      borderRadius: 3,
      borderWidth: 0.35,
      shadowBlurRadius: 10,
      shadowOpacity: isDark ? 0.35 : 0.16,
      baseOpacity: 0.22,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();

    final start = index.clamp(0, itemCount - 1);
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
            child: TurnablePage(
              controller: controller,
              pageCount: itemCount,
              pageViewMode: PageViewMode.single,
              paperBoundaryDecoration: _paperEdge(brightness),
              textDirection: TextDirection.ltr,
              aspectRatio: aspectRatio,
              settings: FlipSettings(
                startPageIndex: start,
                flippingTime: 680,
                swipeDistance: 70,
                cornerTriggerAreaSize: 0.12,
                drawShadow: true,
                showCenterShadow: true,
                enableEasing: true,
                enableInertia: true,
                mobileScrollSupport: true,
                swipeAngleThreshold: 1.45,
              ),
              onPageChanged: (leftIndex, rightIndex) {
                final next = leftIndex;
                if (next < 0 || next >= itemCount) return;
                if (next == index) return;
                if (next > index && !canGoNext) return;
                if (next < index && !canGoPrevious) return;
                onIndexChanged(next);
              },
              builder: (context, pageIndex, pageConstraints) {
                return itemBuilder(context, pageIndex);
              },
            ),
          ),
        );
      },
    );
  }
}
