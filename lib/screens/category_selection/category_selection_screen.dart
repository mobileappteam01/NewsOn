import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/category_card.dart';
import '../../providers/remote_config_provider.dart';
import '../home/home_screen.dart';

/// Category selection screen - First screen of the app
class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final Set<String> _selectedCategories = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<RemoteConfigProvider>(
        builder: (context, configProvider, child) {
          final config = configProvider.config;
          return SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppConstants.largePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        config.selectCategoryTitle,
                        style: GoogleFonts.playfair(
                          color: config.primaryColorValue,
                          fontSize: config.displayMediumFontSize,
                        ),
                        // style: theme.textTheme.displaySmall,
                      ),
                      giveHeight(12),
                      Text(
                        config.selectCategoryDesc,
                        style: GoogleFonts.playfair(
                          color: theme.colorScheme.tertiary,
                          fontSize: config.displaySmallFontSize,
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppConstants.defaultPadding,
                          mainAxisSpacing: AppConstants.defaultPadding,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: ApiConstants.categories.length,
                    itemBuilder: (context, index) {
                      final category = ApiConstants.categories[index];
                      final isSelected = _selectedCategories.contains(category);

                      return CategoryCard(
                        category: category,
                        imageUrl: AppConstants.categoryImages[category],
                        isSelected: isSelected,
                        index: index,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCategories.remove(category);
                            } else {
                              _selectedCategories.add(category);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),

                // Continue Button
                _BottomCta(
                  red: config.primaryColorValue,
                  label: 'Continue',
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder:
                            (context) => HomeScreen(
                              selectedCategories: _selectedCategories.toList(),
                            ),
                      ),
                    );
                  },
                ),
                // Padding(
                //   padding: const EdgeInsets.all(AppConstants.largePadding),
                //   child: SizedBox(
                //     width: double.infinity,
                //     height: 56,
                //     child: ElevatedButton(
                //       onPressed:
                //           _selectedCategories.isEmpty
                //               ? null
                //               : () {
                //                 Navigator.of(context).pushReplacement(
                //                   MaterialPageRoute(
                //                     builder:
                //                         (context) => HomeScreen(
                //                           selectedCategories:
                //                               _selectedCategories.toList(),
                //                         ),
                //                   ),
                //                 );
                //               },
                //       style: ElevatedButton.styleFrom(
                //         // backgroundColor: theme.colorScheme.primary,
                //         foregroundColor: Colors.white,
                //         shape: RoundedRectangleBorder(
                //           borderRadius: BorderRadius.circular(
                //             AppConstants.borderRadius,
                //           ),
                //         ),
                //       ),
                //       child: Row(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //         children: [
                //           Text(
                //             'Continue',
                //             // style: theme.textTheme.titleMedium?.copyWith(
                //             //   color: Colors.white,
                //             // ),
                //           ),
                //           const SizedBox(width: 8),
                //           const Icon(Icons.arrow_forward, color: Colors.white),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  final Color red;
  final String label;
  final VoidCallback onTap;

  const _BottomCta({
    required this.red,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: red,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Colors.white),
              const Icon(Icons.chevron_right, color: Colors.white),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
