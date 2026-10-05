import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/news_article.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:newson/features/article_feedback/data/v2_article_feedback_api.dart';
import 'package:newson/features/article_feedback/domain/v2_article_feedback.dart';
import 'package:newson/features/article_feedback/presentation/v2_article_feedback_coordinator.dart';
import 'package:newson/features/article_feedback/presentation/v2_article_feedback_sheets.dart';
import 'package:newson/features/home_v2/presentation/widgets/v2_article_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_setup.dart';
import 'fake_api_service.dart';

final _article = NewsArticle(title: 'Story a1', articleId: 'a1');

class _Rig {
  _Rig({this.loggedIn = true}) {
    coordinator = V2ArticleFeedbackCoordinator(
      api: V2ArticleFeedbackApi(apiService: http, readToken: () => 'tok'),
      isLoggedIn: () => loggedIn,
      promptSignIn: (_) => signInPrompts++,
    );
  }

  final FakeApiService http = FakeApiService();
  late final V2ArticleFeedbackCoordinator coordinator;
  bool loggedIn;
  int signInPrompts = 0;
  final List<NewsArticle> hidden = [];
  V2HideResult hideResult = V2HideResult.hidden;

  Future<V2HideResult> hide(NewsArticle article) async {
    hidden.add(article);
    return hideResult;
  }

  Widget app({ThemeData? theme}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: V2ReaderActionButtons(
                bookmarked: false,
                onBookmark: () {},
                onShare: () {},
                onMore: () =>
                    coordinator.openMenu(context, _article, hide: hide),
              ),
            ),
          ),
        ),
      );
}

Future<void> _setLanguage(WidgetTester tester, String code) async {
  await tester.runAsync(
    () => DynamicLocalizationService().setLanguage(code, forceReload: true),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(V2ReaderActionButtons.moreButtonKey));
  await tester.pumpAndSettle();
}

Future<void> _openReport(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.byKey(V2ArticleOverflowSheet.reportKey));
  await tester.pumpAndSettle();
}

Future<void> _selectReason(WidgetTester tester, V2ReportReason reason) async {
  await tester.ensureVisible(find.byKey(V2ReportSheet.reasonKey(reason)));
  await tester.tap(find.byKey(V2ReportSheet.reasonKey(reason)));
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(V2ReportSheet.submitKey));
  await tester.tap(find.byKey(V2ReportSheet.submitKey));
  await tester.pump();
}

bool _submitEnabled(WidgetTester tester) => tester
    .widget<FilledButton>(find.byKey(V2ReportSheet.submitKey))
    .enabled;

String _commentText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(V2ReportSheet.commentKey))
    .controller!
    .text;

void main() {
  ensureTestBinding();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('V2 card action row shows ⋮ with an accessible label',
      (tester) async {
    await _setLanguage(tester, 'en');
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_Rig().app());

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(V2ReaderActionButtons.moreButtonKey)),
      containsSemantics(
        label: 'More options',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('without onMore the action row is unchanged (no ⋮)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V2ReaderActionButtons(
          bookmarked: true,
          onBookmark: () {},
          onShare: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    expect(find.byKey(V2ReaderActionButtons.moreButtonKey), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  test('V1 cards do not use the V2 feedback controls', () {
    for (final path in [
      'lib/core/widgets/news_card.dart',
      'lib/core/widgets/breaking_news_card.dart',
      'lib/features/home/presentation/widgets/latest_news_card.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final marker in [
        'article_feedback',
        'V2ReaderActionButtons',
        'more_vert',
        'not-interested',
      ]) {
        expect(source.contains(marker), isFalse, reason: '$path: $marker');
      }
    }
  });

  testWidgets('⋮ opens the overflow menu with both options', (tester) async {
    await _setLanguage(tester, 'en');
    await tester.pumpWidget(_Rig().app());
    await _openMenu(tester);

    expect(find.byKey(V2ArticleOverflowSheet.notInterestedKey), findsOneWidget);
    expect(find.byKey(V2ArticleOverflowSheet.reportKey), findsOneWidget);
    expect(find.text('Not Interested'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
  });

  group('Not Interested', () {
    testWidgets('hides the article for a signed-in user', (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig();
      await tester.pumpWidget(rig.app());
      await _openMenu(tester);
      await tester.tap(find.byKey(V2ArticleOverflowSheet.notInterestedKey));
      await tester.pumpAndSettle();

      expect(rig.hidden, [_article]);
      expect(find.byType(V2ArticleOverflowSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('failure shows the error message', (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig()..hideResult = V2HideResult.failed;
      await tester.pumpWidget(rig.app());
      await _openMenu(tester);
      await tester.tap(find.byKey(V2ArticleOverflowSheet.notInterestedKey));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't hide this story. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets('signed out: sign-in prompt, nothing hidden or sent',
        (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig(loggedIn: false);
      await tester.pumpWidget(rig.app());
      await _openMenu(tester);
      await tester.tap(find.byKey(V2ArticleOverflowSheet.notInterestedKey));
      await tester.pumpAndSettle();

      expect(rig.signInPrompts, 1);
      expect(rig.hidden, isEmpty);
      expect(rig.http.posts, isEmpty);
    });
  });

  group('Report', () {
    testWidgets('sheet opens with the title and all five reasons',
        (tester) async {
      await _setLanguage(tester, 'en');
      await tester.pumpWidget(_Rig().app());
      await _openReport(tester);

      expect(find.text('Report this news'), findsOneWidget);
      for (final label in [
        'Offensive content',
        'Harassment or abuse',
        'Misinformation',
        'Spam or misleading',
        'Other',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final reason in V2ReportReason.values) {
        expect(find.byKey(V2ReportSheet.reasonKey(reason)), findsOneWidget);
      }
      expect(find.text('Tell us more'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);
    });

    testWidgets('selecting a reason checks it and enables Submit',
        (tester) async {
      await _setLanguage(tester, 'en');
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_Rig().app());
      await _openReport(tester);

      expect(_submitEnabled(tester), isFalse);
      await _selectReason(tester, V2ReportReason.misinformation);

      expect(
        tester
            .widget<RadioGroup<V2ReportReason>>(
                find.byType(RadioGroup<V2ReportReason>))
            .groupValue,
        V2ReportReason.misinformation,
      );
      expect(
        tester.getSemantics(
            find.byKey(V2ReportSheet.reasonKey(V2ReportReason.misinformation))),
        containsSemantics(label: 'Misinformation', isChecked: true),
      );
      expect(_submitEnabled(tester), isTrue);

      await _selectReason(tester, V2ReportReason.spamMisleading);
      expect(
        tester
            .widget<RadioGroup<V2ReportReason>>(
                find.byType(RadioGroup<V2ReportReason>))
            .groupValue,
        V2ReportReason.spamMisleading,
      );
      handle.dispose();
    });

    testWidgets('"Other" needs meaningful text before Submit is enabled',
        (tester) async {
      await _setLanguage(tester, 'en');
      await tester.pumpWidget(_Rig().app());
      await _openReport(tester);

      await _selectReason(tester, V2ReportReason.other);
      expect(_submitEnabled(tester), isFalse);
      expect(find.text("Please tell us what's wrong"), findsOneWidget);

      await tester.enterText(find.byKey(V2ReportSheet.commentKey), '   ');
      await tester.pump();
      expect(_submitEnabled(tester), isFalse);

      await tester.enterText(find.byKey(V2ReportSheet.commentKey), '?!.');
      await tester.pump();
      expect(_submitEnabled(tester), isFalse);

      await tester.enterText(
          find.byKey(V2ReportSheet.commentKey), 'Fake photo');
      await tester.pump();
      expect(_submitEnabled(tester), isTrue);
      expect(find.text("Please tell us what's wrong"), findsNothing);
    });

    testWidgets('comment is capped at 500 characters with a counter',
        (tester) async {
      await _setLanguage(tester, 'en');
      await tester.pumpWidget(_Rig().app());
      await _openReport(tester);

      await tester.enterText(find.byKey(V2ReportSheet.commentKey), 'x' * 650);
      await tester.pump();
      expect(_commentText(tester).length, V2ReportForm.maxCommentLength);
      expect(find.text('500/500'), findsOneWidget);

      await tester.enterText(find.byKey(V2ReportSheet.commentKey), 'hello');
      await tester.pump();
      expect(find.text('5/500'), findsOneWidget);
    });

    test('length cap never splits a character', () {
      const formatter = V2ReportCommentLengthFormatter();
      final text = '${'x' * 499}😀😀';
      final out = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );
      expect(out.text, 'x' * 499);
    });

    testWidgets('submit sends the trimmed body, closes, shows success',
        (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig();
      await tester.pumpWidget(rig.app());
      await _openReport(tester);

      await _selectReason(tester, V2ReportReason.harassmentAbuse);
      await tester.enterText(
          find.byKey(V2ReportSheet.commentKey), '  Abusive headline  ');
      await tester.pump();
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      final call = rig.http.posts.single;
      expect(call.path, '/api/v2/articles/a1/report');
      expect(call.useV2Host, isTrue);
      expect(call.baseUrlOverride, isNull);
      expect(call.body, {
        'reason': 'harassment_abuse',
        'comment': 'Abusive headline',
      });
      expect(find.byType(V2ReportSheet), findsNothing);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(rig.coordinator.hasReported('a1'), isTrue);
    });

    testWidgets('an accepted report cannot be submitted again',
        (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig();
      await tester.pumpWidget(rig.app());
      await _openReport(tester);
      await _selectReason(tester, V2ReportReason.misinformation);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(rig.http.posts, hasLength(1));

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _openReport(tester);

      expect(find.byType(V2ReportSheet), findsNothing);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(rig.http.posts, hasLength(1));
    });

    testWidgets('double tap on Submit sends one request', (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig();
      final gate = Completer<void>();
      rig.http.gate = gate;
      await tester.pumpWidget(rig.app());
      await _openReport(tester);
      await _selectReason(tester, V2ReportReason.misinformation);

      await _tapSubmit(tester);
      expect(_submitEnabled(tester), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(V2ReportSheet.submitKey), warnIfMissed: false);
      await tester.pump();
      expect(rig.http.posts, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(rig.http.posts, hasLength(1));
      expect(find.text('Report submitted'), findsOneWidget);
    });

    testWidgets('network failure keeps the form and allows retry',
        (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig();
      rig.http.response = FakeApiService.failure(503);
      await tester.pumpWidget(rig.app());
      await _openReport(tester);

      await _selectReason(tester, V2ReportReason.other);
      await tester.enterText(
          find.byKey(V2ReportSheet.commentKey), 'Doctored image');
      await tester.pump();
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.byType(V2ReportSheet), findsOneWidget);
      expect(find.byKey(V2ReportSheet.errorKey), findsOneWidget);
      expect(
        find.text("Couldn't submit your report. Please try again."),
        findsOneWidget,
      );
      expect(_commentText(tester), 'Doctored image');
      expect(
        tester
            .widget<RadioGroup<V2ReportReason>>(
                find.byType(RadioGroup<V2ReportReason>))
            .groupValue,
        V2ReportReason.other,
      );
      expect(_submitEnabled(tester), isTrue);
      expect(find.text('Report submitted'), findsNothing);
      expect(rig.coordinator.hasReported('a1'), isFalse);

      rig.http.response = FakeApiService.ok();
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(rig.http.posts, hasLength(2));
      expect(rig.http.posts.last.body,
          {'reason': 'other', 'comment': 'Doctored image'});
      expect(find.byType(V2ReportSheet), findsNothing);
      expect(find.text('Report submitted'), findsOneWidget);
    });

    testWidgets('closing the sheet during the request does not crash',
        (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig();
      final gate = Completer<void>();
      rig.http.gate = gate;
      await tester.pumpWidget(rig.app());
      await _openReport(tester);
      await _selectReason(tester, V2ReportReason.misinformation);
      await _tapSubmit(tester);

      Navigator.of(tester.element(find.byType(V2ReportSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(V2ReportSheet), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rig.coordinator.hasReported('a1'), isTrue);
      expect(find.text('Report submitted'), findsOneWidget);
    });

    testWidgets('signed out: sign-in prompt, no sheet, nothing sent',
        (tester) async {
      await _setLanguage(tester, 'en');
      final rig = _Rig(loggedIn: false);
      await tester.pumpWidget(rig.app());
      await _openReport(tester);

      expect(rig.signInPrompts, 1);
      expect(find.byType(V2ReportSheet), findsNothing);
      expect(rig.http.posts, isEmpty);
    });
  });

  group('narrow width, languages, text scale', () {
    const languages = ['en', 'ta', 'hi', 'ml', 'te', 'kn'];

    for (final code in languages) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$code at 320px, text scale $scale: no overflow',
            (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _setLanguage(tester, code);
          final l10n = DynamicLocalizationService();
          final rig = _Rig();

          await tester.pumpWidget(rig.app(theme: ThemeData.dark()));
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(V2ReaderActionButtons)),
            ).scale(10),
            10 * scale,
          );
          expect(tester.takeException(), isNull);

          await _openMenu(tester);
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.translate('v2FeedbackNotInterested')),
              findsOneWidget);
          expect(find.text(l10n.translate('v2FeedbackReport')),
              findsOneWidget);

          await tester.tap(find.byKey(V2ArticleOverflowSheet.reportKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.translate('v2FeedbackReportTitle')),
              findsOneWidget);
          expect(find.text(l10n.translate('v2FeedbackReasonOther')),
              findsOneWidget);

          await _selectReason(tester, V2ReportReason.other);
          expect(find.text(l10n.translate('v2FeedbackOtherRequired')),
              findsOneWidget);
          await tester.ensureVisible(find.byKey(V2ReportSheet.submitKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.translate('v2FeedbackSubmit')),
              findsOneWidget);
        });
      }
    }

    test('every feedback key is translated in each supported language',
        () async {
      const keys = [
        'v2FeedbackMoreOptions',
        'v2FeedbackNotInterested',
        'v2FeedbackReport',
        'v2FeedbackReportTitle',
        'v2FeedbackReasonOffensive',
        'v2FeedbackReasonHarassment',
        'v2FeedbackReasonMisinformation',
        'v2FeedbackReasonSpam',
        'v2FeedbackReasonOther',
        'v2FeedbackTellUsMore',
        'v2FeedbackOtherRequired',
        'v2FeedbackSubmit',
        'v2FeedbackReportSubmitted',
        'v2FeedbackReportFailed',
        'v2FeedbackNotInterestedFailed',
      ];
      final service = DynamicLocalizationService();
      await service.setLanguage('en', forceReload: true);
      final english = {for (final k in keys) k: service.translate(k)};
      for (final code in languages.skip(1)) {
        await service.setLanguage(code, forceReload: true);
        for (final key in keys) {
          expect(service.hasTranslation(key), isTrue, reason: '$code/$key');
          expect(service.translate(key), isNot(english[key]),
              reason: '$code/$key is still English');
        }
      }
      await service.setLanguage('en', forceReload: true);
    });
  });
}
