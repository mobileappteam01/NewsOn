import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/search/domain/search_query_validator.dart';

void main() {
  group('SearchQueryValidator', () {
    test('rejects too short', () {
      expect(SearchQueryValidator.validate('a'), 'too_short');
      expect(SearchQueryValidator.validate(' '), 'too_short');
    });

    test('rejects too long', () {
      final long = 'x' * 101;
      expect(SearchQueryValidator.validate(long), 'too_long');
    });

    test('accepts valid and normalizes whitespace', () {
      expect(SearchQueryValidator.validate('  hi  there '), isNull);
      expect(
        SearchQueryValidator.normalize('  hi   there  '),
        'hi there',
      );
    });

    test('clamps limit', () {
      expect(SearchQueryValidator.clampLimit(0), 20);
      expect(SearchQueryValidator.clampLimit(100), 50);
      expect(SearchQueryValidator.clampLimit(10), 10);
    });
  });
}
