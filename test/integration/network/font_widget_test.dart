@Tags(['integration', 'network'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_setup.dart';
import 'package:newson/core/services/font_manager.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/remote_config_model.dart';

import '../../font_test_utils.dart';
// import 'package:newson/test/font_test_utils.dart';

/// Widget tests for font integration in actual UI components
void main() {
  ensureTestBinding();

  group('Font Widget Tests', () {
    late RemoteConfigModel testConfig;

    setUp(() {
      testConfig = RemoteConfigModel(
        appName: 'NewsOn Test',
        primaryColor: '#C70000',
        backgroundColor: '#FFFFFF',
        cardBackgroundColor: '#F5F5F5',
        textPrimaryColor: '#000000',
        textSecondaryColor: '#666666',
        displayLargeFontSize: 32.0,
        displayMediumFontSize: 28.0,
        displaySmallFontSize: 24.0,
        headlineMediumFontSize: 20.0,
        titleLargeFontSize: 18.0,
        titleMediumFontSize: 16.0,
        bodyLargeFontSize: 16.0,
        bodyMediumFontSize: 14.0,
        bodySmallFontSize: 12.0,
        borderRadius: 12.0,
        cardElevation: 4.0,
      );
    });

    group('FontManager Widget Tests', () {
      testWidgets('should render all FontManager styles correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: const SampleTextWidgets(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify all text widgets are rendered
        expect(find.text('Breaking News Headline'), findsOneWidget);
        expect(find.text('Technology'), findsOneWidget);
        expect(find.text('2 hours ago'), findsOneWidget);
        expect(find.text('This is the news content...'), findsOneWidget);
        expect(find.text('Headline 1'), findsOneWidget);
        expect(find.text('Body Text 1'), findsOneWidget);
        expect(find.text('Thin Text'), findsOneWidget);
        expect(find.text('Bold Text'), findsOneWidget);

        // Verify all text widgets use custom font
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);

        // Print statistics for debugging
        FontTestUtils.printFontUsageStats(tester);
      });

      testWidgets('should apply correct font weights',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: const SampleTextWidgets(),
          ),
        );

        await tester.pumpAndSettle();

        // Test specific font weights
        final thinText =
            FontTestUtils.requireTextWidgetByContent(tester, 'Thin Text');
        expect(FontTestUtils.getFontWeight(thinText), FontWeight.w100);

        final boldText =
            FontTestUtils.requireTextWidgetByContent(tester, 'Bold Text');
        expect(FontTestUtils.getFontWeight(boldText), FontWeight.w700);

        final blackText =
            FontTestUtils.requireTextWidgetByContent(tester, 'Black Text');
        expect(FontTestUtils.getFontWeight(blackText), FontWeight.w900);
      });

      testWidgets('should apply correct font sizes',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: const SampleTextWidgets(),
          ),
        );

        await tester.pumpAndSettle();

        // Test specific font sizes
        final headline1 =
            FontTestUtils.requireTextWidgetByContent(tester, 'Headline 1');
        expect(FontTestUtils.getFontSize(headline1), 32);

        final headline2 =
            FontTestUtils.requireTextWidgetByContent(tester, 'Headline 2');
        expect(FontTestUtils.getFontSize(headline2), 28);

        final body1 =
            FontTestUtils.requireTextWidgetByContent(tester, 'Body Text 1');
        expect(FontTestUtils.getFontSize(body1), 16);

        final caption =
            FontTestUtils.requireTextWidgetByContent(tester, 'Caption Text');
        expect(FontTestUtils.getFontSize(caption), 12);
      });
    });

    group('Theme Font Integration Tests', () {
      testWidgets('should apply custom fonts through theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getLightTheme(testConfig),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final textTheme = Theme.of(context).textTheme;
                  return Column(
                    children: [
                      Text('Display Large', style: textTheme.displayLarge),
                      Text('Title Large', style: textTheme.titleLarge),
                      Text('Body Large', style: textTheme.bodyLarge),
                      Text('Body Medium', style: textTheme.bodyMedium),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify theme-styled sample texts use production UI font
        for (final label in [
          'Display Large',
          'Title Large',
          'Body Large',
          'Body Medium',
        ]) {
          final text =
              FontTestUtils.requireTextWidgetByContent(tester, label);
          expect(
            FontTestUtils.isProductionUiFont(FontTestUtils.getFontFamily(text)),
            isTrue,
          );
        }

        final displayLarge =
            FontTestUtils.requireTextWidgetByContent(tester, 'Display Large');
        expect(FontTestUtils.getFontWeight(displayLarge), FontWeight.bold);

        final titleLarge =
            FontTestUtils.requireTextWidgetByContent(tester, 'Title Large');
        expect(FontTestUtils.getFontWeight(titleLarge), FontWeight.w500);

        final bodyLarge =
            FontTestUtils.requireTextWidgetByContent(tester, 'Body Large');
        expect(FontTestUtils.getFontWeight(bodyLarge), FontWeight.w400);
      });

      testWidgets('should apply custom fonts in dark theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getDarkTheme(testConfig),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final textTheme = Theme.of(context).textTheme;
                  return Column(
                    children: [
                      Text('Display Large', style: textTheme.displayLarge),
                      Text('Title Large', style: textTheme.titleLarge),
                      Text('Body Large', style: textTheme.bodyLarge),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        for (final label in ['Display Large', 'Title Large', 'Body Large']) {
          final text =
              FontTestUtils.requireTextWidgetByContent(tester, label);
          expect(
            FontTestUtils.isProductionUiFont(FontTestUtils.getFontFamily(text)),
            isTrue,
          );
        }

        final displayLarge =
            FontTestUtils.requireTextWidgetByContent(tester, 'Display Large');
        expect(FontTestUtils.getFontWeight(displayLarge), FontWeight.bold);

        final bodyLarge =
            FontTestUtils.requireTextWidgetByContent(tester, 'Body Large');
        expect(FontTestUtils.getFontWeight(bodyLarge), FontWeight.w400);
      });
    });

    group('News-Specific Font Tests', () {
      testWidgets('should apply news-specific font styles',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('Breaking News Today', style: FontManager.newsTitle),
                Text('Technology', style: FontManager.newsCategory),
                Text('5 minutes ago', style: FontManager.newsTimestamp),
                Text('Full article content goes here...',
                    style: FontManager.newsContent),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify news title style
        final newsTitle = FontTestUtils.requireTextWidgetByContent(
          tester,
          'Breaking News Today',
        );
        expect(FontTestUtils.usesNewsTitleStyle(newsTitle), isTrue);
        expect(
          FontTestUtils.isProductionUiFont(FontTestUtils.getFontFamily(newsTitle)),
          isTrue,
        );
        expect(FontTestUtils.getFontWeight(newsTitle), FontWeight.bold);

        // Verify news category style
        final newsCategory =
            FontTestUtils.requireTextWidgetByContent(tester, 'Technology');
        expect(FontTestUtils.usesNewsCategoryStyle(newsCategory), isTrue);
        expect(
          FontTestUtils.isProductionUiFont(
            FontTestUtils.getFontFamily(newsCategory),
          ),
          isTrue,
        );
        expect(FontTestUtils.getFontWeight(newsCategory), FontWeight.w500);

        // Verify news timestamp style
        final newsTimestamp =
            FontTestUtils.requireTextWidgetByContent(tester, '5 minutes ago');
        expect(FontTestUtils.usesNewsTimestampStyle(newsTimestamp), isTrue);
        expect(
          FontTestUtils.isProductionUiFont(
            FontTestUtils.getFontFamily(newsTimestamp),
          ),
          isTrue,
        );
        expect(FontTestUtils.getFontWeight(newsTimestamp), FontWeight.w400);
      });
    });

    group('Font Extension Tests', () {
      testWidgets('should use crassula extension method',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('Extended Text',
                    style: const TextStyle(fontSize: 16).crassula),
                Text('Extended Bold',
                    style: const TextStyle(fontSize: 16)
                        .crassulaWithWeight(FontWeight.bold)),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify extension method works
        final extendedText =
            FontTestUtils.requireTextWidgetByContent(tester, 'Extended Text');
        expect(FontTestUtils.getFontFamily(extendedText), 'Crassula');

        // Verify extension method with weight works
        final extendedBold =
            FontTestUtils.requireTextWidgetByContent(tester, 'Extended Bold');
        expect(FontTestUtils.getFontFamily(extendedBold), 'Crassula');
        expect(FontTestUtils.getFontWeight(extendedBold), FontWeight.bold);
      });
    });

    group('Font Consistency Tests', () {
      testWidgets('should maintain font consistency across different widgets',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                // Different ways to apply the same font
                Text('Direct FontManager', style: FontManager.bodyText1),
                Text('Custom Font Method',
                    style: FontManager.customFont(
                        fontSize: 16, fontWeight: FontWeight.w400)),
                Text('Extension Method',
                    style: const TextStyle(fontSize: 16).crassula),
                Text('Apply Custom Font',
                    style: FontManager.applyCustomFont(
                        const TextStyle(fontSize: 16))),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // All should use the same font family
        final allTexts = FontTestUtils.findAllTextWidgets(tester);
        for (final text in allTexts) {
          expect(FontTestUtils.isProductionUiFont(FontTestUtils.getFontFamily(text)), isTrue);
        }
      });

      testWidgets('should handle font inheritance correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getLightTheme(testConfig),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final textTheme = Theme.of(context).textTheme;
                  return Column(
                    children: [
                      Text('Theme Text', style: textTheme.bodyLarge),
                      Text(
                        'Override Text',
                        style: FontManager.bold.copyWith(
                          color: Colors.red,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'Mixed Text',
                        style: textTheme.titleLarge?.copyWith(color: Colors.blue),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        for (final label in ['Theme Text', 'Override Text', 'Mixed Text']) {
          final text =
              FontTestUtils.requireTextWidgetByContent(tester, label);
          expect(
            FontTestUtils.isProductionUiFont(FontTestUtils.getFontFamily(text)),
            isTrue,
          );
        }

        final overrideText =
            FontTestUtils.requireTextWidgetByContent(tester, 'Override Text');
        expect(FontTestUtils.getFontWeight(overrideText), FontWeight.bold);
      });
    });

    group('Font Edge Case Tests', () {
      testWidgets('should handle empty text', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('', style: FontManager.bodyText1),
                Text('', style: FontManager.caption),
                Text('   ', style: FontManager.newsTitle),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Explicitly styled empty/whitespace texts use production UI font
        final styled = FontTestUtils.findAllTextWidgets(tester)
            .where((w) => w.style?.fontFamily != null);
        expect(styled, isNotEmpty);
        for (final text in styled) {
          expect(FontTestUtils.usesCustomFont(text), isTrue);
        }
      });

      testWidgets('should handle very long text', (WidgetTester tester) async {
        const longText =
            'This is a very long text that should be handled properly by the font system without any issues or crashes. ';

        await tester.pumpWidget(
          FontTestWidget(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(longText, style: FontManager.bodyText1),
                  Text(longText, style: FontManager.newsTitle),
                  Text(longText, style: FontManager.headline1),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should handle long text gracefully
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);
      });

      testWidgets('should handle special characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('Special chars: @#%^&*()_+-=[]{}|;:,.<>?',
                    style: FontManager.bodyText1),
                Text('Unicode: ñáéíóú 中文 русский العربية',
                    style: FontManager.newsTitle),
                Text('Emojis: 🚀📱💻⚡', style: FontManager.headline1),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should handle special characters gracefully
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);
      });
    });

    group('Font Performance Tests', () {
      testWidgets('should handle many text widgets efficiently',
          (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();

        await tester.pumpWidget(
          FontTestWidget(
            child: ListView.builder(
              itemCount: 1000,
              itemBuilder: (context, index) {
                return Text(
                  'Item $index',
                  style: FontManager.bodyText2,
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();
        stopwatch.stop();

        // Should render quickly (less than 1 second for 1000 items)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));

        // All text should use custom font
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);
      });
    });
  });
}
