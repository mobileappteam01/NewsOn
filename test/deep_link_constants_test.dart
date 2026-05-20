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
  });

  test('buildAppDeepLink roundtrip', () {
    const id = 'abc123';
    final link = DeepLinkConstants.buildAppDeepLink(id);
    expect(DeepLinkConstants.parseArticleId(link), id);
  });
}
