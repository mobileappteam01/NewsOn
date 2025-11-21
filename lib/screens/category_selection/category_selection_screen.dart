import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/category_card.dart';
import '../../core/widgets/category_shimmer.dart';
import '../../data/models/category_model.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/services/category_api_service.dart';
import '../../data/services/fcm_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';
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
  final Set<String> _selectedCategoryIds = {}; // Store category IDs
  final CategoryApiService _categoryApiService = CategoryApiService();
  final AuthApiService _authApiService = AuthApiService();
  final UserService _userService = UserService();
  final FcmService _fcmService = FcmService();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _categoryApiService.getCategories();

      if (response.success && mounted) {
        setState(() {
          _categories = response.categories;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
          // Fallback to empty list if API fails
          _categories = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load categories: $e';
          _isLoading = false;
          // Fallback to empty list
          _categories = [];
        });
      }
    }
  }

  Future<void> _selectCategories() async {
    if (_selectedCategoryIds.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const CircularProgressIndicator(),
            ),
          ),
    );

    try {
      // Step 1: Get nickname from onboarding (stored in StorageService)
      final nickName =
          StorageService.getSetting(AppConstants.userNameKey) as String? ?? '';

      // Step 2: Get Google account data (stored temporarily)
      final googleAccountData = _userService.getTempGoogleAccount();
      if (googleAccountData == null) {
        throw Exception('Google account data not found. Please sign in again.');
      }

      // Step 3: Get FCM token
      final fcmToken = await _fcmService.getToken();

      // Step 4: Get selected category IDs as array
      final selectedCategoryIds = _selectedCategoryIds.toList();

      // Step 5: Call Sign-Up API
      final signUpResponse = await _authApiService.signUp(
        googleAccountData: googleAccountData,
        nickName: nickName,
        fcmToken: fcmToken,
        categoryIds: selectedCategoryIds,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (signUpResponse.success) {
          // Extract token and user data from response
          final responseData = signUpResponse.data as Map<String, dynamic>?;

          if (responseData != null) {
            final token = responseData['token'] as String?;
            final userData = responseData['data'] as Map<String, dynamic>?;

            if (token != null && userData != null) {
              // Save user data and token
              await _userService.saveUserData(token: token, userData: userData);

              // Clear temporary Google account data
              await _userService.clearTempGoogleAccount();

              // Get selected category names for HomeScreen
              final selectedCategoryNames =
                  _categories
                      .where((cat) => _selectedCategoryIds.contains(cat.id))
                      .map((cat) => cat.categoryName)
                      .toList();

              // Navigate to home screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (context) =>
                          HomeScreen(selectedCategories: selectedCategoryNames),
                ),
              );
            } else {
              throw Exception('Invalid response: missing token or user data');
            }
          } else {
            throw Exception('Invalid response format');
          }
        } else {
          // Sign-up failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${signUpResponse.message}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildErrorState(ThemeData theme, dynamic config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load categories',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: theme.colorScheme.tertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCategories,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: config.primaryColorValue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

                // Categories Grid or Loading/Error State
                Expanded(
                  child:
                      _isLoading
                          ? const CategoryShimmer()
                          : _errorMessage != null && _categories.isEmpty
                          ? _buildErrorState(theme, config)
                          : GridView.builder(
                            padding: const EdgeInsets.all(
                              AppConstants.defaultPadding,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: AppConstants.defaultPadding,
                                  mainAxisSpacing: AppConstants.defaultPadding,
                                  childAspectRatio: 1.2,
                                ),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isSelected = _selectedCategoryIds.contains(
                                category.id,
                              );

                              return CategoryCard(
                                category: category.categoryName,
                                imageUrl: category.imageUrl,
                                isSelected: isSelected,
                                index: index,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedCategoryIds.remove(category.id);
                                    } else {
                                      _selectedCategoryIds.add(category.id);
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
                  onTap:
                      _selectedCategoryIds.isEmpty
                          ? null
                          : () async {
                            // Call selectCategories API before navigating
                            await _selectCategories();
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
  final VoidCallback? onTap;

  const _BottomCta({required this.red, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Opacity(
          opacity: onTap != null ? 1.0 : 0.5,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            width: MediaQuery.of(context).size.width * 0.9,
            decoration: BoxDecoration(
              color: onTap != null ? red : Colors.grey,
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
      ),
    );
  }
}
