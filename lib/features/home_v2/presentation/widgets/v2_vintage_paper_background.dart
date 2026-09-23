import 'package:flutter/material.dart';

/// Intensity of the vintage paper atmosphere.
enum V2PaperIntensity {
  /// Softer layer behind header / nav / stage (continuity).
  stage,

  /// Stronger layer inside each TurnablePage sheet (turns with article).
  page,
}

/// Vintage newspaper texture — reused for stage atmosphere and page sheets.
///
/// Asset: [assetPath] (`assets/images/vintage_newspaper_bg.png`).
class V2VintagePaperBackground extends StatelessWidget {
  const V2VintagePaperBackground({
    super.key,
    this.intensity = V2PaperIntensity.page,
  });

  static const String assetPath = 'assets/images/vintage_newspaper_bg.png';

  final V2PaperIntensity intensity;

  /// Warm reading-stage base (Light).
  static const Color lightStageBase = Color(0xFFF2E9DA);

  /// Night-edition charcoal base (Dark).
  static const Color darkStageBase = Color(0xFF141210);

  static Color stageBaseFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkStageBase : lightStageBase;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPage = intensity == V2PaperIntensity.page;

    // Target: clearly perceptible at first glance, still secondary to content.
    final textureOpacity = isDark
        ? (isPage ? 0.38 : 0.26)
        : (isPage ? 0.34 : 0.22);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: isDark ? darkStageBase : lightStageBase,
          ),
          Opacity(
            opacity: textureOpacity,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              color: isDark
                  ? const Color(0xFF8B7F6C)
                  : const Color(0xFFD4C4A8),
              colorBlendMode: BlendMode.modulate,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Soft vignette / edge depth — keeps paper from looking flat/digital.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  (isDark ? Colors.black : const Color(0xFF5C4A32))
                      .withValues(alpha: isDark ? 0.28 : 0.06),
                ],
              ),
            ),
          ),
          if (isDark)
            ColoredBox(
              color: const Color(0xFF0C0A08).withValues(
                alpha: isPage ? 0.22 : 0.30,
              ),
            ),
        ],
      ),
    );
  }
}
