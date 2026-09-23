import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_network_diagnostics.dart';
import '../../data/services/ad_service.dart';
import 'dailyhunt_ad_frame.dart';
import 'live_banner_ad_cache.dart';

/// In-feed banner every N articles in Today / category / search lists.
class InlineFeedAd extends StatefulWidget {
  const InlineFeedAd({
    super.key,
    required this.slotIndex,
    this.cacheKeyPrefix = 'inline_feed_ad',
  });

  final int slotIndex;
  final String cacheKeyPrefix;

  @override
  State<InlineFeedAd> createState() => _InlineFeedAdState();
}

class _InlineFeedAdState extends State<InlineFeedAd>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoading = false;
  bool _gaveUp = false;
  int _retryCount = 0;
  int _noFillRetries = 0;

  static const int _maxRetries = 3;
  static const int _maxNoFillRetries = 2;

  String get _cacheId => '${widget.cacheKeyPrefix}_${widget.slotIndex}';

  /// Reserve space from first frame so news after the ad never jumps.
  double get _placeholderHeight {
    final adService = AdService();
    if (adService.hasDedicatedMediumUnit) return 258;
    return 120;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final adopted = LiveBannerAdCache.instance.adopt(_cacheId);
    if (adopted != null && mounted) {
      setState(() {
        _bannerAd = adopted.ad;
        _adSize = adopted.size;
        _gaveUp = false;
        _isLoading = false;
      });
      return;
    }
    _scheduleInitialLoad();
  }

  void _scheduleInitialLoad() {
    // No artificial stagger — the exclusive banner queue already serializes
    // loads. Visible slots should enqueue as soon as they mount.
    _startLoad();
  }

  Future<void> _startLoad() async {
    if (!mounted || _gaveUp || _isLoading || _bannerAd != null) return;

    final adService = AdService();
    if (!adService.policy.enabled) return;

    await adService.initialize();
    if (!mounted || _gaveUp) return;

    if (AdNetworkDiagnostics.isLikelyBlocked) {
      if (mounted) {
        setState(() {
          _gaveUp = true;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Fire-and-forget style: do not block list scrolling on the ad queue.
      unawaited(adService.runExclusiveBannerLoad(() async {
        if (!mounted || _gaveUp) return;

        final widthPx = (MediaQuery.sizeOf(context).width - 32).truncate();
        final completer = Completer<void>();

        final banner = adService.createBannerAd(
          inlineFeed: true,
          maxContentWidth: widthPx,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              final loaded = ad as BannerAd;
              if (!mounted) {
                ad.dispose();
                completer.complete();
                return;
              }
              LiveBannerAdCache.instance.store(_cacheId, loaded, loaded.size);
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
                '❌ Inline feed ad slot ${widget.slotIndex} failed: '
                '${error.message} (${error.code})',
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
      debugPrint('❌ Inline feed ad slot ${widget.slotIndex} error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scheduleRetry({required bool isNoFill}) {
    final delay = isNoFill
        ? Duration(milliseconds: 1800 + _noFillRetries * 800)
        : Duration(milliseconds: 800 + _retryCount * 500);
    Future.delayed(delay, () {
      if (mounted && !_gaveUp && _bannerAd == null) _startLoad();
    });
  }

  @override
  void dispose() {
    if (_bannerAd != null) {
      LiveBannerAdCache.instance.detach(_cacheId);
    }
    super.dispose();
  }

  Widget _reservedSlot({required bool showSpinner}) {
    return DailyhuntAdFrame(
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: _placeholderHeight,
        width: double.infinity,
        child: showSpinner
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Ads fully disabled via policy — no reserved slot.
    if (!AdService().policy.enabled) return const SizedBox.shrink();

    if (_bannerAd != null && _adSize != null) {
      return DailyhuntAdFrame(
        margin: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: _placeholderHeight,
          child: Center(
            child: SizedBox(
              width: _adSize!.width.toDouble(),
              height: _adSize!.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ),
      );
    }

    // Loading, pending, OR permanent failure: keep reserved height so news
    // below never jumps. Spinner only while still trying.
    return _reservedSlot(showSpinner: !_gaveUp);
  }
}
