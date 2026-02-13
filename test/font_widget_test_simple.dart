import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/services/font_manager.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/remote_config_model.dart';

/// Simple widget tests for font integration
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

    testWidgets('should render FontManager styles correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // News-specific styles
                Text('Breaking News Headline', style: FontManager.newsTitle),
                Text('Technology', style: FontManager.newsCategory),
                Text('2 hours ago', style: FontManager.newsTimestamp),
                Text('This is the news content...',
                    style: FontManager.newsContent),

                // Heading styles
                Text('Headline 1', style: FontManager.headline1),
                Text('Headline 2', style: FontManager.headline2),
                Text('Headline 3', style: FontManager.headline3),

                // Body styles
                Text('Body Text 1', style: FontManager.bodyText1),
                Text('Body Text 2', style: FontManager.bodyText2),
                Text('Caption Text', style: FontManager.caption),
                Text('Button Text', style: FontManager.button),

                // Custom font variations
                Text('Thin Text', style: FontManager.thin),
                Text('Light Text', style: FontManager.light),
                Text('Regular Text', style: FontManager.regular),
                Text('Medium Text', style: FontManager.medium),
                Text('Bold Text', style: FontManager.bold),
                Text('Black Text', style: FontManager.black),
              ],
            ),
          ),
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

      // Verify font family is applied
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style ?? const TextStyle();
        expect(style.fontFamily, 'Crassula');
      }
    });

    testWidgets('should apply correct font weights',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Thin Text', style: FontManager.thin),
                Text('Light Text', style: FontManager.light),
                Text('Regular Text', style: FontManager.regular),
                Text('Medium Text', style: FontManager.medium),
                Text('Bold Text', style: FontManager.bold),
                Text('Black Text', style: FontManager.black),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test specific font weights
      final thinText = tester.widget<Text>(find.text('Thin Text'));
      expect(thinText.style?.fontWeight, FontWeight.w100);

      final boldText = tester.widget<Text>(find.text('Bold Text'));
      expect(boldText.style?.fontWeight, FontWeight.w700);

      final blackText = tester.widget<Text>(find.text('Black Text'));
      expect(blackText.style?.fontWeight, FontWeight.w900);
    });

    testWidgets('should apply correct font sizes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Headline 1', style: FontManager.headline1),
                Text('Headline 2', style: FontManager.headline2),
                Text('Headline 3', style: FontManager.headline3),
                Text('Body Text 1', style: FontManager.bodyText1),
                Text('Body Text 2', style: FontManager.bodyText2),
                Text('Caption Text', style: FontManager.caption),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test specific font sizes
      final headline1 = tester.widget<Text>(find.text('Headline 1'));
      expect(headline1.style?.fontSize, 32);

      final headline2 = tester.widget<Text>(find.text('Headline 2'));
      expect(headline2.style?.fontSize, 28);

      final body1 = tester.widget<Text>(find.text('Body Text 1'));
      expect(body1.style?.fontSize, 16);

      final caption = tester.widget<Text>(find.text('Caption Text'));
      expect(caption.style?.fontSize, 12);
    });

    testWidgets('should apply custom fonts through theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getLightTheme(testConfig),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    Text('Display Large',
                        style: Theme.of(context).textTheme.displayLarge),
                    Text('Title Large',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('Body Large',
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text('Body Medium',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all theme-based text uses custom font
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style ?? const TextStyle();
        expect(style.fontFamily, 'Crassula');
      }

      // Verify specific text widgets
      final displayLarge = tester.widget<Text>(find.text('Display Large'));
      expect(displayLarge.style?.fontFamily, 'Crassula');
      expect(displayLarge.style?.fontWeight, FontWeight.bold);

      final titleLarge = tester.widget<Text>(find.text('Title Large'));
      expect(titleLarge.style?.fontFamily, 'Crassula');
      expect(titleLarge.style?.fontWeight, FontWeight.w600);

      final bodyLarge = tester.widget<Text>(find.text('Body Large'));
      expect(bodyLarge.style?.fontFamily, 'Crassula');
      expect(bodyLarge.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('should apply custom fonts in dark theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getDarkTheme(testConfig),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    Text('Display Large',
                        style: Theme.of(context).textTheme.displayLarge),
                    Text('Title Large',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('Body Large',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all dark theme text uses custom font
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style ?? const TextStyle();
        expect(style.fontFamily, 'Crassula');
      }

      // Verify font weights are correct in dark theme
      final displayLarge = tester.widget<Text>(find.text('Display Large'));
      expect(displayLarge.style?.fontWeight, FontWeight.bold);

      final bodyLarge = tester.widget<Text>(find.text('Body Large'));
      expect(bodyLarge.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('should apply news-specific font styles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Breaking News Today', style: FontManager.newsTitle),
                Text('Technology', style: FontManager.newsCategory),
                Text('5 minutes ago', style: FontManager.newsTimestamp),
                Text('Full article content goes here...',
                    style: FontManager.newsContent),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify news title style
      final newsTitle = tester.widget<Text>(find.text('Breaking News Today'));
      expect(newsTitle.style?.fontFamily, 'Crassula');
      expect(newsTitle.style?.fontWeight, FontWeight.bold);
      expect(newsTitle.style?.fontSize, 20);

      // Verify news category style
      final newsCategory = tester.widget<Text>(find.text('Technology'));
      expect(newsCategory.style?.fontFamily, 'Crassula');
      expect(newsCategory.style?.fontWeight, FontWeight.w500);
      expect(newsCategory.style?.fontSize, 12);

      // Verify news timestamp style
      final newsTimestamp = tester.widget<Text>(find.text('5 minutes ago'));
      expect(newsTimestamp.style?.fontFamily, 'Crassula');
      expect(newsTimestamp.style?.fontWeight, FontWeight.w400);
      expect(newsTimestamp.style?.fontSize, 11);
    });

    testWidgets('should use crassula extension method',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Extended Text',
                    style: const TextStyle(fontSize: 16).crassula),
                Text('Extended Bold',
                    style: const TextStyle(fontSize: 16)
                        .crassulaWithWeight(FontWeight.bold)),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify extension method works
      final extendedText = tester.widget<Text>(find.text('Extended Text'));
      expect(extendedText.style?.fontFamily, 'Crassula');

      // Verify extension method with weight works
      final extendedBold = tester.widget<Text>(find.text('Extended Bold'));
      expect(extendedBold.style?.fontFamily, 'Crassula');
      expect(extendedBold.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('should handle custom font with parameters',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Custom Font 1',
                    style: FontManager.customFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                      height: 1.4,
                      letterSpacing: 0.5,
                    )),
                Text('Custom Font 2',
                    style: FontManager.customFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: Colors.blue,
                    )),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify custom font with parameters
      final custom1 = tester.widget<Text>(find.text('Custom Font 1'));
      expect(custom1.style?.fontFamily, 'Crassula');
      expect(custom1.style?.fontSize, 18);
      expect(custom1.style?.fontWeight, FontWeight.w600);
      expect(custom1.style?.color, Colors.red);
      expect(custom1.style?.height, 1.4);
      expect(custom1.style?.letterSpacing, 0.5);

      final custom2 = tester.widget<Text>(find.text('Custom Font 2'));
      expect(custom2.style?.fontFamily, 'Crassula');
      expect(custom2.style?.fontSize, 14);
      expect(custom2.style?.fontWeight, FontWeight.w300);
      expect(custom2.style?.color, Colors.blue);
    });

    testWidgets('should handle empty text gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('', style: FontManager.bodyText1),
                const Text(''),
                Text('   ', style: FontManager.newsTitle),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should handle empty text gracefully
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style ?? const TextStyle();
        expect(style.fontFamily, 'Crassula');
      }
    });

    testWidgets('should handle special characters',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Special chars: @#\$%^&*()_+-=[]{}|;:,.<>?',
                    style: FontManager.bodyText1),
                Text('Unicode: ñáéíóú 中文 русский العربية',
                    style: FontManager.newsTitle),
                Text('Emojis: 🚀📱💻⚡', style: FontManager.headline1),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should handle special characters gracefully
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style ?? const TextStyle();
        expect(style.fontFamily, 'Crassula');
      }
    });

    testWidgets('should handle many text widgets efficiently',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) {
                return Text(
                  'Item $index',
                  style: FontManager.bodyText2,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All text should use custom font
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style ?? const TextStyle();
        expect(style.fontFamily, 'Crassula');
      }

      // Should have 100 text widgets
      expect(textWidgets.length, 100);
    });
  });
}
