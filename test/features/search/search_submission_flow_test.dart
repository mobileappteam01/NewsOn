import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/search/data/recent_searches_store.dart';
import 'package:newson/features/search/domain/search_query_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors NewsSearchController submit/recent/suggestion rules without Firebase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('submission path: validate → normalize → store recent', () async {
    final store = RecentSearchesStore();
    expect(SearchQueryValidator.validate('x'), 'too_short');

    final q = SearchQueryValidator.normalize('  Climate  Crisis ');
    expect(SearchQueryValidator.validate(q), isNull);
    final recent = await store.add(q);
    expect(recent.first, 'Climate Crisis');
  });

  test('local suggestions filter recent (no network)', () async {
    final store = RecentSearchesStore();
    await store.add('climate');
    await store.add('politics');
    final recent = await store.load();
    final q = 'cli'.toLowerCase();
    final suggestions =
        recent.where((e) => e.toLowerCase().contains(q)).take(8).toList();
    expect(suggestions, ['climate']);
  });
}
