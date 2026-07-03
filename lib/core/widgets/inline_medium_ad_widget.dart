import 'package:flutter/material.dart';

import 'inline_feed_ad.dart';

/// @deprecated Prefer [InlineFeedAd]. Kept for existing imports.
class InlineMediumAdWidget extends StatelessWidget {
  final int index;

  const InlineMediumAdWidget({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return InlineFeedAd(slotIndex: index);
  }
}
