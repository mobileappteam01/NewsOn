/// Sends "Not Interested" for one article id; throws when not accepted.
typedef V2NotInterestedSender = Future<void> Function(String articleId);

enum V2HideResult {
  hidden,

  /// A hide for this article is already in flight or done.
  duplicate,

  /// Not in the visible feed, or it has no id.
  unavailable,

  /// The server did not accept it; the article is back in the feed.
  failed,
}

/// Report reasons accepted by `POST /api/v2/articles/:articleId/report`.
/// [id] is the wire value and must stay stable.
enum V2ReportReason {
  offensiveContent('offensive_content'),
  harassmentAbuse('harassment_abuse'),
  misinformation('misinformation'),
  spamMisleading('spam_misleading'),
  other('other');

  const V2ReportReason(this.id);

  final String id;
}

/// Client-side rules for the report form. The server validates the same
/// contract; these only decide when Submit is enabled.
abstract final class V2ReportForm {
  /// Counted in UTF-16 code units, the unit the server measures.
  static const int maxCommentLength = 500;

  /// "Other" needs at least this many characters, including a letter or digit.
  static const int minOtherCommentLength = 3;

  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static String normalizeComment(String raw) => raw.trim();

  static bool isCommentValid(V2ReportReason reason, String raw) {
    final comment = normalizeComment(raw);
    if (comment.length > maxCommentLength) return false;
    if (reason != V2ReportReason.other) return true;
    return comment.runes.length >= minOtherCommentLength &&
        _letterOrDigit.hasMatch(comment);
  }

  static bool canSubmit(V2ReportReason? reason, String raw) =>
      reason != null && isCommentValid(reason, raw);
}
