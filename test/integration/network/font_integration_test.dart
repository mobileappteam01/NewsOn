@Tags(['integration', 'network'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_setup.dart';
import 'package:newson/core/services/font_manager.dart';
import 'package:newson/core/theme/app_theme.dart';
import 'package:newson/data/models/remote_config_model.dart';

import '../../font_test_utils.dart';

/// Integration tests for custom font system
/// Tests all font scenarios and edge cases across the application
void main() {
  ensureTestBinding();

  group('Font Integration Tests', () {
    late RemoteConfigModel testConfig;

    setUp(() {
      testConfig = RemoteConfigModel(
        // Test configuration with default values
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

    group('FontManager Tests', () {
      test('should have correct font family name', () {
        final textStyle = FontManager.regular;
        expect(FontTestUtils.isProductionUiFont(textStyle.fontFamily), isTrue);
      });

      test('should provide different font weights', () {
        expect(FontManager.thin.fontWeight, FontWeight.w100);
        expect(FontManager.light.fontWeight, FontWeight.w300);
        expect(FontManager.regular.fontWeight, FontWeight.w400);
        expect(FontManager.medium.fontWeight, FontWeight.w500);
        expect(FontManager.bold.fontWeight, FontWeight.w700);
        expect(FontManager.black.fontWeight, FontWeight.w900);
      });

      test('should provide headline styles with correct properties', () {
        final headline1 = FontManager.headline1;
        expect(headline1.fontSize, 32);
        expect(headline1.fontWeight, FontWeight.bold);
        expect(FontTestUtils.isProductionUiFont(headline1.fontFamily), isTrue);

        final headline2 = FontManager.headline2;
        expect(headline2.fontSize, 28);
        expect(headline2.fontWeight, FontWeight.bold);
        expect(FontTestUtils.isProductionUiFont(headline2.fontFamily), isTrue);

        final headline3 = FontManager.headline3;
        expect(headline3.fontSize, 24);
        expect(headline3.fontWeight, FontWeight.bold);
        expect(FontTestUtils.isProductionUiFont(headline3.fontFamily), isTrue);
      });

      test('should provide body text styles with correct properties', () {
        final body1 = FontManager.bodyText1;
        expect(body1.fontSize, 16);
        expect(body1.fontWeight, FontWeight.w400);
        expect(FontTestUtils.isProductionUiFont(body1.fontFamily), isTrue);

        final body2 = FontManager.bodyText2;
        expect(body2.fontSize, 14);
        expect(body2.fontWeight, FontWeight.w400);
        expect(FontTestUtils.isProductionUiFont(body2.fontFamily), isTrue);
      });

      test('should provide news-specific styles', () {
        final newsTitle = FontManager.newsTitle;
        expect(newsTitle.fontSize, 20);
        expect(newsTitle.fontWeight, FontWeight.bold);
        expect(FontTestUtils.isProductionUiFont(newsTitle.fontFamily), isTrue);

        final newsCategory = FontManager.newsCategory;
        expect(newsCategory.fontSize, 12);
        expect(newsCategory.fontWeight, FontWeight.w500);
        expect(FontTestUtils.isProductionUiFont(newsCategory.fontFamily), isTrue);

        final newsTimestamp = FontManager.newsTimestamp;
        expect(newsTimestamp.fontSize, 11);
        expect(newsTimestamp.fontWeight, FontWeight.w400);
        expect(FontTestUtils.isProductionUiFont(newsTimestamp.fontFamily), isTrue);
      });

      test('should create custom font with parameters', () {
        final customFont = FontManager.customFont(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.red,
          height: 1.4,
          letterSpacing: 0.5,
        );

        expect(customFont.fontSize, 18);
        expect(customFont.fontWeight, FontWeight.w600);
        expect(customFont.color, Colors.red);
        expect(customFont.height, 1.4);
        expect(customFont.letterSpacing, 0.5);
        expect(FontTestUtils.isProductionUiFont(customFont.fontFamily), isTrue);
      });

      test('should apply custom font to existing TextStyle', () {
        final originalStyle = TextStyle(
          fontSize: 16,
          color: Colors.blue,
          decoration: TextDecoration.underline,
        );

        final customStyle = FontManager.applyCustomFont(originalStyle);

        expect(customStyle.fontFamily, 'Crassula');
        expect(customStyle.fontSize, 16);
        expect(customStyle.color, Colors.blue);
        expect(customStyle.decoration, TextDecoration.underline);
      });

      test('should apply custom font with specific weight', () {
        final originalStyle = TextStyle(fontSize: 14);
        final customStyle = FontManager.applyCustomFont(
          originalStyle,
          weight: FontWeight.w600,
        );

        expect(customStyle.fontFamily, 'Crassula');
        expect(customStyle.fontWeight, FontWeight.w600);
      });

      test('should check font loading status', () {
        expect(FontManager.isFontLoaded(), isTrue);
      });
    });

    group('FontManager Extensions Tests', () {
      test('should apply Crassula font to TextStyle', () {
        final originalStyle = TextStyle(fontSize: 16);
        final crassulaStyle = originalStyle.crassula;

        expect(crassulaStyle.fontFamily, 'Crassula');
        expect(crassulaStyle.fontSize, 16);
      });

      test('should apply Crassula font with specific weight', () {
        final originalStyle = TextStyle(fontSize: 14);
        final crassulaStyle = originalStyle.crassulaWithWeight(FontWeight.w700);

        expect(crassulaStyle.fontFamily, 'Crassula');
        expect(crassulaStyle.fontWeight, FontWeight.w700);
      });
    });

    group('AppTheme Font Integration Tests', () {
      test('should use custom fonts in light theme', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);

        // Check displayLarge uses custom font
        expect(FontTestUtils.isProductionUiFont(lightTheme.textTheme.displayLarge?.fontFamily), isTrue);
        expect(lightTheme.textTheme.displayLarge?.fontWeight, FontWeight.bold);

        // Check titleLarge uses custom font
        expect(FontTestUtils.isProductionUiFont(lightTheme.textTheme.titleLarge?.fontFamily), isTrue);
        expect(lightTheme.textTheme.titleLarge?.fontWeight, FontWeight.w500);

        // Check bodyLarge uses custom font
        expect(FontTestUtils.isProductionUiFont(lightTheme.textTheme.bodyLarge?.fontFamily), isTrue);
        expect(lightTheme.textTheme.bodyLarge?.fontWeight, FontWeight.w400);

        // Check bodyMedium uses custom font
        expect(FontTestUtils.isProductionUiFont(lightTheme.textTheme.bodyMedium?.fontFamily), isTrue);
        expect(lightTheme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
      });

      test('should use custom fonts in dark theme', () {
        final darkTheme = AppTheme.getDarkTheme(testConfig);

        // Check displayLarge uses custom font
        expect(FontTestUtils.isProductionUiFont(darkTheme.textTheme.displayLarge?.fontFamily), isTrue);
        expect(darkTheme.textTheme.displayLarge?.fontWeight, FontWeight.bold);

        // Check titleLarge uses custom font
        expect(FontTestUtils.isProductionUiFont(darkTheme.textTheme.titleLarge?.fontFamily), isTrue);
        expect(darkTheme.textTheme.titleLarge?.fontWeight, FontWeight.w500);

        // Check bodyLarge uses custom font
        expect(FontTestUtils.isProductionUiFont(darkTheme.textTheme.bodyLarge?.fontFamily), isTrue);
        expect(darkTheme.textTheme.bodyLarge?.fontWeight, FontWeight.w400);

        // Check bodyMedium uses custom font
        expect(FontTestUtils.isProductionUiFont(darkTheme.textTheme.bodyMedium?.fontFamily), isTrue);
        expect(darkTheme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
      });

      test('should apply correct font sizes from config', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);

        expect(lightTheme.textTheme.displayLarge?.fontSize, testConfig.displayLargeFontSize);
        expect(lightTheme.textTheme.displayMedium?.fontSize, testConfig.displayMediumFontSize);
        expect(lightTheme.textTheme.displaySmall?.fontSize, testConfig.displaySmallFontSize);
        expect(lightTheme.textTheme.headlineMedium?.fontSize, testConfig.headlineMediumFontSize);
        expect(lightTheme.textTheme.titleLarge?.fontSize, testConfig.titleLargeFontSize);
        expect(lightTheme.textTheme.titleMedium?.fontSize, testConfig.titleMediumFontSize);
        expect(lightTheme.textTheme.bodyLarge?.fontSize, testConfig.bodyLargeFontSize);
        expect(lightTheme.textTheme.bodyMedium?.fontSize, testConfig.bodyMediumFontSize);
        expect(lightTheme.textTheme.bodySmall?.fontSize, testConfig.bodySmallFontSize);
      });

      test('should apply correct colors from config', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);

        expect(lightTheme.textTheme.displayLarge?.color, testConfig.textPrimaryColorValue);
        expect(lightTheme.textTheme.titleLarge?.color, testConfig.textPrimaryColorValue);
        expect(lightTheme.textTheme.bodyLarge?.color, testConfig.textPrimaryColorValue);
        expect(lightTheme.textTheme.bodyMedium?.color, testConfig.textSecondaryColorValue);
        expect(lightTheme.textTheme.bodySmall?.color, testConfig.textSecondaryColorValue);
      });
    });

    group('Font Consistency Tests', () {
      test('should maintain consistent font family across all text styles', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);
        final darkTheme = AppTheme.getDarkTheme(testConfig);

        // Check all text styles use the same font family
        final lightTextStyles = [
          lightTheme.textTheme.displayLarge,
          lightTheme.textTheme.displayMedium,
          lightTheme.textTheme.displaySmall,
          lightTheme.textTheme.headlineMedium,
          lightTheme.textTheme.titleLarge,
          lightTheme.textTheme.titleMedium,
          lightTheme.textTheme.bodyLarge,
          lightTheme.textTheme.bodyMedium,
          lightTheme.textTheme.bodySmall,
        ];

        final darkTextStyles = [
          darkTheme.textTheme.displayLarge,
          darkTheme.textTheme.displayMedium,
          darkTheme.textTheme.displaySmall,
          darkTheme.textTheme.headlineMedium,
          darkTheme.textTheme.titleLarge,
          darkTheme.textTheme.titleMedium,
          darkTheme.textTheme.bodyLarge,
          darkTheme.textTheme.bodyMedium,
          darkTheme.textTheme.bodySmall,
        ];

        for (final style in lightTextStyles) {
          expect(FontTestUtils.isProductionUiFont(style?.fontFamily), isTrue);
        }

        for (final style in darkTextStyles) {
          expect(FontTestUtils.isProductionUiFont(style?.fontFamily), isTrue);
        }
      });

      test('should maintain consistent font weight hierarchy', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);

        // Display styles should be bold
        expect(lightTheme.textTheme.displayLarge?.fontWeight, FontWeight.bold);
        expect(lightTheme.textTheme.displayMedium?.fontWeight, FontWeight.bold);
        expect(lightTheme.textTheme.displaySmall?.fontWeight, FontWeight.bold);

        // Title styles should be semi-bold to medium
        expect(lightTheme.textTheme.headlineMedium?.fontWeight, FontWeight.w500);
        expect(lightTheme.textTheme.titleLarge?.fontWeight, FontWeight.w500);
        expect(lightTheme.textTheme.titleMedium?.fontWeight, FontWeight.w500);

        // Body styles should be regular
        expect(lightTheme.textTheme.bodyLarge?.fontWeight, FontWeight.w400);
        expect(lightTheme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
        expect(lightTheme.textTheme.bodySmall?.fontWeight, FontWeight.w400);
      });
    });

    group('Font Edge Cases Tests', () {
      test('should handle null parameters gracefully', () {
        final customFont = FontManager.customFont(
          fontSize: null,
          fontWeight: null,
          color: null,
          height: null,
          letterSpacing: null,
        );

        expect(FontTestUtils.isProductionUiFont(customFont.fontFamily), isTrue);
        expect(customFont.fontSize, null);
        expect(customFont.fontWeight, FontWeight.w400); // Default weight
        expect(customFont.color, null);
        expect(customFont.height, null);
        expect(customFont.letterSpacing, null);
      });

      test('should handle empty TextStyle for applyCustomFont', () {
        final emptyStyle = TextStyle();
        final customStyle = FontManager.applyCustomFont(emptyStyle);

        expect(customStyle.fontFamily, 'Crassula');
        expect(customStyle.fontWeight, FontWeight.w400);
      });

      test('should preserve TextStyle properties when applying custom font', () {
        final originalStyle = TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w300,
          color: Colors.green,
          backgroundColor: Colors.yellow,
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.red,
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2.0,
          fontFamily: 'Arial', // This should be overridden
        );

        final customStyle = FontManager.applyCustomFont(originalStyle);

        expect(customStyle.fontFamily, 'Crassula'); // Overridden
        expect(customStyle.fontSize, 20); // Preserved
        expect(customStyle.fontWeight, FontWeight.w300); // Preserved
        expect(customStyle.color, Colors.green); // Preserved
        expect(customStyle.backgroundColor, Colors.yellow); // Preserved
        expect(customStyle.decoration, TextDecoration.lineThrough); // Preserved
        expect(customStyle.decorationColor, Colors.red); // Preserved
        expect(customStyle.decorationStyle, TextDecorationStyle.dashed); // Preserved
        expect(customStyle.decorationThickness, 2.0); // Preserved
      });
    });

    group('Font Style Creation Tests', () {
      test('should create many font styles without error', () {
        TextStyle? last;
        for (int i = 0; i < 100; i++) {
          last = FontManager.customFont(
            fontSize: 16.0 + (i % 10),
            fontWeight: FontWeight.values[i % FontWeight.values.length],
            color: Color(0xFF000000 + i),
          );
        }
        expect(FontTestUtils.isProductionUiFont(last?.fontFamily), isTrue);
      });

      test('should apply custom Crassula font to TextStyle repeatedly', () {
        final originalStyle = TextStyle(fontSize: 16);
        TextStyle? last;
        for (int i = 0; i < 100; i++) {
          last = FontManager.applyCustomFont(originalStyle);
        }
        expect(last?.fontFamily, 'Crassula');
        expect(last?.fontSize, 16);
      });
    });

    group('Font Accessibility Tests', () {
      test('should provide sufficient font size contrast', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);

        // Check minimum font sizes for readability
        expect(lightTheme.textTheme.bodyLarge?.fontSize, greaterThanOrEqualTo(14));
        expect(lightTheme.textTheme.bodyMedium?.fontSize, greaterThanOrEqualTo(12));
        expect(lightTheme.textTheme.bodySmall?.fontSize, greaterThanOrEqualTo(10));

        // Check heading font sizes are significantly larger
        expect(lightTheme.textTheme.headlineMedium?.fontSize, greaterThan(lightTheme.textTheme.bodyLarge?.fontSize ?? 0));
        expect(lightTheme.textTheme.titleLarge?.fontSize, greaterThan(lightTheme.textTheme.bodyLarge?.fontSize ?? 0));
      });

      test('should maintain readable font weights', () {
        final lightTheme = AppTheme.getLightTheme(testConfig);

        // Check font weights are readable (not too light)
        expect(lightTheme.textTheme.bodyLarge?.fontWeight?.value, greaterThanOrEqualTo(400));
        expect(lightTheme.textTheme.bodyMedium?.fontWeight?.value, greaterThanOrEqualTo(400));
        expect(lightTheme.textTheme.bodySmall?.fontWeight?.value, greaterThanOrEqualTo(400));
      });
    });
  });

  group('Widget Integration Tests', () {
    late RemoteConfigModel widgetConfig;

    setUp(() {
      widgetConfig = RemoteConfigModel(
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

    testWidgets('should render Text widgets with custom fonts', (WidgetTester tester) async {
      final theme = AppTheme.getLightTheme(widgetConfig);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                return Column(
                  children: [
                    Text('Headline', style: textTheme.displayLarge),
                    Text('Title', style: textTheme.titleLarge),
                    Text('Body', style: textTheme.bodyLarge),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify text widgets are rendered
      expect(find.text('Headline'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('should apply custom fonts to news-specific text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('News Title', style: FontManager.newsTitle),
                Text('News Category', style: FontManager.newsCategory),
                Text('News Timestamp', style: FontManager.newsTimestamp),
                Text('News Content', style: FontManager.newsContent),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all news text widgets are rendered
      expect(find.text('News Title'), findsOneWidget);
      expect(find.text('News Category'), findsOneWidget);
      expect(find.text('News Timestamp'), findsOneWidget);
      expect(find.text('News Content'), findsOneWidget);
    });
  });
}
