import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';
import 'ad_labeled_slot.dart';

/// Medium-rectangle in-feed ad (one instance per slot — safe for ListView).
class InlineFeedAd extends StatefulWidget {
  const InlineFeedAd({
    super.key,
    required this.slotIndex,
  });

  final int slotIndex;

  @override
  State<InlineFeedAd> createState() => _InlineFeedAdState();
}

class _InlineFeedAdState extends State<InlineFeedAd>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    final policy = AdService().policy;
    if (!policy.enabled) return;

    await AdService().initialize();

    await _bannerAd?.dispose();
    _bannerAd = null;

    _bannerAd = AdService().createBannerAd(
      size: AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ Inline feed ad ${widget.slotIndex}: ${error.message} '
            '(code ${error.code}) unit=${AdService().mediumRectangleAdUnitId}',
          );
          ad.dispose();
          _bannerAd = null;
          _scheduleRetry();
        },
      ),
    );

    await _bannerAd?.load();
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries || !mounted) return;
    _retryCount++;
    Future.delayed(Duration(seconds: 15 * _retryCount), () {
      if (mounted && !_isLoaded) _loadAd();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!AdService().policy.enabled || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return AdLabeledSlot(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
