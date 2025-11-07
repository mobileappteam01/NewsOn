import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/storage_service.dart';
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
    final v = StorageService.getSetting(
      AppConstants.userNameKey,
      defaultValue: '',
    );
    _name = v is String ? v : '';
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final red = AppTheme.primaryRed;
    final theme = Theme.of(context);
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
                        child: showImage(config.welcomeBgImg, BoxFit.cover),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0.7, 0.50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            config.welcomeTitleText,
                            style: GoogleFonts.playfair(
                              fontSize: config.displayLargeFontSize,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),

                          Text(
                            'JOHN PAUL',
                            style: GoogleFonts.playfair(
                              color: config.primaryColorValue,
                              fontSize: 50,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          Text(
                            config.welcomeDescText,
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
                      child: _SlideToStart(
                        red: red,
                        onCompleted: _finish,
                        text: config.splashSwipeText,
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

class _SlideToStart extends StatefulWidget {
  final Color red;
  final String text;
  final VoidCallback onCompleted;

  const _SlideToStart({
    required this.red,
    required this.onCompleted,
    required this.text,
  });

  @override
  State<_SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<_SlideToStart>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  double _progress = 0.0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() => setState(() {}));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final tween = Tween<double>(
      begin: _progress,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller
      ..reset()
      ..forward();
    tween.addListener(() {
      setState(() => _progress = tween.value);
    });
  }

  void _onPanUpdate(DragUpdateDetails d, double max) {
    if (_completed) return;
    final dx = d.localPosition.dx.clamp(0.0, max);
    setState(() => _progress = dx / max);
  }

  void _onPanEnd(double max) {
    if (_completed) return;
    if (_progress > 0.65) {
      _completed = true;
      _animateTo(1.0);
      Future.delayed(const Duration(milliseconds: 320), widget.onCompleted);
    } else {
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.9;
    const height = 64.0;
    const knob = 50.0;
    final trackColor = const Color(0xFF4A4A4A);
    final pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    return GestureDetector(
      onHorizontalDragUpdate: (d) => _onPanUpdate(d, width - knob - 14),
      onHorizontalDragEnd: (_) => _onPanEnd(width - knob - 14),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, _) {
                  final offset =
                      2 + 4 * pulse.value; // subtle drift to the right
                  final opacity1 = 0.4 + 0.6 * (1 - pulse.value);
                  final opacity2 = 0.4 + 0.6 * (0.5 + 0.5 * pulse.value);
                  final opacity3 = 0.4 + 0.6 * pulse.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      giveWidth(48),
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Opacity(
                        opacity: opacity1,
                        child: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(offset, 0),
                        child: Opacity(
                          opacity: opacity2,
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(offset * 2, 0),
                        child: Opacity(
                          opacity: opacity3,
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              left: 7 + (width - knob - 14) * _progress,
              child: Transform.scale(
                scale: 1.0 + 0.06 * _progress,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(
                    color: widget.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
