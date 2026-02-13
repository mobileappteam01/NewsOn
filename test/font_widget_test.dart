import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/services/font_manager.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/test/font_test_utils.dart';

/// Widget tests for font integration in actual UI components
void main() {
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
      testWidgets('should render all FontManager styles correctly', (WidgetTester tester) async {
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

      testWidgets('should apply correct font weights', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: const SampleTextWidgets(),
          ),
        );

        await tester.pumpAndSettle();

        // Test specific font weights
        final thinText = FontTestUtils.findTextWidgetsByContent(tester, 'Thin Text').first;
        expect(FontTestUtils.getFontWeight(thinText), FontWeight.w100);

        final boldText = FontTestUtils.findTextWidgetsByContent(tester, 'Bold Text').first;
        expect(FontTestUtils.getFontWeight(boldText), FontWeight.w700);

        final blackText = FontTestUtils.findTextWidgetsByContent(tester, 'Black Text').first;
        expect(FontTestUtils.getFontWeight(blackText), FontWeight.w900);
      });

      testWidgets('should apply correct font sizes', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: const SampleTextWidgets(),
          ),
        );

        await tester.pumpAndSettle();

        // Test specific font sizes
        final headline1 = FontTestUtils.findTextWidgetsByContent(tester, 'Headline 1').first;
        expect(FontTestUtils.getFontSize(headline1), 32);

        final headline2 = FontTestUtils.findTextWidgetsByContent(tester, 'Headline 2').first;
        expect(FontTestUtils.getFontSize(headline2), 28);

        final body1 = FontTestUtils.findTextWidgetsByContent(tester, 'Body Text 1').first;
        expect(FontTestUtils.getFontSize(body1), 16);

        final caption = FontTestUtils.findTextWidgetsByContent(tester, 'Caption Text').first;
        expect(FontTestUtils.getFontSize(caption), 12);
      });
    });

    group('Theme Font Integration Tests', () {
      testWidgets('should apply custom fonts through theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getLightTheme(testConfig),
            home: Scaffold(
              body: Column(
                children: [
                  Text('Display Large', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.displayLarge),
                  Text('Title Large', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.titleLarge),
                  Text('Body Large', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.bodyLarge),
                  Text('Body Medium', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify all theme-based text uses custom font
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);

        // Verify specific text widgets
        final displayLarge = FontTestUtils.findTextWidgetsByContent(tester, 'Display Large').first;
        expect(FontTestUtils.getFontFamily(displayLarge), 'Crassula');
        expect(FontTestUtils.getFontWeight(displayLarge), FontWeight.bold);

        final titleLarge = FontTestUtils.findTextWidgetsByContent(tester, 'Title Large').first;
        expect(FontTestUtils.getFontFamily(titleLarge), 'Crassula');
        expect(FontTestUtils.getFontWeight(titleLarge), FontWeight.w600);

        final bodyLarge = FontTestUtils.findTextWidgetsByContent(tester, 'Body Large').first;
        expect(FontTestUtils.getFontFamily(bodyLarge), 'Crassula');
        expect(FontTestUtils.getFontWeight(bodyLarge), FontWeight.w400);
      });

      testWidgets('should apply custom fonts in dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getDarkTheme(testConfig),
            home: Scaffold(
              body: Column(
                children: [
                  Text('Display Large', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.displayLarge),
                  Text('Title Large', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.titleLarge),
                  Text('Body Large', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify all dark theme text uses custom font
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);

        // Verify font weights are correct in dark theme
        final displayLarge = FontTestUtils.findTextWidgetsByContent(tester, 'Display Large').first;
        expect(FontTestUtils.getFontWeight(displayLarge), FontWeight.bold);

        final bodyLarge = FontTestUtils.findTextWidgetsByContent(tester, 'Body Large').first;
        expect(FontTestUtils.getFontWeight(bodyLarge), FontWeight.w400);
      });
    });

    group('News-Specific Font Tests', () {
      testWidgets('should apply news-specific font styles', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('Breaking News Today', style: FontManager.newsTitle),
                Text('Technology', style: FontManager.newsCategory),
                Text('5 minutes ago', style: FontManager.newsTimestamp),
                Text('Full article content goes here...', style: FontManager.newsContent),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify news title style
        final newsTitle = FontTestUtils.findTextWidgetsByContent(tester, 'Breaking News Today').first;
        expect(FontTestUtils.usesNewsTitleStyle(newsTitle), isTrue);
        expect(FontTestUtils.getFontFamily(newsTitle), 'Crassula');
        expect(FontTestUtils.getFontWeight(newsTitle), FontWeight.bold);

        // Verify news category style
        final newsCategory = FontTestUtils.findTextWidgetsByContent(tester, 'Technology').first;
        expect(FontTestUtils.usesNewsCategoryStyle(newsCategory), isTrue);
        expect(FontTestUtils.getFontFamily(newsCategory), 'Crassula');
        expect(FontTestUtils.getFontWeight(newsCategory), FontWeight.w500);

        // Verify news timestamp style
        final newsTimestamp = FontTestUtils.findTextWidgetsByContent(tester, '5 minutes ago').first;
        expect(FontTestUtils.usesNewsTimestampStyle(newsTimestamp), isTrue);
        expect(FontTestUtils.getFontFamily(newsTimestamp), 'Crassula');
        expect(FontTestUtils.getFontWeight(newsTimestamp), FontWeight.w400);
      });
    });

    group('Font Extension Tests', () {
      testWidgets('should use crassula extension method', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('Extended Text', style: const TextStyle(fontSize: 16).crassula),
                Text('Extended Bold', style: const TextStyle(fontSize: 16).crassulaWithWeight(FontWeight.bold)),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify extension method works
        final extendedText = FontTestUtils.findTextWidgetsByContent(tester, 'Extended Text').first;
        expect(FontTestUtils.getFontFamily(extendedText), 'Crassula');

        // Verify extension method with weight works
        final extendedBold = FontTestUtils.findTextWidgetsByContent(tester, 'Extended Bold').first;
        expect(FontTestUtils.getFontFamily(extendedBold), 'Crassula');
        expect(FontTestUtils.getFontWeight(extendedBold), FontWeight.bold);
      });
    });

    group('Font Consistency Tests', () {
      testWidgets('should maintain font consistency across different widgets', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                // Different ways to apply the same font
                Text('Direct FontManager', style: FontManager.bodyText1),
                Text('Custom Font Method', style: FontManager.customFont(fontSize: 16, fontWeight: FontWeight.w400)),
                Text('Extension Method', style: const TextStyle(fontSize: 16).crassula),
                Text('Apply Custom Font', style: FontManager.applyCustomFont(const TextStyle(fontSize: 16))),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // All should use the same font family
        final allTexts = FontTestUtils.findAllTextWidgets(tester);
        for (final text in allTexts) {
          expect(FontTestUtils.getFontFamily(text), 'Crassula');
        }
      });

      testWidgets('should handle font inheritance correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getLightTheme(testConfig),
            home: Scaffold(
              body: Column(
                children: [
                  // Theme-based text
                  Text('Theme Text', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.bodyLarge),
                  // Override theme with custom font
                  Text('Override Text', style: FontManager.bold.copyWith(
                    color: Colors.red,
                    fontSize: 20,
                  )),
                  // Mix theme and custom
                  Text('Mixed Text', style: Theme.of(tester.element(find.byType(Scaffold))).textTheme.titleLarge?.copyWith(
                    color: Colors.blue,
                  )),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // All should still use custom font
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);

        // Verify overrides work correctly
        final overrideText = FontTestUtils.findTextWidgetsByContent(tester, 'Override Text').first;
        expect(FontTestUtils.getFontFamily(overrideText), 'Crassula');
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
                const Text(''),
                Text('   ', style: FontManager.newsTitle),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should handle empty text gracefully
        expect(FontTestUtils.allTextsUseCustomFont(tester), isTrue);
      });

      testWidgets('should handle very long text', (WidgetTester tester) async {
        final longText = 'This is a very long text that should be handled properly by the font system without any issues or crashes. '.repeat(10);
        
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

      testWidgets('should handle special characters', (WidgetTester tester) async {
        await tester.pumpWidget(
          FontTestWidget(
            child: Column(
              children: [
                Text('Special chars: @#$%^&*()_+-=[]{}|;:,.<>?', style: FontManager.bodyText1),
                Text('Unicode: ñáéíóú 中文 русский العربية', style: FontManager.newsTitle),
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
      testWidgets('should handle many text widgets efficiently', (WidgetTester tester) async {
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
