import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/localization_helper.dart';
import '../../core/widgets/category_card.dart';
import '../../providers/news_provider.dart';
import '../../core/widgets/audio_mini_player.dart';
import '../news_detail/news_detail_screen.dart';
import '../../core/widgets/news_card.dart';
import '../../core/widgets/loading_shimmer.dart';

/// Categories tab - Browse news by category
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab>
    with AutomaticKeepAliveClientMixin {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final newsProvider = Provider.of<NewsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(LocalizationHelper.categories(context))),
      body: Stack(
        children: [
          Column(
            children: [
              // Categories Grid
              SizedBox(
                height: 180,
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppConstants.defaultPadding,
                    mainAxisSpacing: AppConstants.defaultPadding,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: ApiConstants.categories.length,
                  itemBuilder: (context, index) {
                    final category = ApiConstants.categories[index];
                    final isSelected = _selectedCategory == category;

                    return CategoryCard(
                      category: category,
                      imageUrl: AppConstants.categoryImages[category],
                      isSelected: isSelected,
                      index: index,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        newsProvider.fetchNewsByCategory(category);
                      },
                    );
                  },
                ),
              ),

              const Divider(),

              // Category News List
              Expanded(
                child:
                    _selectedCategory == null
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 64,
                                color: theme.primaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a category',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose a category above to view news',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                        : newsProvider.isLoading &&
                            newsProvider.articles.isEmpty
                        ? const LoadingShimmer()
                        : newsProvider.error != null
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                newsProvider.error!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  if (_selectedCategory != null) {
                                    newsProvider.fetchNewsByCategory(
                                      _selectedCategory!,
                                    );
                                  }
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                        : newsProvider.articles.isEmpty
                        ? const Center(child: Text('No news available'))
                        : ListView.builder(
                          itemCount: newsProvider.articles.length,
                          itemBuilder: (context, index) {
                            final article = newsProvider.articles[index];
                            return NewsCard(
                              article: article,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            NewsDetailScreen(article: article),
                                  ),
                                );
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
          // Audio Mini Player (Spotify-like)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const AudioMiniPlayer(),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
