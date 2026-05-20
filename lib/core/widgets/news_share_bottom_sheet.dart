import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/news_article.dart';
import '../../data/services/news_share_service.dart';
import '../../providers/remote_config_provider.dart';

/// Bottom sheet with Share action for a news article.
void showNewsShareBottomSheet(BuildContext context, NewsArticle article) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final config = sheetContext.watch<RemoteConfigProvider>().config;
      final primary = config.primaryColorValue;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.share_outlined, color: primary),
                title: const Text('Share this news'),
                subtitle: const Text(
                  'Friends with NewsOn can open the article in the app',
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await NewsShareService.shareArticle(article);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
