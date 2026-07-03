import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';
import 'ad_labeled_slot.dart';

/// Persistent anchored adaptive banner above the bottom navigation bar.
class AnchorBannerAd extends StatefulWidget {
  const AnchorBannerAd({super.key});

  @override
  State<AnchorBannerAd> createState() => _AnchorBannerAdState();
}

class _AnchorBannerAdState extends State<AnchorBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _fallbackTried = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isLoading) return;
    final policy = AdService().policy;
    if (!policy.enabled || !policy.anchorBannerEnabled) return;

    _isLoading = true;
    await AdService().initialize();

    if (!mounted) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        await AdService.anchoredAdaptiveSize(width) ?? AdSize.banner;

    _bannerAd = AdService().createBannerAd(
      size: size,
      anchored: true,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ Anchor banner failed: ${error.message} (code ${error.code})',
          );
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
            _isLoading = false;
          });
          if (!_fallbackTried) {
            _fallbackTried = true;
            _loadStandardBannerFallback();
          }
        },
      ),
    );

    await _bannerAd?.load();
  }

  Future<void> _loadStandardBannerFallback() async {
    if (!mounted || _isLoading) return;
    _isLoading = true;
    await AdService().initialize();

    _bannerAd = AdService().createBannerAd(
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Anchor banner fallback failed: ${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() => _isLoading = false);
        },
      ),
    );
    await _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = AdService().policy;
    if (!policy.enabled || !policy.anchorBannerEnabled) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 0,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AdLabeledSlot(
        margin: EdgeInsets.zero,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
