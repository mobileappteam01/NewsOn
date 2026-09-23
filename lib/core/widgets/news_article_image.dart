import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/news_article.dart';
import '../../data/services/news_image_cache_service.dart';
import '../../providers/remote_config_provider.dart';
import '../utils/shared_functions.dart';

/// Cap decode size so expand/full-bleed cards still avoid multi‑megapixel bitmaps.
const int _kMaxMemCachePx = 1280;

/// Branded app logo shown when a news image is missing or fails to load.
/// Uses the same remote-config logo as the home feed header.
Widget newsArticleImageFallback(
  BuildContext context, {
  double? width,
  double? height,
  Color? backgroundColor,
}) {
  final theme = Theme.of(context);
  final bg = backgroundColor ??
      (theme.brightness == Brightness.dark
          ? Colors.grey.shade900
          : Colors.grey.shade100);

  return Consumer<RemoteConfigProvider>(
    builder: (context, configProvider, _) {
      return Container(
        width: width ?? double.infinity,
        height: height,
        color: bg,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: showImage(
            configProvider.config.getAppNameLogoForTheme(theme.brightness),
            BoxFit.contain,
            height: _fallbackLogoHeight(height),
            width: _fallbackLogoWidth(width),
          ),
        ),
      );
    },
  );
}

double? _fallbackLogoHeight(double? containerHeight) {
  if (containerHeight == null || !containerHeight.isFinite) return 60;
  return (containerHeight * 0.45).clamp(32, 80);
}

double? _fallbackLogoWidth(double? containerWidth) {
  if (containerWidth == null || !containerWidth.isFinite) return 80;
  return (containerWidth * 0.55).clamp(48, 100);
}

int? _memCachePx(double? logicalPx, double devicePixelRatio) {
  if (logicalPx == null || !logicalPx.isFinite || logicalPx <= 0) return null;
  return (logicalPx * devicePixelRatio).round().clamp(1, _kMaxMemCachePx);
}

/// Lightweight static skeleton (no spinner / no per-thumb animation).
Widget _staticImagePlaceholder({
  required ThemeData theme,
  double? width,
  double? height,
  Color? backgroundColor,
}) {
  final isDark = theme.brightness == Brightness.dark;
  return Container(
    width: width,
    height: height,
    color: backgroundColor ??
        (isDark ? Colors.grey.shade800 : const Color(0xFFE8E8E8)),
  );
}

/// Cached news thumbnail with themed logo fallback (not for news detail hero).
///
/// Decodes at approximately the on-screen size (× device pixel ratio) so Home
/// list thumbs do not keep full source-resolution bitmaps in memory.
/// Disk caching via [NewsImageCacheService] / [DefaultCacheManager] is unchanged.
class NewsArticleImage extends StatelessWidget {
  const NewsArticleImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.backgroundColor,
  });

  factory NewsArticleImage.fromArticle(
    NewsArticle article, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Color? backgroundColor,
  }) {
    return NewsArticleImage(
      imageUrl: article.imageUrl ?? article.sourceIcon,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      backgroundColor: backgroundColor,
    );
  }

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = newsArticleImageFallback(
      context,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
    );

    final resolved = imageUrl?.trim();
    if (resolved == null || resolved.isEmpty) {
      return fallback;
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalW = width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final logicalH = height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : null);

        final memW = _memCachePx(logicalW, dpr);
        final memH = _memCachePx(logicalH, dpr);

        return NewsImageCacheService.instance.cachedImage(
          url: resolved,
          fit: fit,
          width: width,
          height: height,
          memCacheWidth: memW,
          memCacheHeight: memH,
          placeholder: placeholder ??
              _staticImagePlaceholder(
                theme: theme,
                width: width,
                height: height,
                backgroundColor: backgroundColor,
              ),
          errorWidget: fallback,
        );
      },
    );
  }
}

/// Convenience wrapper matching [showImage] call sites for article thumbnails.
Widget showNewsArticleImage(
  BuildContext context,
  String? imageUrl,
  BoxFit fit, {
  double? height,
  double? width,
  Color? backgroundColor,
}) {
  return NewsArticleImage(
    imageUrl: imageUrl,
    fit: fit,
    height: height,
    width: width,
    backgroundColor: backgroundColor,
  );
}
