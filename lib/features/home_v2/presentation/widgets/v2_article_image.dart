import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/shared_functions.dart';

/// Large editorial hero image with subtle depth.
class V2ArticleImage extends StatelessWidget {
  const V2ArticleImage({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 4 / 3,
    this.borderRadius = 18,
  });

  final String? imageUrl;
  final double aspectRatio;
  final double borderRadius;

  /// Decode width of hero images in the memory cache.
  static const int decodeWidth = 1200;

  /// The image provider [V2ArticleImage] shows for [url]. Precaching this
  /// exact provider fills the cache entry the page reads instead of decoding
  /// the image a second time at full size.
  static ImageProvider provider(String url) => ResizeImage.resizeIfNeeded(
        decodeWidth,
        null,
        CachedNetworkImageProvider(url),
      );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            child: url.isEmpty
                ? newsOnImageFallback(
                    height: double.infinity,
                    logoMaxExtent: 72,
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    memCacheWidth: decodeWidth,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => newsOnImageFallback(
                      height: double.infinity,
                      logoMaxExtent: 72,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
