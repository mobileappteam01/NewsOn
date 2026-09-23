import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/constants/deep_link_constants.dart';

void main() {
  test('parseArticleId from custom scheme', () {
    final uri = Uri.parse(
      'newson://news?articleId=709cfe94f5f24201ffd04d0610bcd2dd',
    );
    expect(
      DeepLinkConstants.parseArticleId(uri),
      '709cfe94f5f24201ffd04d0610bcd2dd',
    );
    expect(DeepLinkConstants.isNewsDeepLink(uri), isTrue);
    expect(DeepLinkConstants.isV2ArticleDeepLink(uri), isFalse);
  });

  test('parseArticleId from https path', () {
    final uri = Uri.parse(
      'https://api.newson.app/news/709cfe94f5f24201ffd04d0610bcd2dd',
    );
    expect(
      DeepLinkConstants.parseArticleId(uri),
      '709cfe94f5f24201ffd04d0610bcd2dd',
    );
    expect(DeepLinkConstants.isNewsDeepLink(uri), isTrue);
    expect(DeepLinkConstants.isV2ArticleDeepLink(uri), isFalse);
  });

  test('buildAppDeepLink roundtrip', () {
    const id = 'abc123';
    final link = DeepLinkConstants.buildAppDeepLink(id);
    expect(DeepLinkConstants.parseArticleId(link), id);
  });

  test('V2 https share link parses as V2 only', () {
    const id = '6ab1d4fda5abc256076d157e';
    final uri = DeepLinkConstants.buildV2HttpsDeepLink(id);
    expect(
      uri.toString(),
      'https://api.newson.app/v2/article/$id',
    );
    expect(DeepLinkConstants.isV2ArticleDeepLink(uri), isTrue);
    expect(DeepLinkConstants.parseV2ArticleId(uri), id);
    expect(DeepLinkConstants.parseArticleId(uri), isNull);
    expect(DeepLinkConstants.linkKey(uri), 'v2:$id');
  });

  test('V2 custom scheme share link parses as V2 only', () {
    const id = '6ab1d4fda5abc256076d157e';
    final uri = DeepLinkConstants.buildV2AppDeepLink(id);
    expect(uri.toString(), 'newson://v2/article/$id');
    expect(DeepLinkConstants.isV2ArticleDeepLink(uri), isTrue);
    expect(DeepLinkConstants.parseV2ArticleId(uri), id);
    expect(DeepLinkConstants.parseArticleId(uri), isNull);
  });

  test('V1 /news/ is never classified as V2', () {
    final uri = Uri.parse(
      'https://api.newson.app/news/6ab1d4fda5abc256076d157e',
    );
    expect(DeepLinkConstants.isV2ArticleDeepLink(uri), isFalse);
    expect(DeepLinkConstants.parseArticleId(uri), '6ab1d4fda5abc256076d157e');
  });
}
