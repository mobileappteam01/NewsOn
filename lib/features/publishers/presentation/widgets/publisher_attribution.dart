import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routing/v2_routes.dart';
import '../../../../core/utils/localization_helper.dart';
import '../../../../data/models/news_article.dart';
import '../../../../providers/language_provider.dart';
import '../../../news/domain/news_summary.dart';

/// Tappable publisher chip when a real [NewsArticle.publisherId] exists and
/// publisher pages are enabled; otherwise plain text.
class PublisherAttribution extends StatelessWidget {
  const PublisherAttribution({
    super.key,
    required this.article,
    this.style,
    this.showIcon = false,
    this.iconSize = 20,
    this.sourceScreen = 'feed',
  });

  final NewsArticle article;
  final TextStyle? style;
  final bool showIcon;
  final double iconSize;
  final String sourceScreen;

  @override
  Widget build(BuildContext context) {
    final name = article.publisherDisplayName;
    final enabled = V2Routes.canOpenPublisher(context, article);
    final label = '${LocalizationHelper.v2Publisher(context)} $name';

    final text = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    Widget child = text;
    if (showIcon) {
      final icon = article.sourceIcon;
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: icon != null && icon.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: icon,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.apartment,
                        size: iconSize * 0.8,
                      ),
                    )
                  : Icon(Icons.apartment, size: iconSize * 0.8),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: text),
        ],
      );
    }

    if (!enabled) {
      return Semantics(label: label, child: child);
    }

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          V2Routes.openPublisherFromArticle(
            context,
            article,
            sourceScreen: sourceScreen,
            language: context.read<LanguageProvider>().newsLanguageCode,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: child,
        ),
      ),
    );
  }
}
