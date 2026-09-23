/// Documented ranking / signal constants for Phase 5 personalization.
///
/// Ranking is performed on the **backend**. Mobile does not re-score feeds.
/// These values mirror the preferred backend PersonalizationRankingService
/// contract so client and server stay aligned.
abstract final class PersonalizationRankingConfig {
  /// Soft min/max for normalized ranking scores.
  static const double scoreMin = 0.0;
  static const double scoreMax = 1.0;

  /// Recency half-life in hours (deterministic exponential decay on backend).
  static const double recencyHalfLifeHours = 36;

  /// Relative signal strengths (documentation / backend alignment).
  static const double weightRecency = 0.30;
  static const double weightCategory = 0.25;
  static const double weightPublisher = 0.20;
  static const double weightRegion = 0.15;
  static const double weightLanguage = 0.10;

  /// Engagement influence (bounded; one click must not dominate).
  static const double weightBookmark = 0.12;
  static const double weightShare = 0.10;
  static const double weightOpen = 0.06;
  static const double weightImpression = 0.01;

  /// Already-seen suppression window (hours) for opens/reads.
  static const int seenSuppressionHours = 48;

  /// Candidate pool caps (backend).
  static const int maxCategoryCandidates = 40;
  static const int maxPublisherCandidates = 30;
  static const int maxRegionalCandidates = 30;
  static const int maxLatestFallback = 40;
  static const int maxMergedCandidates = 100;

  static double clampScore(double value) {
    if (value < scoreMin) return scoreMin;
    if (value > scoreMax) return scoreMax;
    return value;
  }
}
