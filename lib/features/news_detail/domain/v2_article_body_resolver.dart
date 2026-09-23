import '../../../data/models/news_article.dart';

/// Resolves the in-app article body for V2 Detail (V1-compatible precedence).
///
/// Prefer stored full [NewsArticle.content], then [NewsArticle.description].
/// Never uses [NewsArticle.v2Summary] / NewsOn Cut as the article body.
abstract final class V2ArticleBodyResolver {
  static const _paidPlanPlaceholder = 'ONLY AVAILABLE IN PAID PLANS';

  /// Raw body string, or null when nothing usable is stored.
  static String? rawBody(NewsArticle article) {
    final content = article.content?.trim();
    if (content != null &&
        content.isNotEmpty &&
        content != _paidPlanPlaceholder) {
      return content;
    }

    final description = article.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }

    return null;
  }

  /// True when the body looks like HTML markup (not plain text).
  static bool looksLikeHtml(String body) {
    final t = body.trimLeft();
    if (t.startsWith('<')) return true;
    return RegExp(r'<\/?[a-zA-Z][^>]*>').hasMatch(body);
  }

  /// Split plain text into paragraph blocks for readable layout.
  static List<String> paragraphs(String body) {
    final normalized = body
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const [];

    final byBlank = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (byBlank.length > 1) return byBlank;

    final byLine = normalized
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (byLine.length > 1) return byLine;

    return [normalized];
  }
}
