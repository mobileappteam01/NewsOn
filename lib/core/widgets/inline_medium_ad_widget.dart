import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';

class InlineMediumAdWidget extends StatefulWidget {
  final int index;

  const InlineMediumAdWidget({
    super.key,
    required this.index,
  });

  @override
  State<InlineMediumAdWidget> createState() => _InlineMediumAdWidgetState();
}

class _InlineMediumAdWidgetState extends State<InlineMediumAdWidget>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;

  bool _isLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _loadAd();
  }

  void _loadAd() {
    _bannerAd = AdService().createBannerAd(
      size: AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint(
            '✅ Inline ad loaded ${widget.index}',
          );

          if (!mounted) return;

          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ Inline ad failed ${widget.index}: ${error.message}',
          );

          ad.dispose();

          _bannerAd = null;
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
