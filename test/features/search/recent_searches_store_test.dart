import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/search/data/recent_searches_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('adds newest first, dedupes case-insensitively, bounds count', () async {
    final store = RecentSearchesStore(maxItems: 3);
    await store.add('Alpha');
    await store.add('beta');
    await store.add('gamma');
    await store.add('alpha'); // move to front, dedupe
    final list = await store.load();
    expect(list, ['alpha', 'gamma', 'beta']);
  });

  test('clear removes all', () async {
    final store = RecentSearchesStore();
    await store.add('one');
    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
