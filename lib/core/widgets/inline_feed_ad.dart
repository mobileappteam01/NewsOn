import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';
import '../../data/services/ad_network_diagnostics.dart';
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
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isLoading || _isLoaded) return;
    final policy = AdService().policy;
    if (!policy.enabled) return;

    _isLoading = true;
    try {
      // Don't burn retries when device DNS sinksholes AdMob.
      if (AdNetworkDiagnostics.isLikelyBlocked) {
        _isLoading = false;
        return;
      }

      await AdService().initialize();

      // Wait for MobileAds SDK — loading before this causes
      // "Unable to obtain a JavascriptEngine" on cold start / release.
      final ready = await AdService().ensureMobileAdsReady(
        timeout: const Duration(seconds: 20),
      );
      if (!ready) {
        debugPrint(
          '⚠️ Inline feed ad ${widget.slotIndex}: MobileAds not ready, will retry',
        );
        _isLoading = false;
        _scheduleRetry();
        return;
      }

      if (!mounted) {
        _isLoading = false;
        return;
      }

      await _bannerAd?.dispose();
      _bannerAd = null;

      await AdService().runExclusiveBannerLoad(() async {
        if (!mounted) {
          _isLoading = false;
          return;
        }

        _bannerAd = AdService().createBannerAd(
          size: AdService().inlineFeedAdSize,
          adUnitId: AdService().inlineFeedAdUnitId,
          inlineFeed: true,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              if (!mounted) return;
              setState(() {
                _bannerAd = ad as BannerAd;
                _isLoaded = true;
                _isLoading = false;
              });
              debugPrint(
                '✅ Inline feed ad ${widget.slotIndex} loaded '
                '(slot after every ${AdService().policy.inlineInterval} articles)',
              );
            },
            onAdFailedToLoad: (ad, error) async {
              debugPrint(
                '❌ Inline feed ad ${widget.slotIndex}: '
                '${AdService.describeLoadError(error)} '
                'unit=${AdService().inlineFeedAdUnitId}',
              );
              ad.dispose();
              _bannerAd = null;
              _isLoading = false;
              if (error.message.contains('JavascriptEngine')) {
                await AdNetworkDiagnostics.reportJavascriptEngineFailure();
                if (AdNetworkDiagnostics.isLikelyBlocked) return;
              }
              // Live AdMob setup broken → switch to Google test units & retry once.
              if (await AdService().handleLoadFailure(error)) {
                if (mounted && !_isLoaded) {
                  _retryCount = 0;
                  _loadAd();
                }
                return;
              }
              // Don't hammer retries on permanent no-fill once already on test units.
              if (error.code == 3) return;
              _scheduleRetry();
            },
          ),
        );

        await _bannerAd?.load();
      });
    } catch (e) {
      debugPrint('❌ Inline feed ad ${widget.slotIndex} load error: $e');
      _isLoading = false;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries || !mounted) return;
    _retryCount++;
    // Stagger retries so multiple slots don't all hit WebView at once.
    final delaySeconds = _retryCount == 1 ? 4 : 8 * _retryCount;
    final staggerMs = widget.slotIndex * 400;
    Future.delayed(Duration(seconds: delaySeconds, milliseconds: staggerMs), () {
      if (mounted && !_isLoaded) {
        _isLoading = false;
        _loadAd();
      }
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
      // Collapse until loaded so failed ads don't leave empty gaps.
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: AdLabeledSlot(
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}
