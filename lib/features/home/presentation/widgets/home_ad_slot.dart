import 'package:flutter/material.dart';

import '../../../../core/widgets/feed_section_banner_ad.dart';

/// Reserved Home ad slot — never placed inside a NewsOn Cut summary.
class HomeAdSlot extends StatelessWidget {
  const HomeAdSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: FeedSectionBannerAd(),
    );
  }
}
