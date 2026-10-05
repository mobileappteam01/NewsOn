import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_actions.dart';
import 'package:newson/features/news_detail/presentation/full_article_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';

const _readFullArticle = {
  'en': 'Read Full Article',
  'ta': 'முழு கட்டுரையைப் படிக்கவும்',
  'hi': 'पूरा लेख पढ़ें',
  'ml': 'പൂർണ്ണ ലേഖനം വായിക്കുക',
  'te': 'పూర్తి కథనాన్ని చదవండి',
  'kn': 'ಪೂರ್ಣ ಲೇಖನ ಓದಿ',
};

const _invalidUrl = {
  'en': 'Invalid article URL',
  'ta': 'தவறான கட்டுரை இணைப்பு',
  'hi': 'अमान्य लेख लिंक',
  'ml': 'അസാധുവായ ലേഖന ലിങ്ക്',
  'te': 'చెల్లని కథనం లింక్',
  'kn': 'ಅಮಾನ್ಯ ಲೇಖನ ಲಿಂಕ್',
};

const _retry = {
  'en': 'Retry',
  'ta': 'மீண்டும் முயற்சிக்க',
  'hi': 'पुनः प्रयास करें',
  'ml': 'വീണ്ടും ശ്രമിക്കുക',
  'te': 'మళ్లీ ప్రయత్నించండి',
  'kn': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
};

Future<void> _setLanguage(WidgetTester tester, String code) async {
  await tester.runAsync(
    () => DynamicLocalizationService().setLanguage(code, forceReload: true),
  );
}

void main() {
  ensureTestBinding();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await DynamicLocalizationService().setLanguage('en', forceReload: true);
  });

  for (final entry in _readFullArticle.entries) {
    final code = entry.key;

    testWidgets('Read Full Article text and semantics in $code',
        (tester) async {
      await _setLanguage(tester, code);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: V2ArticleActions(onViewFullArticle: () => opened = true),
        ),
      ));
      await tester.pump();

      expect(find.text(entry.value), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(entry.value))),
          findsWidgets);
      if (code != 'en') {
        expect(find.text('Read Full Article'), findsNothing);
      }
      await tester.tap(find.text(entry.value));
      expect(opened, isTrue);
    });

    testWidgets('full article error state is localized in $code',
        (tester) async {
      await _setLanguage(tester, code);
      await tester.pumpWidget(const MaterialApp(
        home: FullArticleScreen(url: 'not a url', title: 'Story'),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text(_invalidUrl[code]!), findsOneWidget);
      expect(find.text(_retry[code]!), findsOneWidget);
    });
  }
}
