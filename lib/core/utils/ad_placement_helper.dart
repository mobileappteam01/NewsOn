import '../../data/models/ad_policy.dart';
import '../../data/services/ad_service.dart';

/// List index math for inline medium-rectangle ads between feed items.
class AdPlacementHelper {
  AdPlacementHelper._();

  static int get interval {
    final policy = AdService().policy;
    if (!policy.enabled) return 999999;
    return policy.inlineInterval.clamp(3, 12);
  }

  static int totalItemCount(int articleCount) =>
      totalItemCountWithInterval(articleCount, interval);

  static int totalItemCountWithInterval(int articleCount, int interval) {
    if (articleCount <= 0) return 0;
    final ads = (articleCount - 1) ~/ interval;
    return articleCount + ads;
  }

  static bool isAdSlot(int listIndex) =>
      isAdSlotWithInterval(listIndex, interval);

  static bool isAdSlotWithInterval(int listIndex, int interval) {
    if (listIndex <= 0) return false;
    return listIndex % (interval + 1) == interval;
  }

  static int articleIndexForListIndex(int listIndex) {
    final adsBefore = listIndex ~/ (interval + 1);
    return listIndex - adsBefore;
  }

  static int adSlotIndex(int listIndex) {
    return listIndex ~/ (interval + 1);
  }

  static bool shouldShowInlineAds(AdPolicy policy) =>
      policy.enabled && policy.inlineInterval > 0;
}
