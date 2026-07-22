import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';
import '../../data/services/ad_network_diagnostics.dart';
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
    // Keep the last good creative — never tear it down for a refresh/no-fill.
    if (_isLoading || _isLoaded) return;
    final policy = AdService().policy;
    if (!policy.enabled || !policy.anchorBannerEnabled) return;

    _isLoading = true;
    await AdService().initialize();
    final ready = await AdService().ensureMobileAdsReady(
      timeout: const Duration(seconds: 20),
    );
    if (!ready) {
      debugPrint('⚠️ Anchor banner: MobileAds not ready, retrying…');
      _isLoading = false;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isLoaded) _loadAd();
      });
      return;
    }

    if (!mounted || _isLoaded) {
      _isLoading = false;
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        await AdService.anchoredAdaptiveSize(width) ?? AdSize.banner;

    await AdService().runExclusiveBannerLoad(() async {
      if (!mounted || _isLoaded) {
        _isLoading = false;
        return;
      }
      final pending = AdService().createBannerAd(
        size: size,
        anchored: true,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
              _isLoading = false;
            });
            debugPrint('✅ Anchor banner loaded');
          },
          onAdFailedToLoad: (ad, error) async {
            debugPrint(
              '❌ Anchor banner failed: ${AdService.describeLoadError(error)}',
            );
            ad.dispose();
            _isLoading = false;
            if (!mounted) return;
            // Do not blank a previously shown creative.
            if (_isLoaded && _bannerAd != null) {
              setState(() {});
              return;
            }
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
            if (error.message.contains('JavascriptEngine')) {
              await AdNetworkDiagnostics.reportJavascriptEngineFailure();
              if (AdNetworkDiagnostics.isLikelyBlocked) return;
            }
            if (await AdService().handleLoadFailure(error)) {
              if (mounted && !_isLoaded) _loadAd();
              return;
            }
            if (!_fallbackTried) {
              _fallbackTried = true;
              _loadStandardBannerFallback();
            }
          },
        ),
      );

      _bannerAd = pending;
      await pending.load();
    });
  }

  Future<void> _loadStandardBannerFallback() async {
    if (!mounted || _isLoading || _isLoaded) return;
    _isLoading = true;
    await AdService().initialize();
    final ready = await AdService().ensureMobileAdsReady();
    if (!ready || !mounted || _isLoaded) {
      _isLoading = false;
      return;
    }

    await AdService().runExclusiveBannerLoad(() async {
      if (!mounted || _isLoaded) {
        _isLoading = false;
        return;
      }
      final pending = AdService().createBannerAd(
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
              _isLoading = false;
            });
            debugPrint('✅ Anchor banner fallback loaded');
          },
          onAdFailedToLoad: (ad, error) async {
            debugPrint('❌ Anchor banner fallback failed: ${error.message}');
            ad.dispose();
            _isLoading = false;
            if (!mounted) return;
            if (_isLoaded && _bannerAd != null) {
              setState(() {});
              return;
            }
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
            if (await AdService().handleLoadFailure(error)) {
              if (mounted && !_isLoaded) {
                _fallbackTried = false;
                _loadAd();
              }
            }
          },
        ),
      );
      _bannerAd = pending;
      await pending.load();
    });
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
