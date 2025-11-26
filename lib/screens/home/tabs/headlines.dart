import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/remote_config_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../providers/news_provider.dart';

class HeadLinesView extends StatefulWidget {
  const HeadLinesView({super.key});

  @override
  State<HeadLinesView> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<HeadLinesView> {
  String _selectedCategory = 'All';

  // Get dynamic categories from API config, with 'All' as first option
  List<String> get categories {
    final apiCategories = ApiConstants.categories;
    // Capitalize first letter of each category for display
    final formattedCategories = apiCategories.map((cat) {
      if (cat.isEmpty) return cat;
      return cat[0].toUpperCase() + cat.substring(1);
    }).toList();
    return ['All', ...formattedCategories];
  }

  // Get appropriate icon for each category
  Widget _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    IconData iconData;
    
    switch (categoryLower) {
      case 'all':
        iconData = Icons.apps;
        break;
      case 'business':
        iconData = Icons.business;
        break;
      case 'politics':
        iconData = Icons.how_to_vote;
        break;
      case 'sports':
        iconData = Icons.sports_soccer;
        break;
      case 'entertainment':
        iconData = Icons.movie;
        break;
      case 'technology':
        iconData = Icons.computer;
        break;
      case 'science':
        iconData = Icons.science;
        break;
      case 'health':
        iconData = Icons.health_and_safety;
        break;
      case 'food':
        iconData = Icons.restaurant;
        break;
      case 'environment':
        iconData = Icons.eco;
        break;
      case 'tourism':
        iconData = Icons.flight;
        break;
      case 'world':
        iconData = Icons.public;
        break;
      case 'top':
        iconData = Icons.trending_up;
        break;
      default:
        iconData = Icons.category;
    }
    
    return Icon(
      iconData,
      size: 16,
      color: Colors.white.withOpacity(0.8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final primaryColor = config.primaryColorValue;
        final theme = Theme.of(context);
        final newsProvider = Provider.of<NewsProvider>(context);

        final isDark = theme.brightness == Brightness.dark;
        debugPrint(
          "Dark secondary color: ${Theme.of(context).colorScheme.secondary} and $isDark",
        );
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    if (category != 'All') {
                      // Convert display name back to API format (lowercase)
                      final apiCategory = category.toLowerCase();
                      newsProvider.fetchNewsByCategory(apiCategory);
                    } else {
                      // If "All" is selected, fetch breaking news
                      newsProvider.fetchBreakingNews();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category icon
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _getCategoryIcon(category),
                        ),
                        // Category text
                        Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
