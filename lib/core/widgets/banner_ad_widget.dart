import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;

  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;

  bool _isAdLoaded = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _initializeAds();
  }

  Future<void> _initializeAds() async {
    final adService = AdService();

    if (!adService.isInitialized) {
      await adService.initialize();
    }

    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final adService = AdService();

    _bannerAd = adService.createBannerAd(
      size: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner loaded');

          if (!mounted) return;

          setState(() {
            _bannerAd = ad as BannerAd;
            _isAdLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ Banner failed: ${error.message}',
          );

          debugPrint(
            '❌ Error code: ${error.code}',
          );

          ad.dispose();

          if (!mounted) return;

          setState(() {
            _bannerAd = null;
            _isAdLoaded = false;
            _isLoading = false;
          });
        },
        onAdImpression: (ad) {
          debugPrint('📢 Ad impression');
        },
        onAdOpened: (ad) {
          debugPrint('📢 Ad opened');
        },
        onAdClosed: (ad) {
          debugPrint('📢 Ad closed');
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
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

class BannerAdContainer extends StatelessWidget {
  final Color? backgroundColor;

  final AdSize adSize;

  const BannerAdContainer({
    super.key,
    this.backgroundColor,
    this.adSize = AdSize.banner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: BannerAdWidget(
          adSize: adSize,
        ),
      ),
    );
  }
}
