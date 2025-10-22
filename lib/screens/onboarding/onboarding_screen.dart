import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
import '../category_selection/category_selection_screen.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
    );
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await StorageService.saveSetting(AppConstants.userNameKey, name);
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  void _next() {
    if (_index < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final red = AppTheme.primaryRed;
    final pages = <_OnboardPage>[
      const _OnboardPage(
        image: 'assets/images/App_Images/Welcoming screen.png',
        title: 'WELCOME TO NEWSON',
      ),
      const _OnboardPage(
        image: 'assets/images/App_Images/Splash Screen.png',
        title: 'LATEST HEADLINES AT YOUR FINGERTIPS',
      ),
      const _OnboardPage(
        image: 'assets/images/App_Images/About_Screen_01.png',
        title: 'WELCOME  ABOARD, NEWS\nENTHUSIAST!',
      ),
      const _OnboardPage(
        image: 'assets/images/App_Images/Headlines screen.png',
        title: 'READ NEWS WITH ONLY ONE\nAPP, HEADNEWS!',
      ),
      _OnboardPage(
        image: 'assets/images/App_Images/Headlines screen.png',
        title: 'GET READY TO EXPLORE THE WORLD OF NEWS!',
        showNameInput: true,
        nameController: _nameController,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip',
              style: TextStyle(color: red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _index = i),
              children: pages,
            ),
          ),
          const SizedBox(height: 8),
          _Dots(count: pages.length, index: _index, activeColor: red),
          const SizedBox(height: 16),
          _BottomCta(
            red: red,
            label: _index == pages.length - 1 ? 'Get started' : 'Continue',
            onTap: _next,
          ),
          const SizedBox(height: 16),
        ],
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

    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                image,
                fit: BoxFit.cover,
              ),
            ),
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
            Align(
              alignment: const Alignment(0, 0.3),
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
            if (showNameInput)
              Align(
                alignment: const Alignment(0, 0.6),
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
              BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter your nick name   & Swipe to get started',
                hintStyle: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(color: red.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.person, color: red),
          ),
        ],
      ),
    );
  }
}
