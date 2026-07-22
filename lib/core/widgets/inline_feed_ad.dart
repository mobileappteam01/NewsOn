import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';
import '../../data/services/ad_network_diagnostics.dart';
import 'ad_labeled_slot.dart';

/// In-feed ad (every N articles). Width-adaptive so Banner-unit creatives fit
/// padded phone layouts; off-screen instances are disposable (no keep-alive).
class InlineFeedAd extends StatefulWidget {
  const InlineFeedAd({
    super.key,
    required this.slotIndex,
  });

  final int slotIndex;

  @override
  State<InlineFeedAd> createState() => _InlineFeedAdState();
}

class _InlineFeedAdState extends State<InlineFeedAd> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _gaveUp = false;
  bool _initialLoadQueued = false;
  int _retryCount = 0;
  int _lastLoadWidth = 0;
  static const int _maxRetries = 4;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant InlineFeedAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slotIndex != widget.slotIndex) {
      _disposeAd();
      _isLoaded = false;
      _gaveUp = false;
      _retryCount = 0;
      _lastLoadWidth = 0;
      _initialLoadQueued = false;
      setState(() {});
    }
  }

  Future<void> _loadAd(int contentWidth) async {
    if (_isLoading || _isLoaded || _gaveUp) return;
    if (contentWidth < 160) return;

    final policy = AdService().policy;
    if (!policy.enabled) return;

    // Avoid reloading the same width repeatedly while scrolling.
    if (_lastLoadWidth == contentWidth && (_isLoading || _bannerAd != null)) {
      return;
    }

    _isLoading = true;
    _lastLoadWidth = contentWidth;

    try {
      if (AdNetworkDiagnostics.isLikelyBlocked) {
        _isLoading = false;
        _gaveUp = true;
        if (mounted) setState(() {});
        return;
      }

      await AdService().initialize();

      final ready = await AdService().ensureMobileAdsReady(
        timeout: const Duration(seconds: 20),
      );
      if (!ready) {
        debugPrint(
          '⚠️ Inline feed ad ${widget.slotIndex}: MobileAds not ready, will retry',
        );
        _isLoading = false;
        _scheduleRetry(contentWidth);
        return;
      }

      if (!mounted) {
        _isLoading = false;
        return;
      }

      await _bannerAd?.dispose();
      _bannerAd = null;
      _adSize = null;

      await AdService().runExclusiveBannerLoad(() async {
        if (!mounted) {
          _isLoading = false;
          return;
        }

        final requestWidth = contentWidth;
        _bannerAd = AdService().createBannerAd(
          size: AdService().resolveInlineFeedAdSize(requestWidth),
          adUnitId: AdService().inlineFeedAdUnitId,
          inlineFeed: true,
          maxContentWidth: requestWidth,
          listener: BannerAdListener(
            onAdLoaded: (ad) async {
              final banner = ad as BannerAd;
              AdSize? platformSize;
              try {
                platformSize = await banner.getPlatformAdSize();
              } catch (_) {}
              if (!mounted) {
                banner.dispose();
                return;
              }
              setState(() {
                _bannerAd = banner;
                _adSize = platformSize ?? banner.size;
                _isLoaded = true;
                _isLoading = false;
              });
              debugPrint(
                '✅ Inline feed ad ${widget.slotIndex} loaded '
                '${_adSize?.width}x${_adSize?.height} '
                '(every ${AdService().policy.inlineInterval} articles)',
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
              _adSize = null;
              _isLoading = false;
              if (!mounted) return;

              if (error.message.contains('JavascriptEngine')) {
                await AdNetworkDiagnostics.reportJavascriptEngineFailure();
                if (AdNetworkDiagnostics.isLikelyBlocked) {
                  _gaveUp = true;
                  setState(() {});
                  return;
                }
              }

              if (await AdService().handleLoadFailure(error)) {
                if (mounted && !_isLoaded) {
                  _retryCount = 0;
                  _lastLoadWidth = 0;
                  _loadAd(contentWidth);
                }
                return;
              }

              // Transient no-fill / network — retry a few times, then collapse.
              if (error.code == 3 && _retryCount >= 2) {
                _gaveUp = true;
                if (mounted) setState(() {});
                return;
              }
              _scheduleRetry(contentWidth);
            },
          ),
        );

        await _bannerAd?.load();
      });
    } catch (e) {
      debugPrint('❌ Inline feed ad ${widget.slotIndex} load error: $e');
      _isLoading = false;
      _scheduleRetry(contentWidth);
    }
  }

  void _scheduleRetry(int contentWidth) {
    if (_retryCount >= _maxRetries || !mounted || _gaveUp) {
      _gaveUp = true;
      if (mounted) setState(() {});
      return;
    }
    _retryCount++;
    final delaySeconds = _retryCount == 1 ? 3 : 6 * _retryCount;
    final staggerMs = widget.slotIndex * 350;
    Future.delayed(Duration(seconds: delaySeconds, milliseconds: staggerMs), () {
      if (mounted && !_isLoaded && !_gaveUp) {
        _isLoading = false;
        _lastLoadWidth = 0;
        _loadAd(contentWidth);
      }
    });
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService().policy.enabled || _gaveUp) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // SliverPadding (16*2) + AdLabeledSlot (12*2 + 8*2) ≈ 72.
        // Prefer tight constraint when list provides it; else screen width.
        final screenW = MediaQuery.sizeOf(context).width;
        final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : screenW;
        final contentWidth = (maxW - 40).floor().clamp(160, 1200);

        if (!_initialLoadQueued && !_isLoaded && !_gaveUp) {
          _initialLoadQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadAd(contentWidth);
          });
        }

        if (!_isLoaded || _bannerAd == null || _adSize == null) {
          // Soft reserved height while loading — avoids zero-height slots
          // that never reflow after a late successful load on some OEMs.
          if (_isLoading || _retryCount > 0) {
            return const SizedBox(height: 8);
          }
          return const SizedBox.shrink();
        }

        final w = _adSize!.width.toDouble();
        final h = _adSize!.height.toDouble();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: AdLabeledSlot(
              child: SizedBox(
                width: w > 0 ? w : contentWidth.toDouble(),
                height: h > 0 ? h : 100,
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ),
        );
      },
    );
  }
}
