import 'package:flutter/material.dart';

import '../v2_news_text_scale.dart';
import 'v2_reader_ad_slot.dart';
import 'v2_vintage_paper_background.dart';

/// Dedicated Turnable reader page for an ad. Not an article page.
class V2ReaderAdPage extends StatelessWidget {
  const V2ReaderAdPage({super.key, required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const V2VintagePaperBackground(intensity: V2PaperIntensity.page),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: V2NewsTextScope(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sponsored',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: V2ReaderAdSlot(slotIndex: slotIndex)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
