import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/analytics/analytics_events.dart';
import 'package:newson/features/for_you/domain/personalization_ranking_config.dart';

void main() {
  test('analytics search event name is canonical', () {
    expect(AnalyticsEvents.search, 'search');
    expect(AnalyticsEvents.forYouImpression, 'for_you_impression');
  });

  test('impression weight is weakest engagement signal', () {
    expect(
      PersonalizationRankingConfig.weightImpression,
      lessThan(PersonalizationRankingConfig.weightOpen),
    );
  });
}
