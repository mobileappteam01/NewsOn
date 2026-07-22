import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_service.dart';
import '../../data/services/ad_network_diagnostics.dart';
import 'ad_labeled_slot.dart';
import 'live_banner_ad_cache.dart';

/// In-feed ad (every N articles).
///
/// Once a creative loads successfully it stays visible:
/// - [AutomaticKeepAliveClientMixin] keeps the State alive while scrolling
/// - [LiveBannerAdCache] reattaches the last good creative after brief dispose
///
/// Slots that never receive inventory collapse (no fake ads).
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
  AdSize? _adSize;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _gaveUp = false;
  bool _initialLoadQueued = false;
  int _retryCount = 0;
  int _lastLoadWidth = 0;
  int _loadGeneration = 0;
  static const int _maxRetries = 4;

  /// Stable cache id from [ValueKey] when present (today vs category vs For You).
  String get _cacheId {
    final key = widget.key;
    if (key is ValueKey) {
      return 'inline_${key.value}';
    }
    return 'inline_slot_${widget.slotIndex}';
  }

  @override
  bool get wantKeepAlive => _isLoaded;

  @override
  void initState() {
    super.initState();
    _tryAdoptCached();
  }

  void _tryAdoptCached() {
    _adoptFromCache();
  }

  /// Returns true when this slot already has (or just restored) a creative.
  bool _adoptFromCache() {
    if (_isLoaded && _bannerAd != null) return true;
    final cached = LiveBannerAdCache.instance.adopt(_cacheId);
    if (cached == null) return false;
    _bannerAd = cached.ad;
    _adSize = cached.size;
    _isLoaded = true;
    _gaveUp = false;
    _isLoading = false;
    debugPrint('♻️ Inline feed ad ${widget.slotIndex} restored from cache');
    return true;
  }

  @override
  void didUpdateWidget(covariant InlineFeedAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = _cacheIdFor(oldWidget);
    final newId = _cacheId;
    if (oldId != newId || oldWidget.slotIndex != widget.slotIndex) {
      _loadGeneration++;
      // Park the old creative under its cache id for possible remount.
      if (_isLoaded && _bannerAd != null) {
        LiveBannerAdCache.instance.store(
          oldId,
          _bannerAd!,
          _adSize ?? _bannerAd!.size,
        );
        LiveBannerAdCache.instance.detach(oldId);
      } else {
        // In-flight request is invalidated via _loadGeneration; listener cleans up.
        LiveBannerAdCache.instance.detach(oldId);
      }
      _bannerAd = null;
      _adSize = null;
      _isLoaded = false;
      _gaveUp = false;
      _retryCount = 0;
      _lastLoadWidth = 0;
      _initialLoadQueued = false;
      _isLoading = false;
      _tryAdoptCached();
      updateKeepAlive();
      setState(() {});
    }
  }

  String _cacheIdFor(InlineFeedAd w) {
    final key = w.key;
    if (key is ValueKey) return 'inline_${key.value}';
    return 'inline_slot_${w.slotIndex}';
  }

  Future<void> _loadAd(int contentWidth) async {
    // Never replace a creative that already filled this slot.
    if (_isLoading || _isLoaded || _gaveUp) return;
    if (_adoptFromCache()) {
      if (mounted) {
        updateKeepAlive();
        setState(() {});
      }
      return;
    }
    if (contentWidth < 160) return;

    final policy = AdService().policy;
    if (!policy.enabled) return;

    if (_lastLoadWidth == contentWidth && (_isLoading || _bannerAd != null)) {
      return;
    }

    final loadGen = ++_loadGeneration;
    _isLoading = true;
    _lastLoadWidth = contentWidth;

    try {
      if (AdNetworkDiagnostics.isLikelyBlocked) {
        if (loadGen != _loadGeneration) return;
        _isLoading = false;
        _gaveUp = true;
        if (mounted) setState(() {});
        return;
      }

      await AdService().initialize();

      final ready = await AdService().ensureMobileAdsReady(
        timeout: const Duration(seconds: 20),
      );
      if (loadGen != _loadGeneration) return;
      if (!ready) {
        debugPrint(
          '⚠️ Inline feed ad ${widget.slotIndex}: MobileAds not ready, will retry',
        );
        _isLoading = false;
        _scheduleRetry(contentWidth);
        return;
      }

      if (!mounted || _isLoaded || loadGen != _loadGeneration) {
        _isLoading = false;
        return;
      }

      // Only dispose a *pending* unloadable instance — never a displayed one.
      if (!_isLoaded && _bannerAd != null) {
        await _bannerAd?.dispose();
        if (loadGen != _loadGeneration) return;
        _bannerAd = null;
        _adSize = null;
      }

      await AdService().runExclusiveBannerLoad(() async {
        if (!mounted || _isLoaded || loadGen != _loadGeneration) {
          _isLoading = false;
          return;
        }

        final requestWidth = contentWidth;
        final cacheId = _cacheId;
        final slotIndex = widget.slotIndex;
        final pending = AdService().createBannerAd(
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
              final size = platformSize ?? banner.size;

              // Stale load (disposed / superseded) — park creative or drop it.
              if (loadGen != _loadGeneration || !mounted) {
                LiveBannerAdCache.instance.store(cacheId, banner, size);
                LiveBannerAdCache.instance.detach(cacheId);
                return;
              }
              if (_isLoaded &&
                  _bannerAd != null &&
                  !identical(_bannerAd, banner)) {
                banner.dispose();
                return;
              }
              setState(() {
                _bannerAd = banner;
                _adSize = size;
                _isLoaded = true;
                _isLoading = false;
                _gaveUp = false;
              });
              LiveBannerAdCache.instance.store(cacheId, banner, size);
              updateKeepAlive();
              debugPrint(
                '✅ Inline feed ad $slotIndex loaded '
                '${size.width}x${size.height} '
                '(every ${AdService().policy.inlineInterval} articles)',
              );
            },
            onAdFailedToLoad: (ad, error) async {
              debugPrint(
                '❌ Inline feed ad $slotIndex: '
                '${AdService.describeLoadError(error)} '
                'unit=${AdService().inlineFeedAdUnitId}',
              );
              ad.dispose();
              if (loadGen != _loadGeneration) return;
              _isLoading = false;

              // Keep any previously shown creative (should already be gated).
              if (_isLoaded && _bannerAd != null) {
                if (mounted) setState(() {});
                return;
              }

              _bannerAd = null;
              _adSize = null;
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
                if (mounted && !_isLoaded && loadGen == _loadGeneration) {
                  _retryCount = 0;
                  _lastLoadWidth = 0;
                  _loadAd(contentWidth);
                }
                return;
              }

              // No inventory — prefer a late-cached fill over collapsing.
              if (_adoptFromCache()) {
                if (mounted) {
                  updateKeepAlive();
                  setState(() {});
                }
                return;
              }

              // No inventory — retry briefly, then collapse (never fake an ad).
              if (error.code == 3 && _retryCount >= 2) {
                _gaveUp = true;
                if (mounted) setState(() {});
                return;
              }
              _scheduleRetry(contentWidth);
            },
          ),
        );

        if (loadGen != _loadGeneration || !mounted || _isLoaded) {
          pending.dispose();
          _isLoading = false;
          return;
        }

        _bannerAd = pending;
        await pending.load();
      });
    } catch (e) {
      debugPrint('❌ Inline feed ad ${widget.slotIndex} load error: $e');
      if (loadGen != _loadGeneration) return;
      _isLoading = false;
      if (!_isLoaded) _scheduleRetry(contentWidth);
    }
  }

  void _scheduleRetry(int contentWidth) {
    if (_isLoaded) return;
    if (_adoptFromCache()) {
      if (mounted) {
        updateKeepAlive();
        setState(() {});
      }
      return;
    }
    if (_retryCount >= _maxRetries || !mounted || _gaveUp) {
      if (_adoptFromCache()) {
        if (mounted) {
          updateKeepAlive();
          setState(() {});
        }
        return;
      }
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

  @override
  void dispose() {
    _loadGeneration++;
    if (_isLoaded && _bannerAd != null) {
      // Park the displayed creative for remount / scroll-back.
      LiveBannerAdCache.instance.store(
        _cacheId,
        _bannerAd!,
        _adSize ?? _bannerAd!.size,
      );
      LiveBannerAdCache.instance.detach(_cacheId);
    }
    // In-flight loads: do not dispose here. The listener is generation-gated and
    // will either cache a late success or dispose a failed request.
    _bannerAd = null;
    _adSize = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin

    if (!AdService().policy.enabled) {
      return const SizedBox.shrink();
    }

    // Never loaded + gave up → collapse. Loaded ads never take this path.
    if (_gaveUp && !_isLoaded) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = MediaQuery.sizeOf(context).width;
        final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : screenW;
        final contentWidth = (maxW - 40).floor().clamp(160, 1200);

        if (!_initialLoadQueued && !_isLoaded && !_gaveUp) {
          _initialLoadQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isLoaded && !_gaveUp) _loadAd(contentWidth);
          });
        }

        if (!_isLoaded || _bannerAd == null || _adSize == null) {
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
