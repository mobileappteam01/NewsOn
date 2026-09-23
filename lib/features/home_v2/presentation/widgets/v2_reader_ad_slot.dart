import 'package:flutter/material.dart';

import '../../../../core/widgets/inline_feed_ad.dart';
import '../../../../data/services/ad_service.dart';
import '../v2_reader_ad_placement.dart';

/// V2 reader ad area — uses existing [InlineFeedAd] / [AdService].
///
/// Shown only on every Nth article page (see [V2ReaderAdPlacement]). Visually
/// separated from article content; does not occupy a fake article index.
class V2ReaderAdSlot extends StatefulWidget {
  const V2ReaderAdSlot({
    super.key,
    required this.slotIndex,
  });

  final int slotIndex;

  @override
  State<V2ReaderAdSlot> createState() => _V2ReaderAdSlotState();
}

class _V2ReaderAdSlotState extends State<V2ReaderAdSlot> {
  @override
  void initState() {
    super.initState();
    // Session guard: track first mount per slot (revisits reuse cache).
    V2ReaderAdPlacement.claimSlotLoad(widget.slotIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!AdService().policy.enabled) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Sponsored',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        InlineFeedAd(
          slotIndex: widget.slotIndex,
          cacheKeyPrefix: 'v2_reader_ad',
        ),
      ],
    );
  }
}
