import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/utils/ad_placement_helper.dart';
import 'package:newson/data/models/ad_policy.dart';

/// Pure mirrors of [AdPlacementHelper] math (interval=5) so tests do not
/// touch the AdService Firebase singleton.
int _total(int articles, {int interval = 5}) {
  if (articles <= 0) return 0;
  return articles + (articles - 1) ~/ interval;
}

bool _isAd(int listIndex, {int interval = 5}) {
  if (listIndex <= 0) return false;
  return listIndex % (interval + 1) == interval;
}

void main() {
  test('every 5 articles inserts an ad after the 5th, 10th, …', () {
    // Exactly 5 articles → no trailing ad (count stays 5).
    expect(_total(5), 5);

    // Index 5 *would* be an ad slot, but it is not built until article 6 exists.
    expect(_isAd(5), isTrue);

    // 6 articles → one ad after first 5 (list length 7).
    expect(_total(6), 7);
    expect(_isAd(5), isTrue);
    expect(_isAd(6), isFalse);

    // 20 articles → 3 ads (after 5, 10, 15).
    expect(_total(20), 23);
    expect(_isAd(5), isTrue);
    expect(_isAd(11), isTrue);
    expect(_isAd(17), isTrue);
    expect(_isAd(0), isFalse);
    expect(_isAd(4), isFalse);

    // Keep helper API in sync with the pure formula above.
    expect(AdPlacementHelper.totalItemCountWithInterval(20, 5), _total(20));
    expect(AdPlacementHelper.isAdSlotWithInterval(11, 5), isTrue);
  });

  test('shouldShowInlineAds respects policy', () {
    expect(
      AdPlacementHelper.shouldShowInlineAds(
        const AdPolicy(enabled: true, inlineInterval: 5),
      ),
      isTrue,
    );
    expect(
      AdPlacementHelper.shouldShowInlineAds(
        const AdPolicy(enabled: false, inlineInterval: 5),
      ),
      isFalse,
    );
  });
}
