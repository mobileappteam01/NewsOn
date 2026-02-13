import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/services/font_manager.dart';

/// Utility functions for font testing
class FontTestUtils {
  /// Find all Text widgets in the widget tree
  static List<Text> findAllTextWidgets(WidgetTester tester) {
    final textWidgets = <Text>[];
    tester.binding.renderViewElement!.visitChildren((element) {
      _collectTextWidgets(element, textWidgets);
    });
    return textWidgets;
  }

  /// Recursively collect Text widgets
  static void _collectTextWidgets(Element element, List<Text> textWidgets) {
    if (element.widget is Text) {
      textWidgets.add(element.widget as Text);
    }
    element.visitChildren((child) {
      _collectTextWidgets(child, textWidgets);
    });
  }

  /// Verify that a Text widget uses the custom font
  static bool usesCustomFont(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula';
  }

  /// Verify that a Text widget uses the expected font weight
  static bool usesFontWeight(Text textWidget, FontWeight expectedWeight) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontWeight == expectedWeight;
  }

  /// Verify that a Text widget uses the expected font size
  static bool usesFontSize(Text textWidget, double expectedSize) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontSize == expectedSize;
  }

  /// Find Text widgets with specific text content
  static List<Text> findTextWidgetsByContent(WidgetTester tester, String content) {
    final allTextWidgets = findAllTextWidgets(tester);
    return allTextWidgets.where((widget) {
      final textSpan = widget.textSpan;
      if (textSpan != null) {
        return textSpan.toPlainText().contains(content);
      }
      return widget.data?.contains(content) ?? false;
    }).toList();
  }

  /// Find Text widgets using custom font
  static List<Text> findTextsWithCustomFont(WidgetTester tester) {
    final allTextWidgets = findAllTextWidgets(tester);
    return allTextWidgets.where(usesCustomFont).toList();
  }

  /// Find Text widgets not using custom font
  static List<Text> findTextsWithoutCustomFont(WidgetTester tester) {
    final allTextWidgets = findAllTextWidgets(tester);
    return allTextWidgets.where((widget) => !usesCustomFont(widget)).toList();
  }

  /// Print font usage statistics for debugging
  static void printFontUsageStats(WidgetTester tester) {
    final allTextWidgets = findAllTextWidgets(tester);
    final customFontWidgets = findTextsWithCustomFont(tester);
    final nonCustomFontWidgets = findTextsWithoutCustomFont(tester);

    print('=== Font Usage Statistics ===');
    print('Total Text widgets: ${allTextWidgets.length}');
    print('Using custom font: ${customFontWidgets.length}');
    print('Not using custom font: ${nonCustomFontWidgets.length}');
    print('Custom font usage: ${(customFontWidgets.length / allTextWidgets.length * 100).toStringAsFixed(1)}%');

    if (nonCustomFontWidgets.isNotEmpty) {
      print('\nText widgets not using custom font:');
      for (final widget in nonCustomFontWidgets) {
        final text = widget.data ?? widget.textSpan?.toPlainText() ?? 'Unknown';
        final fontFamily = widget.style?.fontFamily ?? 'Default';
        print('- "$text" (Font: $fontFamily)');
      }
    }
  }

  /// Verify all Text widgets use custom font
  static bool allTextsUseCustomFont(WidgetTester tester) {
    final nonCustomFontWidgets = findTextsWithoutCustomFont(tester);
    return nonCustomFontWidgets.isEmpty;
  }

  /// Get font family from Text widget
  static String getFontFamily(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily ?? 'Default';
  }

  /// Get font weight from Text widget
  static FontWeight getFontWeight(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontWeight ?? FontWeight.w400;
  }

  /// Get font size from Text widget
  static double? getFontSize(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontSize;
  }

  /// Verify news-specific font styles
  static bool usesNewsTitleStyle(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula' &&
           style.fontWeight == FontWeight.bold &&
           (style.fontSize == 20 || style.fontSize == null); // null uses default
  }

  static bool usesNewsCategoryStyle(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula' &&
           style.fontWeight == FontWeight.w500 &&
           (style.fontSize == 12 || style.fontSize == null);
  }

  static bool usesNewsTimestampStyle(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula' &&
           style.fontWeight == FontWeight.w400 &&
           (style.fontSize == 11 || style.fontSize == null);
  }

  /// Verify heading styles
  static bool usesHeadlineStyle(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula' &&
           style.fontWeight == FontWeight.bold &&
           (style.fontSize != null && style.fontSize! >= 24);
  }

  static bool usesTitleStyle(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula' &&
           (style.fontWeight == FontWeight.w600 || style.fontWeight == FontWeight.w500) &&
           (style.fontSize != null && style.fontSize! >= 16 && style.fontSize! <= 20);
  }

  static bool usesBodyStyle(Text textWidget) {
    final style = textWidget.style ?? const TextStyle();
    return style.fontFamily == 'Crassula' &&
           style.fontWeight == FontWeight.w400 &&
           (style.fontSize != null && style.fontSize! >= 12 && style.fontSize! <= 16);
  }
}

/// Custom font matchers for test assertions
class FontMatchers {
  /// Matcher for custom font family
  static Matcher usesCustomFont() => predicate(
    (Text widget) => FontTestUtils.usesCustomFont(widget),
    'uses custom Crassula font',
  );

  /// Matcher for specific font weight
  static Matcher usesFontWeight(FontWeight weight) => predicate(
    (Text widget) => FontTestUtils.usesFontWeight(widget, weight),
    'uses font weight $weight',
  );

  /// Matcher for specific font size
  static Matcher usesFontSize(double size) => predicate(
    (Text widget) => FontTestUtils.usesFontSize(widget, size),
    'uses font size $size',
  );

  /// Matcher for news title style
  static Matcher usesNewsTitleStyle() => predicate(
    (Text widget) => FontTestUtils.usesNewsTitleStyle(widget),
    'uses news title style',
  );

  /// Matcher for news category style
  static Matcher usesNewsCategoryStyle() => predicate(
    (Text widget) => FontTestUtils.usesNewsCategoryStyle(widget),
    'uses news category style',
  );

  /// Matcher for news timestamp style
  static Matcher usesNewsTimestampStyle() => predicate(
    (Text widget) => FontTestUtils.usesNewsTimestampStyle(widget),
    'uses news timestamp style',
  );

  /// Matcher for headline style
  static Matcher usesHeadlineStyle() => predicate(
    (Text widget) => FontTestUtils.usesHeadlineStyle(widget),
    'uses headline style',
  );

  /// Matcher for title style
  static Matcher usesTitleStyle() => predicate(
    (Text widget) => FontTestUtils.usesTitleStyle(widget),
    'uses title style',
  );

  /// Matcher for body style
  static Matcher usesBodyStyle() => predicate(
    (Text widget) => FontTestUtils.usesBodyStyle(widget),
    'uses body style',
  );
}

/// Font test helper widget for testing
class FontTestWidget extends StatelessWidget {
  final Widget child;
  
  const FontTestWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }
}

/// Sample text widgets for testing
class SampleTextWidgets extends StatelessWidget {
  const SampleTextWidgets({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // News-specific styles
        Text('Breaking News Headline', style: FontManager.newsTitle),
        Text('Technology', style: FontManager.newsCategory),
        Text('2 hours ago', style: FontManager.newsTimestamp),
        Text('This is the news content...', style: FontManager.newsContent),
        
        // Heading styles
        Text('Headline 1', style: FontManager.headline1),
        Text('Headline 2', style: FontManager.headline2),
        Text('Headline 3', style: FontManager.headline3),
        Text('Headline 4', style: FontManager.headline4),
        Text('Headline 5', style: FontManager.headline5),
        Text('Headline 6', style: FontManager.headline6),
        
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
    );
  }
}
