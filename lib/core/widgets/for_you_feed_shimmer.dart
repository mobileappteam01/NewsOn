import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Loading placeholder matching repeating For You blocks (mosaic + grid).
class ForYouFeedShimmer extends StatelessWidget {
  const ForYouFeedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    Widget box({required double height, double? width, BorderRadius? radius}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius ?? BorderRadius.circular(8),
        ),
      );
    }

    Widget mosaicBlock() {
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                box(height: 120),
                const SizedBox(height: 3),
                box(height: 120),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Expanded(child: box(height: 243)),
        ],
      );
    }

    Widget spotlightGrid() {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
        children: List.generate(4, (_) => box(height: 200)),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          box(height: 20, width: 160),
          const SizedBox(height: 8),
          box(height: 12, width: 240),
          const SizedBox(height: 20),
          mosaicBlock(),
          const SizedBox(height: 16),
          box(height: 14, width: 120),
          const SizedBox(height: 12),
          spotlightGrid(),
          const SizedBox(height: 24),
          box(height: 12, width: 100),
          const SizedBox(height: 16),
          mosaicBlock(),
          const SizedBox(height: 12),
          spotlightGrid(),
        ],
      ),
    );
  }
}
