import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/localization_helper.dart';
import '../../../../core/utils/shared_functions.dart';
import '../../domain/publisher_model.dart';

/// Editorial publisher identity header for the V2 Publisher Screen.
class PublisherHeader extends StatelessWidget {
  const PublisherHeader({
    super.key,
    required this.publisher,
    this.isLoading = false,
  });

  final PublisherModel? publisher;
  final bool isLoading;

  Future<void> _visit(BuildContext context) async {
    final url = publisher?.trustedWebsiteUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading && publisher == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final p = publisher;
    if (p == null) return const SizedBox.shrink();

    final website = p.trustedWebsiteUrl;
    final logo = p.logoUrl?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label:
                    '${LocalizationHelper.v2Publisher(context)} ${p.displayName} logo',
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logo != null && logo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: logo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              newsOnImageFallback(width: 72, height: 72),
                        )
                      : newsOnImageFallback(width: 72, height: 72),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      label: p.displayName,
                      child: Text(
                        p.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          height: 1.15,
                          letterSpacing: -0.4,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LocalizationHelper.v2OriginalPublisher(context),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.hintColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.description != null && p.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              p.description!.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          if (website != null) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: LocalizationHelper.v2VisitPublisher(context),
              child: TextButton.icon(
                onPressed: () => _visit(context),
                icon: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  LocalizationHelper.v2VisitPublisher(context),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            LocalizationHelper.v2LatestNews(context),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
