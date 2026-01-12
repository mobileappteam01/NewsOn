import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/utils/localization_helper.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';
import '../../providers/remote_config_provider.dart';
import '../category_selection/category_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  String _name = '';

  @override
  void initState() {
    super.initState();
    // Priority 1: Get name from StorageService (saved in onboarding screen)
    final savedName = StorageService.getSetting(
      AppConstants.userNameKey,
      defaultValue: '',
    );

    if (savedName is String && savedName.isNotEmpty) {
      _name = savedName;
    } else {
      // Priority 2: Fallback to nickname from UserService (from sign-up API response)
      final userService = UserService();
      final nickName = userService.getNickName();
      _name = nickName ?? '';
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final red = AppTheme.primaryRed;
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                return Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      width: c.maxWidth * 0.4,
                      height: c.maxHeight * 0.55,
                      child: Container(
                        color: isDark ? Colors.white : const Color(0xFF4A4A4A),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.7),
                      child: Container(
                        width: c.maxWidth * 0.7,
                        height: c.maxWidth * 0.7,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: config.welcomeBgImg != null &&
                                config.welcomeBgImg.isNotEmpty
                            ? showImage(config.welcomeBgImg, BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Icon(
                                    Icons.wb_sunny,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0.7, 0.50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LocalizationHelper.welcomeTitleText(context),
                            style: GoogleFonts.playfair(
                              fontSize: config.displayLargeFontSize,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),

                          Text(
                            _name.toUpperCase(),
                            style: GoogleFonts.playfair(
                              color: config.primaryColorValue,
                              fontSize: 50,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          Text(
                            LocalizationHelper.welcomeDescText(context),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfair(
                              fontSize: config.displaySmallFontSize,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SwipeButton.expand(
                          thumb: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 28,
                          ),
                          activeThumbColor: red,
                          activeTrackColor: const Color(0xFF4A4A4A),
                          onSwipe: () {
                            _finish();
                          },
                          child: Text(
                            config.splashSwipeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

