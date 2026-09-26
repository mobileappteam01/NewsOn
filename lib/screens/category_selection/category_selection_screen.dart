import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/category_card.dart';
import '../../core/widgets/category_shimmer.dart';
import '../../data/models/category_model.dart';
import '../../data/services/category_api_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/api_service.dart';
import '../../features/home_v2/data/v2_home_api.dart';
import '../../features/home_v2/domain/v2_category_selection_identity.dart';
import '../../features/home_v2/domain/v2_home_metadata.dart';
import '../../providers/remote_config_provider.dart';
import '../home/home_screen.dart';

/// Category selection screen - First screen of the app or from side menu
class CategorySelectionScreen extends StatefulWidget {
  /// Whether this screen is opened from side menu (existing user updating preferences)
  final bool isFromSideMenu;

  /// When true, load categories from `GET /api/v2/categories` (full catalog).
  /// Default false keeps the V1 `getCategoriesMobile` pagination path unchanged.
  final bool useV2Catalog;

  const CategorySelectionScreen({
    super.key,
    this.isFromSideMenu = false,
    this.useV2Catalog = false,
  });

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final Set<String> _selectedCategoryIds = {}; // Store category IDs
  final CategoryApiService _categoryApiService = CategoryApiService();
  final UserService _userService = UserService();
  final ProfileService _profileService = ProfileService();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination variables
  int _currentPage = 1;
  int _limit = 10;
  int _total = 0; // Total number of items available
  bool _hasMorePages = true;

  // Scroll controller for infinite scroll
  final ScrollController _scrollController = ScrollController();

  /// Check if all categories are selected
  bool get _isAllSelected {
    if (_categories.isEmpty) return false;
    return _categories.every((cat) => _selectedCategoryIds.contains(cat.id));
  }

  /// Check if some (but not all) categories are selected
  bool get _isSomeSelected {
    if (_categories.isEmpty) return false;
    final selectedCount = _visualSelectedCount;
    return selectedCount > 0 && selectedCount < _categories.length;
  }

  /// Count of checked cards — must always equal the header "X of Y" number.
  int get _visualSelectedCount =>
      V2CategorySelectionIdentity.visualSelectedCount(
        selectedIds: _selectedCategoryIds,
        catalog: _categories,
      );

  /// Select all categories
  void _selectAll() {
    setState(() {
      for (final category in _categories) {
        _selectedCategoryIds.add(category.id);
      }
    });
  }

  /// Deselect all categories
  void _deselectAll() {
    setState(() {
      _selectedCategoryIds.clear();
    });
  }

  /// Toggle select/deselect all
  void _toggleSelectAll() {
    if (_isAllSelected) {
      _deselectAll();
    } else {
      _selectAll();
    }
  }

  @override
  void initState() {
    super.initState();
    // V2: catalog must finish before preference hydration so count and cards
    // share one normalized ObjectId set (never race stale V1 ids into the UI).
    if (widget.useV2Catalog) {
      unawaited(_bootstrapV2CatalogAndPreferences());
    } else {
      _loadCategories();
      if (widget.isFromSideMenu) {
        _loadUserCategories();
      }
    }

    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  Future<void> _bootstrapV2CatalogAndPreferences() async {
    await _loadCategories();
    if (!mounted) return;
    if (widget.isFromSideMenu) {
      await _hydrateV2UserCategories();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll events for infinite scroll pagination
  void _onScroll() {
    // Check if we can scroll and if we've reached the threshold
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Load more when user scrolls to 80% of the list
    if (currentScroll >= maxScroll * 0.8) {
      // Prevent multiple simultaneous loads and ensure we haven't loaded all items
      if (!_isLoadingMore &&
          !_isLoading &&
          _hasMorePages &&
          _categories.length < _total) {
        _loadMoreCategories();
      }
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _total = 0;
      _hasMorePages = true;
    });

    try {
      if (widget.useV2Catalog) {
        await _loadV2Categories();
        return;
      }

      final response = await _categoryApiService.getCategories(
        page: 1,
        limit: _limit,
      );

      if (response.success && mounted) {
        setState(() {
          _categories = response.categories;
          _isLoading = false;
          _currentPage = response.page;
          _total = response.total;
          _hasMorePages = response.hasMorePages;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
          // Fallback to empty list if API fails
          _categories = [];
          _total = 0;
          _hasMorePages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load categories: $e';
          _isLoading = false;
          // Fallback to empty list
          _categories = [];
          _total = 0;
          _hasMorePages = false;
        });
      }
    }
  }

  /// V2 catalog: single `GET /api/v2/categories` — full active list, no V1 pages.
  Future<void> _loadV2Categories() async {
    final options = await V2HomeMetadataApi().fetchCategories();
    // Replace (never append) so repeated loads cannot duplicate UI items.
    final models = options
        .map(categoryModelFromV2Option)
        .where((c) => c.id.isNotEmpty && c.isActive && !c.isDeleted)
        .toList();
    if (!mounted) return;
    setState(() {
      _categories = models;
      _isLoading = false;
      _currentPage = 1;
      _total = models.length;
      // Full catalog in one response — no pagination / no page-boundary duplicates.
      _hasMorePages = false;
    });
  }

  /// Load more categories for pagination
  Future<void> _loadMoreCategories() async {
    // V2 catalog is loaded in full — never page the V1 endpoint.
    if (widget.useV2Catalog) return;

    // Prevent loading if already loading, no more pages, or already loaded all items
    if (_isLoadingMore ||
        !_hasMorePages ||
        _isLoading ||
        _categories.length >= _total) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;

      final response = await _categoryApiService.getCategories(
        page: nextPage,
        limit: _limit,
      );

      if (response.success && mounted) {
        setState(() {
          // Only add new categories that aren't already in the list
          final newCategories = response.categories
              .where(
                (cat) => !_categories.any((existing) => existing.id == cat.id),
              )
              .toList();

          _categories.addAll(newCategories);
          _isLoadingMore = false;
          _currentPage = response.page;
          _total = response.total; // Update total in case it changed
          _hasMorePages = response.hasMorePages;

          // Additional safety check: if we've loaded all items, set hasMorePages to false
          if (_categories.length >= _total) {
            _hasMorePages = false;
          }
        });
      } else if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMorePages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMorePages = false;
        });
        debugPrint('❌ Error loading more categories: $e');
      }
    }
  }

  /// Load user's existing categories and pre-select them (V1 profile path).
  Future<void> _loadUserCategories() async {
    try {
      // Check if API Service is initialized
      final apiService = ApiService();
      if (!apiService.isInitialized) {
        await apiService.initialize();
      }

      // Fetch user profile
      final response = await _profileService.getUserProfile();

      if (response.success && response.data != null) {
        // Response structure: {"message": "success", "data": {...userData...}}
        final responseMap = response.data as Map<String, dynamic>;
        final userData = responseMap['data'] as Map<String, dynamic>?;

        if (userData != null && mounted) {
          // Get user's existing categories
          final userCategories = userData['category'] as List?;
          if (userCategories != null && userCategories.isNotEmpty) {
            // Filter out null values and convert to String IDs
            final categoryIds = userCategories
                .where((id) => id != null)
                .map((id) => id.toString())
                .toList();

            debugPrint('📦 User has existing categories: $categoryIds');

            // Pre-select categories
            setState(() {
              _selectedCategoryIds.addAll(categoryIds);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user categories: $e');
    }
  }

  /// V2: hydrate selection from `/api/v2/me/categories` (+ local fallback),
  /// then normalize against the loaded V2 catalog so count == visual cards.
  Future<void> _hydrateV2UserCategories() async {
    if (!widget.useV2Catalog || _categories.isEmpty) return;

    List<String> tokens = const [];
    try {
      final api = ApiService();
      if (!api.isInitialized) {
        await api.initialize();
      }
      final token = _userService.getToken();
      if (token != null && token.isNotEmpty) {
        final response = await api.getByPath(
          '/api/v2/me/categories',
          bearerToken: token,
          useV2Host: true,
        );
        if (response.success && response.data != null) {
          tokens = V2CategorySelectionIdentity.parsePreferenceTokens(
            response.data,
          );
        }
      }
    } catch (e) {
      debugPrint('ℹ️ V2 me/categories hydrate failed: $e');
    }

    if (tokens.isEmpty) {
      tokens = V2CategorySelectionIdentity.parsePreferenceTokens({
        'category': _userService.getUserData()?['category'],
      });
    }

    final normalized = V2CategorySelectionIdentity.normalizeSelectedIds(
      savedTokens: tokens,
      catalog: _categories,
    );

    debugPrint(
      '📦 V2 category hydrate: raw=${tokens.length} → visual=${normalized.length}',
    );

    if (!mounted) return;
    setState(() {
      _selectedCategoryIds
        ..clear()
        ..addAll(normalized);
    });
  }

  /// Persist submitted category IDs into local user data (source of truth for Home chips).
  Future<void> _persistSelectedCategoryIds(
      List<String> selectedCategoryIds) async {
    try {
      final token = _userService.getToken();
      final existing = _userService.getUserData();
      if (token == null || token.isEmpty || existing == null) {
        debugPrint('⚠️ Cannot persist categories: missing local user session');
        return;
      }

      final merged = Map<String, dynamic>.from(existing);
      merged['category'] = List<String>.from(selectedCategoryIds);
      await _userService.saveUserData(token: token, userData: merged);
      debugPrint('✅ Local user categories updated: $selectedCategoryIds');
    } catch (e) {
      debugPrint('❌ Error persisting local category preferences: $e');
    }
  }

  Future<bool> _saveV2CategoryPreferences(List<String> selectedCategoryIds) async {
    final api = ApiService();
    if (!api.isInitialized) {
      await api.initialize();
    }
    final token = _userService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('User data not found. Please sign in again.');
    }
    final response = await api.putByPath(
      '/api/v2/me/categories',
      body: {'categoryIds': selectedCategoryIds},
      bearerToken: token,
      useV2Host: true,
    );
    if (!response.success) {
      throw Exception(response.error ?? 'Failed to update categories');
    }
    await _persistSelectedCategoryIds(selectedCategoryIds);
    return true;
  }

  Future<void> _selectCategories() async {
    // V2 side-menu allows clearing all saved preferences (0 selected).
    if (_selectedCategoryIds.isEmpty &&
        !(widget.useV2Catalog && widget.isFromSideMenu)) {
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
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
      // Only persist IDs that are currently visible in the catalog.
      final selectedCategoryIds = _categories
          .where((cat) => _selectedCategoryIds.contains(cat.id))
          .map((cat) => cat.id)
          .toList();

      // If coming from side menu, update profile with new categories
      if (widget.isFromSideMenu) {
        if (widget.useV2Catalog) {
          try {
            await _saveV2CategoryPreferences(selectedCategoryIds);
            if (!mounted) return;
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Categories updated successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop(true);
          } catch (e) {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Check if API Service is initialized
        final apiService = ApiService();
        if (!apiService.isInitialized) {
          await apiService.initialize();
        }

        // Get user data
        final userData = _userService.getUserData();
        if (userData == null) {
          throw Exception('User data not found. Please sign in again.');
        }

        // Update profile with new categories
        final updateResponse = await _profileService.updateProfile(
          nickName: userData['nickName']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          firstName: userData['firstName']?.toString() ?? '',
          secondName: userData['secondName']?.toString() ?? '',
          personalDetails: userData['personalDetails'] is Map
              ? userData['personalDetails'] as Map
              : null,
          mobileNumber: userData['mobileNumber']?.toString(),
          city: userData['city']?.toString(),
          pincode: userData['pincode']?.toString(),
          country: userData['country']?.toString(),
          category: selectedCategoryIds,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          if (updateResponse.success) {
            // Authoritative local merge: do not rely only on API response body.
            await _persistSelectedCategoryIds(selectedCategoryIds);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Categories updated successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Signal Home to rebuild category chips from updated prefs.
            Navigator.of(context).pop(true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ ${updateResponse.error ?? 'Failed to update categories'}',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // New user flow — account already created at sign-in; save categories.
        if (widget.useV2Catalog) {
          try {
            await _saveV2CategoryPreferences(selectedCategoryIds);
            if (!mounted) return;
            Navigator.of(context).pop();
            await _userService.clearTempGoogleAccount();
            final selectedCategoryNames = _categories
                .where((cat) => _selectedCategoryIds.contains(cat.id))
                .map((cat) => cat.categoryName)
                .toList();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  selectedCategories: selectedCategoryNames,
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        final userData = _userService.getUserData();
        if (userData == null) {
          throw Exception('User data not found. Please sign in again.');
        }

        final nickName =
            StorageService.getSetting(AppConstants.userNameKey) as String? ??
                userData['nickName']?.toString() ??
                '';

        final updateResponse = await _profileService.updateProfile(
          nickName: nickName,
          email: userData['email']?.toString() ?? '',
          firstName: userData['firstName']?.toString() ?? '',
          secondName: userData['secondName']?.toString() ?? '',
          personalDetails: userData['personalDetails'] is Map
              ? userData['personalDetails'] as Map
              : null,
          mobileNumber: userData['mobileNumber']?.toString(),
          city: userData['city']?.toString(),
          pincode: userData['pincode']?.toString(),
          country: userData['country']?.toString(),
          category: selectedCategoryIds,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          if (updateResponse.success) {
            await _userService.clearTempGoogleAccount();

            final selectedCategoryNames = _categories
                .where((cat) => _selectedCategoryIds.contains(cat.id))
                .map((cat) => cat.categoryName)
                .toList();

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  selectedCategories: selectedCategoryNames,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ ${updateResponse.error ?? 'Failed to save categories'}',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
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
              LocalizationHelper.failedToLoadCategories(context),
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? LocalizationHelper.unknownError(context),
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
              label: Text(LocalizationHelper.retry(context)),
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
                        LocalizationHelper.selectCategoryTitle(context),
                        style: GoogleFonts.playfair(
                          color: config.primaryColorValue,
                          fontSize: config.displayMediumFontSize,
                        ),
                        // style: theme.textTheme.displaySmall,
                      ),
                      giveHeight(12),
                      Text(
                        LocalizationHelper.selectCategoryDesc(context),
                        style: GoogleFonts.playfair(
                          color: theme.colorScheme.tertiary,
                          fontSize: config.displaySmallFontSize,
                        ),
                      ),
                      // Select All / Deselect All Button
                      if (!_isLoading && _categories.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              // Selection count
                              Expanded(
                                child: Text(
                                  LocalizationHelper.categoriesSelectedCount(
                                      context,
                                      _visualSelectedCount,
                                      _categories.length),
                                  style: GoogleFonts.roboto(
                                    color: theme.colorScheme.tertiary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Select All / Deselect All Button
                              Flexible(
                                child: InkWell(
                                  onTap: _toggleSelectAll,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isAllSelected
                                          ? config.primaryColorValue
                                              .withOpacity(0.1)
                                          : config.primaryColorValue,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: config.primaryColorValue,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isAllSelected
                                              ? Icons.deselect
                                              : _isSomeSelected
                                                  ? Icons
                                                      .indeterminate_check_box_outlined
                                                  : Icons.select_all,
                                          size: 18,
                                          color: _isAllSelected
                                              ? config.primaryColorValue
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _isAllSelected
                                                ? LocalizationHelper
                                                    .deselectAll(context)
                                                : LocalizationHelper.selectAll(
                                                    context),
                                            style: GoogleFonts.roboto(
                                              color: _isAllSelected
                                                  ? config.primaryColorValue
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Categories Grid or Loading/Error State
                Expanded(
                  child: _isLoading
                      ? const CategoryShimmer()
                      : _errorMessage != null && _categories.isEmpty
                          ? _buildErrorState(theme, config)
                          : GridView.builder(
                              controller: _scrollController,
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
                              itemCount:
                                  _categories.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Show loading indicator at the bottom when loading more
                                if (index == _categories.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final category = _categories[index];
                                final isSelected =
                                    _selectedCategoryIds.contains(
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
                                        _selectedCategoryIds
                                            .remove(category.id);
                                      } else {
                                        _selectedCategoryIds.add(category.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                ),

                // Continue/Update Preferences Button
                _BottomCta(
                  red: config.primaryColorValue,
                  label: widget.isFromSideMenu
                      ? LocalizationHelper.updatePreferences(context)
                      : LocalizationHelper.continueText(context),
                  onTap: (_visualSelectedCount == 0 &&
                          !(widget.useV2Catalog && widget.isFromSideMenu))
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
                //         // backgroundColor: theme.primaryColor,
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

/// Maps V2 `/api/v2/categories` options into the shared [CategoryModel] UI shape.
CategoryModel categoryModelFromV2Option(V2CategoryOption option) {
  final id = (option.id ?? '').trim();
  final name = option.name.trim().isNotEmpty ? option.name.trim() : option.slug;
  final image = option.imageUrl?.trim();
  final media = option.mediaUrl?.trim();
  return CategoryModel(
    id: id.isNotEmpty ? id : option.slug,
    categoryName: name,
    name: option.slug.isNotEmpty ? option.slug : name,
    imageUrl: (image != null && image.isNotEmpty) ? image : null,
    mediaUrl: (media != null && media.isNotEmpty) ? media : null,
    isActive: true,
    isDeleted: false,
  );
}
