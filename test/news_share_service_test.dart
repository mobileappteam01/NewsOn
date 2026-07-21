import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/services/news_share_service.dart';

void main() {
  group('NewsShareService.buildShareText', () {
    test('includes title, CTA, and link — omits description', () {
      final article = NewsArticle(
        articleId: '930a8436b94a3e538164f95859055261',
        title:
            'தவறு செய்தால் அமைச்சர் பதவி பறிக்கப்படும்.. யாராக இருந்தாலும் சரி! அமைச்சர்களுக்கு விஜய் எச்சரிக்கை',
        description:
            'Ministerial post: CM Vijay has stated that the ministerial post '
            'of anyone found to have committed wrongdoing will be stripped away...',
      );

      const cta =
          '🔥 இந்த செய்தியின் முழு உண்மை NewsOn-ல் — இப்போதே படியுங்கள் 👇';
      final text = NewsShareService.buildShareText(
        article,
        curiousCta: cta,
      );

      expect(text, contains(article.title));
      expect(text, contains(cta));
      expect(
        text,
        contains(
          'https://api.newson.app/news/930a8436b94a3e538164f95859055261',
        ),
      );
      expect(text, isNot(contains('Ministerial post')));
      expect(text, isNot(contains(article.description!)));

      // Exact shape: title, blank line, CTA, link
      expect(
        text,
        '''தவறு செய்தால் அமைச்சர் பதவி பறிக்கப்படும்.. யாராக இருந்தாலும் சரி! அமைச்சர்களுக்கு விஜய் எச்சரிக்கை

🔥 இந்த செய்தியின் முழு உண்மை NewsOn-ல் — இப்போதே படியுங்கள் 👇
https://api.newson.app/news/930a8436b94a3e538164f95859055261''',
      );
    });

    test('with no articleId shares title only (no CTA/link)', () {
      final article = NewsArticle(
        title: 'Headline only',
        description: 'Should never appear in share text',
      );

      final text = NewsShareService.buildShareText(
        article,
        curiousCta: '🔥 CTA',
      );

      expect(text, 'Headline only');
      expect(text, isNot(contains('Should never appear')));
      expect(text, isNot(contains('CTA')));
      expect(text, isNot(contains('https://')));
    });

    test('blank description is ignored the same as present description', () {
      final withDesc = NewsArticle(
        articleId: 'abc123',
        title: 'Title A',
        description: 'Long body that must not be shared',
      );
      final withoutDesc = NewsArticle(
        articleId: 'abc123',
        title: 'Title A',
      );

      const cta = '🔥 Read on NewsOn';
      expect(
        NewsShareService.buildShareText(withDesc, curiousCta: cta),
        NewsShareService.buildShareText(withoutDesc, curiousCta: cta),
      );
    });

    test('trims whitespace articleId as missing', () {
      final article = NewsArticle(
        articleId: '   ',
        title: 'No id',
        description: 'body',
      );
      expect(
        NewsShareService.buildShareText(article, curiousCta: 'cta'),
        'No id',
      );
    });
  });
}
