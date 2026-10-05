import 'package:flutter/widgets.dart';

import '../../../data/models/news_article.dart';

/// Built book pages, reused while their inputs are unchanged so a page turn
/// (which rebuilds Home) does not rebuild every article page. Each page sits
/// behind a [RepaintBoundary]: the book repaints on every drag frame and then
/// only re-composites the pages' recorded layers.
class V2ReaderPageCache {
  final Map<int, _CachedPage> _entries = {};
  int _epoch = -1;

  /// Drops pages of another book and indexes the current one does not have.
  void prepare(int epoch, int pageCount) {
    if (epoch != _epoch) {
      _epoch = epoch;
      _entries.clear();
    } else {
      _entries.removeWhere((index, _) => index >= pageCount);
    }
  }

  /// Page [index] for [article] (compared by identity) and [inputs]
  /// (compared with `==`), built by [build] when either changed.
  Widget get(
    int index,
    NewsArticle? article,
    Object inputs,
    Widget Function() build,
  ) {
    final hit = _entries[index];
    if (hit != null &&
        identical(hit.article, article) &&
        hit.inputs == inputs) {
      return hit.page;
    }
    final page = RepaintBoundary(child: build());
    _entries[index] = _CachedPage(article, inputs, page);
    return page;
  }
}

class _CachedPage {
  const _CachedPage(this.article, this.inputs, this.page);

  final NewsArticle? article;
  final Object inputs;
  final Widget page;
}

/// Compares [value] by identity inside a record of page inputs.
class V2IdentityKey {
  const V2IdentityKey(this.value);

  final Object value;

  @override
  bool operator ==(Object other) =>
      other is V2IdentityKey && identical(other.value, value);

  @override
  int get hashCode => identityHashCode(value);
}
