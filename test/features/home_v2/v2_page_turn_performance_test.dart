import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/features/home_v2/presentation/v2_reader_page_cache.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_image.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_vintage_paper_background.dart';
// CachedNetworkImage renders through OctoImage; the test reads its provider.
// ignore: depend_on_referenced_packages
import 'package:octo_image/octo_image.dart';

NewsArticle _article(String id) =>
    NewsArticle(articleId: id, newsId: id, title: 'title $id');

void main() {
  group('page cache', () {
    test('same article and inputs reuse the built page', () {
      final cache = V2ReaderPageCache()..prepare(1, 3);
      final a = _article('a');
      var builds = 0;
      Widget build() {
        builds++;
        return const SizedBox();
      }

      final first = cache.get(0, a, (0, false), build);
      final second = cache.get(0, a, (0, false), build);
      expect(second, same(first));
      expect(builds, 1);
      expect(first, isA<RepaintBoundary>());
    });

    test('changed inputs or another article instance rebuild the page', () {
      final cache = V2ReaderPageCache()..prepare(1, 3);
      final a = _article('a');
      final first = cache.get(0, a, (0, false), () => const SizedBox());
      final bookmarked = cache.get(0, a, (0, true), () => const SizedBox());
      expect(bookmarked, isNot(same(first)));
      final edited =
          cache.get(0, _article('a'), (0, true), () => const SizedBox());
      expect(edited, isNot(same(bookmarked)));
    });

    test('a new book drops every page; a shorter one drops the tail', () {
      final cache = V2ReaderPageCache()..prepare(1, 3);
      final a = _article('a');
      final b = _article('b');
      final pageA = cache.get(0, a, 0, () => const SizedBox());
      final pageB = cache.get(2, b, 2, () => const SizedBox());

      cache.prepare(1, 2);
      expect(cache.get(0, a, 0, () => const SizedBox()), same(pageA));
      expect(cache.get(2, b, 2, () => const SizedBox()), isNot(same(pageB)));

      cache.prepare(2, 3);
      expect(cache.get(0, a, 0, () => const SizedBox()), isNot(same(pageA)));
    });

    test('ad pages are cached by slot', () {
      final cache = V2ReaderPageCache()..prepare(1, 3);
      final ad = cache.get(1, null, 0, () => const SizedBox());
      expect(cache.get(1, null, 0, () => const SizedBox()), same(ad));
      expect(cache.get(1, null, 1, () => const SizedBox()), isNot(same(ad)));
    });

    test('identity keys compare by instance, not contents', () {
      final keys = {'sports'};
      expect(V2IdentityKey(keys), V2IdentityKey(keys));
      expect(V2IdentityKey(keys), isNot(const V2IdentityKey(<String>{'sports'})));
    });
  });

  group('image decode', () {
    test('prefetch fills the cache entry the hero image reads', () async {
      const url = 'https://cdn.example/a.jpg';
      final shown = OctoImage(
        image: const CachedNetworkImageProvider(url),
        memCacheWidth: V2ArticleImage.decodeWidth,
      ).image;
      final prefetched = V2ArticleImage.provider(url);
      expect(prefetched, isA<ResizeImage>());
      expect(
        await prefetched.obtainKey(ImageConfiguration.empty),
        await shown.obtainKey(ImageConfiguration.empty),
      );
      expect(
        await prefetched.obtainKey(ImageConfiguration.empty),
        isNot(
          await const CachedNetworkImageProvider(
            url,
          ).obtainKey(ImageConfiguration.empty),
        ),
        reason: 'a full-size decode would be a second cache entry',
      );
    });

    test('hero image decodes at the shared width', () {
      final src = File(
        'lib/features/home_v2/presentation/widgets/v2_article_image.dart',
      ).readAsStringSync();
      expect(src.contains('memCacheWidth: decodeWidth'), isTrue);
    });

    test('Home prefetches the hero provider when no turn is animating', () {
      final src = File(
        'lib/features/home_v2/presentation/v2_reader_home.dart',
      ).readAsStringSync();
      expect(
          src.contains('precacheImage(V2ArticleImage.provider(url)'), isTrue);
      expect(src.contains('CachedNetworkImageProvider('), isFalse);
      expect(src.contains('Priority.idle'), isTrue);
    });
  });

  testWidgets('paper texture paints without an Opacity layer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2VintagePaperBackground()),
    );
    final paper = find.byType(V2VintagePaperBackground);
    expect(
      find.descendant(of: paper, matching: find.byType(Opacity)),
      findsNothing,
    );
    final image = tester.widget<Image>(
      find.descendant(of: paper, matching: find.byType(Image)),
    );
    expect(image.opacity?.value, closeTo(0.34, 1e-9));
  });
}
