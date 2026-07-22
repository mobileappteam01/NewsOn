import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ad_network_diagnostics.dart';
import '../../data/services/ad_service.dart';
import '../utils/localization_helper.dart';
import '../utils/shared_functions.dart';
import 'ad_labeled_slot.dart';

/// Full-page, swipeable ad card between news-detail carousel articles
/// (Inshorts-style). Clearly labeled; never blocks navigation.
class DetailCarouselAdPage extends StatefulWidget {
  const DetailCarouselAdPage({
    super.key,
    required this.slotIndex,
    required this.onClose,
    this.appLogoUrl,
  });

  final int slotIndex;
  final VoidCallback onClose;
  final String? appLogoUrl;

  @override
  State<DetailCarouselAdPage> createState() => _DetailCarouselAdPageState();
}

class _DetailCarouselAdPageState extends State<DetailCarouselAdPage>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
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
    if (_isLoading || _isLoaded) return;
    final policy = AdService().policy;
    if (!policy.enabled || !policy.detailCarouselAdsEnabled) return;

    _isLoading = true;
    try {
      if (AdNetworkDiagnostics.isLikelyBlocked) {
        _isLoading = false;
        return;
      }

      await AdService().initialize();
      final ready = await AdService().ensureMobileAdsReady(
        timeout: const Duration(seconds: 20),
      );
      if (!ready || !mounted) {
        _isLoading = false;
        if (ready == false) _scheduleRetry();
        return;
      }

      await _bannerAd?.dispose();
      _bannerAd = null;

      await AdService().runExclusiveBannerLoad(() async {
        if (!mounted) {
          _isLoading = false;
          return;
        }

        // Prefer medium when available; otherwise adaptive banner on Banner unit
        // (same inventory as feed). Width matches the carousel content area.
        final contentWidth =
            (MediaQuery.sizeOf(context).width - 48).floor().clamp(160, 1200);
        _bannerAd = AdService().createBannerAd(
          size: AdService().resolveInlineFeedAdSize(contentWidth),
          adUnitId: AdService().inlineFeedAdUnitId,
          inlineFeed: true,
          maxContentWidth: contentWidth,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              if (!mounted) return;
              setState(() {
                _bannerAd = ad as BannerAd;
                _isLoaded = true;
                _isLoading = false;
              });
              debugPrint(
                '✅ Detail carousel ad ${widget.slotIndex} loaded',
              );
            },
            onAdFailedToLoad: (ad, error) async {
              debugPrint(
                '❌ Detail carousel ad ${widget.slotIndex}: '
                '${AdService.describeLoadError(error)}',
              );
              ad.dispose();
              _bannerAd = null;
              _isLoading = false;
              if (error.message.contains('JavascriptEngine')) {
                await AdNetworkDiagnostics.reportJavascriptEngineFailure();
                if (AdNetworkDiagnostics.isLikelyBlocked) return;
              }
              if (await AdService().handleLoadFailure(error)) {
                if (mounted && !_isLoaded) {
                  _retryCount = 0;
                  _loadAd();
                }
                return;
              }
              if (error.code == 3) return;
              _scheduleRetry();
            },
          ),
        );

        await _bannerAd?.load();
      });
    } catch (e) {
      debugPrint('❌ Detail carousel ad ${widget.slotIndex} error: $e');
      _isLoading = false;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries || !mounted) return;
    _retryCount++;
    final delay = Duration(seconds: 3 * _retryCount);
    Future.delayed(delay, () {
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
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                _ChromeButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: widget.onClose,
                ),
                const SizedBox(width: 10),
                if (widget.appLogoUrl != null &&
                    widget.appLogoUrl!.trim().isNotEmpty)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.14),
                      ),
                    ),
                    child: showImage(
                      widget.appLogoUrl,
                      BoxFit.contain,
                      height: 48,
                      width: 72,
                    ),
                  ),
                const Spacer(),
                Text(
                  LocalizationHelper.sponsored(context),
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      LocalizationHelper.sponsored(context),
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoaded && _bannerAd != null)
                      AdLabeledSlot(
                        margin: EdgeInsets.zero,
                        child: SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      )
                    else
                      _AdPlaceholder(isLoading: _isLoading),
                    const SizedBox(height: 28),
                    Text(
                      'Swipe for next story',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.swipe_rounded,
                      color: Colors.white.withOpacity(0.28),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 250,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            )
          : Text(
              LocalizationHelper.sponsored(context),
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.42),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
