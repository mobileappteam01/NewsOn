import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routing/v2_routes.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/localization_helper.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/interaction_service.dart';
import '../../../data/services/news_share_service.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../home/presentation/widgets/latest_news_card.dart';
import '../../news/domain/news_summary.dart';
import '../../news/presentation/widgets/newson_cut_card.dart';
import '../data/search_repository.dart';
import '../domain/search_session.dart';
import 'news_search_controller.dart';

/// V2 Search tab — validation, recent searches, submit analytics, pagination.
class V2SearchTab extends StatefulWidget {
  const V2SearchTab({super.key, this.repository});

  final SearchRepository? repository;

  @override
  State<V2SearchTab> createState() => _V2SearchTabState();
}

class _V2SearchTabState extends State<V2SearchTab>
    with AutomaticKeepAliveClientMixin {
  late final NewsSearchController _controller;
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _bootstrapped = false;
  final Set<String> _impressedIds = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = NewsSearchController(
      repository: widget.repository ?? SearchRepository(),
    );
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bootstrapped || !mounted) return;
      _bootstrapped = true;
      await _controller.bootstrap();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _text.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _controller.loadMore();
    }
  }

  Future<void> _submit([String? raw]) async {
    final q = raw ?? _text.text;
    _impressedIds.clear();
    await _controller.submit(q);
    if (!mounted) return;
    final state = _controller.state;
    if (state.status == SearchStatus.ready) {
      await AnalyticsService.instance.search(
        query: state.submittedQuery,
        v2Only: true,
      );
    }
  }

  Future<void> _setLanguage(String? code) async {
    _impressedIds.clear();
    await _controller.setSearchLanguage(code);
  }

  void _clear() {
    _text.clear();
    _impressedIds.clear();
    _controller.clear();
  }

  Widget _clearButton(SearchState state) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _text,
      builder: (context, value, _) {
        if (value.text.isEmpty && state.submittedQuery.isEmpty) {
          return const SizedBox.shrink();
        }
        return IconButton(
          key: const ValueKey('v2_search_clear'),
          icon: const Icon(Icons.close_rounded),
          tooltip: LocalizationHelper.clear(context),
          onPressed: _clear,
        );
      },
    );
  }

  Widget _languageSelector(ThemeData theme, String? selected) {
    final options = SearchLanguages.options;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final code = i == 0 ? null : options[i - 1].code;
          return ChoiceChip(
            key: ValueKey('v2_search_language_${code ?? 'all'}'),
            label: Text(
              code == null
                  ? LocalizationHelper.v2HomeCategoryAll(context)
                  : options[i - 1].nativeName,
            ),
            selected: selected == code,
            showCheckmark: false,
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            onSelected: (_) => _setLanguage(code),
          );
        },
      ),
    );
  }

  Future<void> _open(NewsArticle article, int index) async {
    await AnalyticsService.instance.newsOpen(
      newsId: article.analyticsNewsId,
      v2Only: true,
    );
    if (!mounted) return;
    await V2Routes.openArticle(
      context,
      article: article,
      articles: _controller.state.results,
      initialIndex: index,
    );
  }

  void _emitImpressions(List<NewsArticle> articles) {
    for (final a in articles.take(12)) {
      final id = a.analyticsNewsId;
      if (id.isEmpty || _impressedIds.contains(id)) continue;
      _impressedIds.add(id);
      AnalyticsService.instance.newsImpression(
        newsId: id,
        category: a.category?.isNotEmpty == true ? a.category!.first : null,
        publisher: a.publisherDisplayName,
        v2Only: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final config = context.watch<RemoteConfigProvider>().config;
    final bookmarks = context.watch<BookmarkProvider>();

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final suggestions = _controller.localSuggestions(_text.text);
        if (state.status == SearchStatus.ready && state.results.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _emitImpressions(state.results);
          });
        }

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationHelper.search(context),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _text,
                      textInputAction: TextInputAction.search,
                      onChanged: _controller.onQueryChanged,
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: LocalizationHelper.v2SearchHint(context),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _clearButton(state),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              tooltip: LocalizationHelper.v2Search(context),
                              onPressed: () => _submit(),
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _languageSelector(theme, state.searchLanguage),
                  ],
                ),
              ),
              if (state.recent.isNotEmpty &&
                  state.results.isEmpty &&
                  state.status != SearchStatus.loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        LocalizationHelper.v2RecentSearches(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _controller.clearRecent,
                        child: Text(LocalizationHelper.v2ClearAll(context)),
                      ),
                    ],
                  ),
                ),
              if (suggestions.isNotEmpty &&
                  state.status != SearchStatus.loading &&
                  state.results.isEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final s = suggestions[i];
                      return InputChip(
                        key: ValueKey('v2_recent_search_$s'),
                        label: Text(s),
                        onPressed: () {
                          _text.text = s;
                          _submit(s);
                        },
                        onDeleted: () => _controller.removeRecent(s),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        deleteButtonTooltipMessage:
                            LocalizationHelper.v2RemoveRecentSearch(context, s),
                      );
                    },
                  ),
                ),
              if (state.errorCode != null && state.results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage(context, state.errorCode!),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Expanded(
                child: state.status == SearchStatus.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.status == SearchStatus.ready &&
                            state.results.isEmpty &&
                            state.submittedQuery.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                LocalizationHelper.noResultsFound(context),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : state.status == SearchStatus.idle &&
                                state.results.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    LocalizationHelper.v2SearchHint(context),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _submit(state.submittedQuery),
                                child: ListView.builder(
                                  controller: _scroll,
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 8, 0, 88),
                                  itemCount: state.results.length +
                                      (state.status ==
                                              SearchStatus.loadingMore
                                          ? 1
                                          : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= state.results.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    final article = state.results[index];
                                    final hasCut =
                                        article.newsOnCutText != null;
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 14),
                                      child: hasCut
                                          ? NewsOnCutCard(
                                              article: article,
                                              cutsLabel:
                                                  config.v2NewsCutsLabel,
                                              isBookmarked: bookmarks
                                                  .isBookmarked(article),
                                              onTap: () =>
                                                  _open(article, index),
                                              onBookmark: () async {
                                                await bookmarks
                                                    .toggleBookmarkV2(article);
                                                await AnalyticsService.instance
                                                    .bookmark(
                                                  newsId:
                                                      article.analyticsNewsId,
                                                  v2Only: true,
                                                );
                                              },
                                              onShare: () async {
                                                await NewsShareService
                                                    .shareArticle(
                                                  article,
                                                  v2: true,
                                                );
                                                await InteractionService()
                                                    .trackShare(article);
                                                await AnalyticsService.instance
                                                    .share(
                                                  newsId:
                                                      article.analyticsNewsId,
                                                  v2Only: true,
                                                );
                                              },
                                            )
                                          : LatestNewsCard(
                                              article: article,
                                              isBookmarked: bookmarks
                                                  .isBookmarked(article),
                                              onTap: () =>
                                                  _open(article, index),
                                              onBookmark: () async {
                                                await bookmarks
                                                    .toggleBookmarkV2(article);
                                                await AnalyticsService.instance
                                                    .bookmark(
                                                  newsId:
                                                      article.analyticsNewsId,
                                                  v2Only: true,
                                                );
                                              },
                                              onShare: () async {
                                                await NewsShareService
                                                    .shareArticle(
                                                  article,
                                                  v2: true,
                                                );
                                                await InteractionService()
                                                    .trackShare(article);
                                                await AnalyticsService.instance
                                                    .share(
                                                  newsId:
                                                      article.analyticsNewsId,
                                                  v2Only: true,
                                                );
                                              },
                                            ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _errorMessage(BuildContext context, String code) {
    switch (code) {
      case 'too_short':
        return LocalizationHelper.v2SearchTooShort(context);
      case 'too_long':
        return LocalizationHelper.v2SearchTooLong(context);
      default:
        return LocalizationHelper.v2SearchFailed(context);
    }
  }
}
