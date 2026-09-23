import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/for_you/domain/personalization_ranking_config.dart';

void main() {
  group('PersonalizationRankingConfig', () {
    test('clamps scores to documented bounds', () {
      expect(PersonalizationRankingConfig.clampScore(-1), 0);
      expect(PersonalizationRankingConfig.clampScore(2), 1);
      expect(PersonalizationRankingConfig.clampScore(0.42), 0.42);
    });

    test('weights are bounded and documented', () {
      expect(PersonalizationRankingConfig.scoreMin, 0);
      expect(PersonalizationRankingConfig.scoreMax, 1);
      expect(PersonalizationRankingConfig.weightImpression,
          lessThan(PersonalizationRankingConfig.weightOpen));
      expect(PersonalizationRankingConfig.weightOpen,
          lessThan(PersonalizationRankingConfig.weightBookmark));
      expect(PersonalizationRankingConfig.maxMergedCandidates, lessThanOrEqualTo(100));
    });

    test('candidate pools are bounded', () {
      final sum = PersonalizationRankingConfig.maxCategoryCandidates +
          PersonalizationRankingConfig.maxPublisherCandidates +
          PersonalizationRankingConfig.maxRegionalCandidates +
          PersonalizationRankingConfig.maxLatestFallback;
      expect(sum, greaterThan(PersonalizationRankingConfig.maxMergedCandidates));
    });
  });
}
