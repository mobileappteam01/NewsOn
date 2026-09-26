import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/models/category_model.dart';
import 'package:newson/features/home_v2/domain/v2_category_selection_identity.dart';

CategoryModel _cat(String id, String slug, {String? display}) => CategoryModel(
      id: id,
      categoryName: display ?? slug,
      name: slug,
      isActive: true,
      isDeleted: false,
    );

List<CategoryModel> _catalog(int n) {
  return List.generate(
    n,
    (i) => _cat(
      i.toString().padLeft(24, 'a'),
      'cat$i',
      display: 'Category $i',
    ),
  );
}

void main() {
  group('V2CategorySelectionIdentity', () {
    test('0 selected of 18 → count == visual', () {
      final catalog = _catalog(18);
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: const [],
        catalog: catalog,
      );
      final count = V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: selected,
        catalog: catalog,
      );
      expect(count, 0);
      expect(count, selected.length);
      expect(catalog.where((c) => selected.contains(c.id)).length, count);
    });

    test('1 selected of 18 → count == visual', () {
      final catalog = _catalog(18);
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: [catalog[3].id],
        catalog: catalog,
      );
      final count = V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: selected,
        catalog: catalog,
      );
      expect(count, 1);
      expect(count, selected.length);
      expect(catalog.where((c) => selected.contains(c.id)).length, 1);
    });

    test('7 selected of 18 → count == visual', () {
      final catalog = _catalog(18);
      final tokens = catalog.take(7).map((c) => c.id).toList();
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: tokens,
        catalog: catalog,
      );
      final count = V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: selected,
        catalog: catalog,
      );
      expect(count, 7);
      expect(count, selected.length);
      expect(catalog.where((c) => selected.contains(c.id)).length, 7);
    });

    test('18 selected of 18 → count == visual', () {
      final catalog = _catalog(18);
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: catalog.map((c) => c.id),
        catalog: catalog,
      );
      final count = V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: selected,
        catalog: catalog,
      );
      expect(count, 18);
      expect(count, selected.length);
    });

    test('slug tokens normalize to catalog ObjectIds', () {
      final catalog = _catalog(18);
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: ['cat0', 'CAT2', 'Category 4'],
        catalog: catalog,
      );
      expect(selected, {catalog[0].id, catalog[2].id, catalog[4].id});
      expect(
        V2CategorySelectionIdentity.visualSelectedCount(
          selectedIds: selected,
          catalog: catalog,
        ),
        3,
      );
    });

    test('stale preference IDs are dropped — never inflate count', () {
      final catalog = _catalog(18);
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: [
          catalog[0].id,
          catalog[1].id,
          'zzzzzzzzzzzzzzzzzzzzzzzz', // stale V1 / deleted
          'legacy-slug',
        ],
        catalog: catalog,
      );
      expect(selected, {catalog[0].id, catalog[1].id});
      final count = V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: selected,
        catalog: catalog,
      );
      expect(count, 2);
      // Raw set with stale ids would have been 4 — that was the bug.
      expect(count, isNot(4));
    });

    test('me/categories envelope parses ids', () {
      final tokens = V2CategorySelectionIdentity.parsePreferenceTokens({
        'success': true,
        'data': {
          'categories': [
            {'id': 'aaaaaaaaaaaaaaaaaaaaaaaa', 'name': 'Sports', 'slug': 'sports'},
            {'_id': 'bbbbbbbbbbbbbbbbbbbbbbbb'},
          ],
        },
      });
      expect(tokens, [
        'aaaaaaaaaaaaaaaaaaaaaaaa',
        'bbbbbbbbbbbbbbbbbbbbbbbb',
      ]);
    });

    test('local category array fallback parses', () {
      final tokens = V2CategorySelectionIdentity.parsePreferenceTokens({
        'category': ['id1', 'id2', null, 'id1'],
      });
      expect(tokens, ['id1', 'id2']);
    });

    test('19th and 25th dynamic categories work; new ones unselected', () {
      final catalog19 = _catalog(19);
      final catalog25 = _catalog(25);
      final saved7 = catalog19.take(7).map((c) => c.id).toList();

      final sel19 = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: saved7,
        catalog: catalog19,
      );
      expect(
        V2CategorySelectionIdentity.visualSelectedCount(
          selectedIds: sel19,
          catalog: catalog19,
        ),
        7,
      );
      expect(sel19.contains(catalog19[18].id), isFalse);

      final sel25 = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: saved7,
        catalog: catalog25,
      );
      expect(
        V2CategorySelectionIdentity.visualSelectedCount(
          selectedIds: sel25,
          catalog: catalog25,
        ),
        7,
      );
      expect(sel25.contains(catalog25[24].id), isFalse);
    });

    test('deselect then select keeps count == visual', () {
      final catalog = _catalog(18);
      final selected = V2CategorySelectionIdentity.normalizeSelectedIds(
        savedTokens: catalog.take(7).map((c) => c.id),
        catalog: catalog,
      ).toSet();
      selected.remove(catalog[2].id); // deselect
      selected.add(catalog[10].id); // select another
      final count = V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: selected,
        catalog: catalog,
      );
      expect(count, 7);
      expect(catalog.where((c) => selected.contains(c.id)).length, count);
    });
  });
}
