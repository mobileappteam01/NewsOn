// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/remote_config_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/user_service.dart';
import '../../providers/remote_config_provider.dart';
import '../welcome/welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _index = 0;
  List<_OnboardPage> onBoardingContent = [];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _skip() {
    // Only skip if content is loaded and we're not already on the last page
    if (onBoardingContent.isNotEmpty && _index < onBoardingContent.length - 1) {
      final lastPageIndex = onBoardingContent.length - 1;
      _pageController.animateToPage(
        lastPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await StorageService.saveSetting(AppConstants.userNameKey, name);
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  void _next() {
    if (onBoardingContent.isNotEmpty && _index < onBoardingContent.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _finish();
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill name from temporary Google account data (if available)
    final userService = UserService();
    final googleAccountData = userService.getTempGoogleAccount();
    if (googleAccountData != null) {
      final displayName = googleAccountData['displayName'] as String? ?? '';
      if (displayName.isNotEmpty) {
        // Use first name from display name
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        if (firstName.isNotEmpty) {
          _nameController.text = firstName;
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configProvider = Provider.of<RemoteConfigProvider>(
        context,
        listen: false,
      );
      if (configProvider.isInitialized) {
        _loadOnboarding(configProvider.config);
      } else {
        configProvider.initialize().then((_) {
          _loadOnboarding(configProvider.config);
        });
      }
    });
  }

  void _loadOnboarding(RemoteConfigModel config) {
    try {
      final jsonString = config.onboardingFeatures;
      if (jsonString.isEmpty) return;

      final List<dynamic> decoded = jsonDecode(jsonString);

      setState(() {
        onBoardingContent =
            decoded.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              return _OnboardPage(
                image: e['image'],
                title: e['title'],
                showNameInput:
                    index == decoded.length - 1, // ✅ Show on last page
                nameController:
                    index == decoded.length - 1 ? _nameController : null,
              );
            }).toList();
      });
    } catch (e) {
      debugPrint("Error parsing onboarding: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final red = AppTheme.primaryRed;
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: onBoardingContent,
                  ),
                ),
                const SizedBox(height: 8),
                _Dots(
                  count: onBoardingContent.length,
                  index: _index,
                  activeColor: red,
                ),
                const SizedBox(height: 16),
                _BottomCta(
                  red: red,
                  label:
                      _index == onBoardingContent.length - 1
                          ? 'Get started'
                          : 'Continue',
                  onTap: _next,
                ),
                const SizedBox(height: 16),
              ],
            ),
            // Only show Skip button if content is loaded and not on last page
            if (onBoardingContent.isNotEmpty &&
                _index < onBoardingContent.length - 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onBoardingContent.isNotEmpty ? _skip : null,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: red, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String image;
  final String title;
  final bool showNameInput;
  final TextEditingController? nameController;

  const _OnboardPage({
    required this.image,
    required this.title,
    this.showNameInput = false,
    this.nameController,
  });

  @override
  Widget build(BuildContext context) {
    final red = AppTheme.primaryRed;
    final cleanUrl = image.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            /// ✅ Full-width image with proper scaling
            Positioned.fill(
              child:
                  cleanUrl.isNotEmpty
                      ? Image.network(
                        cleanUrl,
                        fit: BoxFit.cover, // or BoxFit.fitWidth
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          );
                        },
                      )
                      : const Center(
                        child: Icon(Icons.image_not_supported, size: 48),
                      ),
            ),

            /// ✅ Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.9),
                      Colors.white,
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            /// ✅ Title
            Align(
              alignment: Alignment(0, showNameInput ? 0.6 : 0.9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            /// ✅ Nickname input (only on last page)
            if (showNameInput)
              Align(
                alignment: const Alignment(0, 0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _NameField(controller: nameController!, red: red),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;

  const _Dots({
    required this.count,
    required this.index,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return Container(
          width: active ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
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
          height: 64,
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

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final Color red;

  const _NameField({required this.controller, required this.red});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter your nick name',
                hintStyle: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: red.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: red),
          ),
        ],
      ),
    );
  }
}
