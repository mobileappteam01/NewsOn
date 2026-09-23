import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_network_diagnostics.dart';
import '../../data/services/ad_service.dart';
import 'dailyhunt_ad_frame.dart';
import 'live_banner_ad_cache.dart';

/// Full-width banner between Breaking News and Today News (Dailyhunt-style).
///
/// Uses a fixed reserved height so pagination / feed rebuilds do not jump the
/// Today News list under the banner.
class FeedSectionBannerAd extends StatefulWidget {
  const FeedSectionBannerAd({super.key});

  static const String cacheId = 'home_section_banner_ad';

  /// Stable reserved height (adaptive banners typically land near this).
  static const double reservedHeight = 100;

  @override
  State<FeedSectionBannerAd> createState() => _FeedSectionBannerAdState();
}

class _FeedSectionBannerAdState extends State<FeedSectionBannerAd>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoading = false;
  bool _gaveUp = false;
  int _retryCount = 0;
  int _noFillRetries = 0;

  static const int _maxRetries = 3;
  static const int _maxNoFillRetries = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final adopted =
        LiveBannerAdCache.instance.adopt(FeedSectionBannerAd.cacheId);
    if (adopted != null && mounted) {
      setState(() {
        _bannerAd = adopted.ad;
        _adSize = adopted.size;
        _gaveUp = false;
      });
      return;
    }
    await _startLoad();
  }

  Future<void> _startLoad() async {
    if (!mounted || _gaveUp || _isLoading) return;

    final adService = AdService();
    if (!adService.policy.enabled ||
        !adService.policy.homeSectionBannerEnabled) {
      return;
    }

    await adService.initialize();
    if (!mounted || _gaveUp) return;

    if (AdNetworkDiagnostics.isLikelyBlocked) {
      if (mounted) setState(() => _gaveUp = true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      unawaited(adService.runExclusiveBannerLoad(() async {
        if (!mounted || _gaveUp) return;

        final widthPx = MediaQuery.sizeOf(context).width.truncate();
        final size = await AdService.anchoredAdaptiveSize(widthPx) ??
            AdSize.getInlineAdaptiveBannerAdSize(widthPx, 60);

        if (!mounted || _gaveUp) return;

        final completer = Completer<void>();
        final banner = adService.createBannerAd(
          size: size,
          maxContentWidth: widthPx,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              final loaded = ad as BannerAd;
              if (!mounted) {
                ad.dispose();
                completer.complete();
                return;
              }
              LiveBannerAdCache.instance.store(
                FeedSectionBannerAd.cacheId,
                loaded,
                loaded.size,
              );
              setState(() {
                _bannerAd = loaded;
                _adSize = loaded.size;
                _isLoading = false;
                _gaveUp = false;
                _retryCount = 0;
                _noFillRetries = 0;
              });
              completer.complete();
            },
            onAdFailedToLoad: (ad, error) async {
              ad.dispose();
              debugPrint(
                '❌ Home section banner failed: ${error.message} (${error.code})',
              );

              if (!mounted) {
                completer.complete();
                return;
              }

              final retryPublisher =
                  await AdService().handleLoadFailure(error);
              if (retryPublisher) {
                setState(() => _isLoading = false);
                completer.complete();
                if (mounted) _startLoad();
                return;
              }

              final isNoFill = error.code == 3;
              if (isNoFill) {
                _noFillRetries++;
              } else {
                _retryCount++;
              }

              final exhausted = isNoFill
                  ? _noFillRetries >= _maxNoFillRetries
                  : _retryCount >= _maxRetries;

              if (exhausted) {
                setState(() {
                  _isLoading = false;
                  _gaveUp = true;
                });
              } else {
                setState(() => _isLoading = false);
                _scheduleRetry(isNoFill: isNoFill);
              }
              completer.complete();
            },
          ),
        );

        await banner.load();
        if (!completer.isCompleted) {
          await completer.future.timeout(
            const Duration(seconds: 12),
            onTimeout: () {},
          );
        }
      }));
    } catch (e) {
      debugPrint('❌ Home section banner load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scheduleRetry({required bool isNoFill}) {
    final delay = isNoFill
        ? Duration(milliseconds: 2000 + _noFillRetries * 1000)
        : Duration(milliseconds: 1000 + _retryCount * 600);
    Future.delayed(delay, () {
      if (mounted && !_gaveUp && _bannerAd == null) _startLoad();
    });
  }

  @override
  void dispose() {
    if (_bannerAd != null) {
      LiveBannerAdCache.instance.detach(FeedSectionBannerAd.cacheId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final policy = AdService().policy;
    // Ads / section banner disabled — no reserved slot.
    if (!policy.enabled || !policy.homeSectionBannerEnabled) {
      return const SizedBox.shrink();
    }

    return DailyhuntAdFrame(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: SizedBox(
        width: double.infinity,
        height: FeedSectionBannerAd.reservedHeight,
        child: _bannerAd != null && _adSize != null
            ? Center(
                child: SizedBox(
                  width: _adSize!.width.toDouble(),
                  height: _adSize!.height
                      .toDouble()
                      .clamp(0, FeedSectionBannerAd.reservedHeight),
                  child: AdWidget(ad: _bannerAd!),
                ),
              )
            // Loading OR permanent failure: keep reserved height so Today
            // news below never jumps. Spinner only while still trying.
            : _gaveUp
                ? const SizedBox.expand()
                : const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
      ),
    );
  }
}
