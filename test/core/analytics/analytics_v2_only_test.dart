import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V2 analytics no V1 fallback', () {
    test('AnalyticsService.log supports v2Only skip (no V1 host)', () {
      final src =
          File('lib/core/analytics/analytics_service.dart').readAsStringSync();
      expect(src.contains('bool v2Only = false'), isTrue);
      expect(src.contains('V2 host unavailable (v2Only)'), isTrue);
      expect(src.contains('final useV2Host = v2Only || canUseV2'), isTrue);
      // When v2Only and V2 unavailable, must return — never prefer V1.
      final v2OnlyBlockStart = src.indexOf('if (v2Only)');
      expect(v2OnlyBlockStart, greaterThan(0));
      final block = src.substring(
        v2OnlyBlockStart,
        v2OnlyBlockStart + 280,
      );
      expect(block.contains('return;'), isTrue);
      expect(block.contains('useV2Host: false'), isFalse);
    });

    test('V2 surfaces pass v2Only: true on analytics events', () {
      const surfaces = [
        'lib/features/for_you/presentation/v2_for_you_tab.dart',
        'lib/features/search/presentation/v2_search_tab.dart',
        'lib/features/home/presentation/v2_home_screen.dart',
        'lib/features/publishers/presentation/publisher_page.dart',
        'lib/features/home_v2/presentation/v2_reader_home.dart',
        'lib/features/news_detail/presentation/v2_article_detail_screen.dart',
      ];
      for (final path in surfaces) {
        final src = File(path).readAsStringSync();
        expect(
          src.contains('AnalyticsService'),
          isTrue,
          reason: path,
        );
        // Every AnalyticsService event helper call from V2 should opt in.
        expect(src.contains('v2Only: true'), isTrue, reason: path);
      }
    });

    test('V1 news detail screen does not force v2Only analytics', () {
      final src = File(
        'lib/screens/news_detail/news_detail_screen.dart',
      ).readAsStringSync();
      // V1 detail may or may not call analytics — must not require v2Only.
      expect(src.contains('v2Only: true'), isFalse);
    });
  });
}
