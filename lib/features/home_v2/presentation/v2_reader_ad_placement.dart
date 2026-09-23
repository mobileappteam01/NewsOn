import 'package:flutter/foundation.dart';

import '../../../core/utils/ad_placement_helper.dart';
import '../../../data/services/ad_service.dart';

/// Article-based AdMob frequency for the V2 reader (not swipe-based).
///
/// Shows an ad on every Nth article (default N = [AdPlacementHelper.interval],
/// typically 5): articles 5, 10, 15, … Article indices stay 0-based news
/// positions — ads never become fake article pages.
abstract final class V2ReaderAdPlacement {
  /// Session slots that have already mounted an ad load.
  static final Set<int> _loadedSlots = <int>{};

  static int get interval => AdPlacementHelper.interval;

  static bool get adsEnabled {
    final policy = AdService().policy;
    return policy.enabled && policy.inlineInterval > 0;
  }

  /// 0-based [articleIndex]. True on the 5th, 10th, … article when interval is 5.
  static bool shouldShowAdOnArticle(int articleIndex, {int? intervalOverride}) {
    // When testing with an explicit interval, skip AdService (needs Firebase).
    if (intervalOverride == null && !adsEnabled) return false;
    final n = intervalOverride ?? interval;
    if (n <= 0 || n >= 999999) return false;
    if (articleIndex < 0) return false;
    return (articleIndex + 1) % n == 0;
  }

  /// Stable AdMob slot id for [InlineFeedAd] caching (0 for article 5, 1 for 10…).
  static int slotIndexForArticle(int articleIndex, {int? intervalOverride}) {
    final n = intervalOverride ?? interval;
    if (n <= 0) return 0;
    return ((articleIndex + 1) ~/ n) - 1;
  }

  /// First visit to this ad slot in the session → true (caller may load).
  /// Revisiting article 5 after article 4 returns false so we do not spam loads;
  /// the UI may still show the cached banner via [InlineFeedAd].
  static bool claimSlotLoad(int slotIndex) => _loadedSlots.add(slotIndex);

  static bool hasClaimedSlot(int slotIndex) => _loadedSlots.contains(slotIndex);

  @visibleForTesting
  static void debugResetSession() => _loadedSlots.clear();
}
