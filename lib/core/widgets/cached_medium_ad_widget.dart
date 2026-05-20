import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:newson/core/widgets/ad_cache_manager.dart';

class CachedMediumAdWidget extends StatelessWidget {
  final int index;

  const CachedMediumAdWidget({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = AdCacheManager.instance.getMediumAd(index);

    if (ad == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
