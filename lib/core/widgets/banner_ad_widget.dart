import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../data/services/ad_service.dart';

/// Reusable Banner Ad Widget
/// Displays a Google AdMob banner ad at the bottom of the screen
class BannerAdWidget extends StatefulWidget {
  /// Optional custom ad size (defaults to AdSize.banner)
  final AdSize adSize;

  const BannerAdWidget({super.key, this.adSize = AdSize.banner});

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
    _initializeAndLoadAd();
  }

  Future<void> _initializeAndLoadAd() async {
    final adService = AdService();

    // Ensure AdService is initialized before creating ads
    if (!adService.isInitialized) {
      debugPrint('📢 AdService not initialized, initializing now...');
      await adService.initialize();
    }

    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (_isLoading) {
      debugPrint('⚠️ Banner ad is already loading, skipping...');
      return;
    }

    final adService = AdService();
    final adUnitId = adService.bannerAdUnitId;

    debugPrint('📢 Loading banner ad with unit ID: $adUnitId');

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    _bannerAd = adService.createBannerAd(
      size: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner ad loaded successfully');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _isLoading = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner ad failed to load: ${error.message}');
          debugPrint('   Error code: ${error.code}');
          debugPrint('   Error domain: ${error.domain}');
          debugPrint('   Ad Unit ID used: $adUnitId');

          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _isLoading = false;
              _bannerAd = null;
            });
          }
        },
        onAdOpened: (ad) {
          debugPrint('📢 Banner ad opened');
        },
        onAdClosed: (ad) {
          debugPrint('📢 Banner ad closed');
        },
        onAdImpression: (ad) {
          debugPrint('📢 Banner ad impression recorded');
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
      // Return empty container to avoid layout shifts
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

/// Banner Ad Container Widget
/// Wraps the BannerAdWidget with proper styling and safe area handling
class BannerAdContainer extends StatelessWidget {
  /// Background color for the ad container
  final Color? backgroundColor;

  /// Ad size to display (defaults to AdSize.banner)
  final AdSize adSize;

  const BannerAdContainer({
    super.key,
    this.backgroundColor,
    this.adSize = AdSize.banner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12),
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, child: BannerAdWidget(adSize: adSize)),
    );
  }
}
