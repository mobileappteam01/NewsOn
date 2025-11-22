import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/utils/shared_functions.dart';
import '../../core/utils/localization_helper.dart';
import '../../providers/remote_config_provider.dart';
import '../../widgets/news_grid_views.dart';

class BookMark extends StatefulWidget {
  const BookMark({super.key});

  @override
  State<BookMark> createState() => _BookMarkState();
}

class _BookMarkState extends State<BookMark> {
  List newsList = [
    {
      "img":
          "https://firebasestorage.googleapis.com/v0/b/newson-dea6b.firebasestorage.app/o/appImages%2FWhatsApp%20Image%202025-11-07%20at%203.00.50%20PM.jpeg?alt=media&token=1f22daa3-5466-441d-a078-fea3cbba84c0",
      "category": "Politics",
      "headLines":
          "Trump Tariffs: India can get 25% off its tariffs if NewDelhi stops buying Russia...",
      "updatedAt": "15Min ago",
    },
    {
      "img":
          "https://firebasestorage.googleapis.com/v0/b/newson-dea6b.firebasestorage.app/o/appImages%2FWhatsApp%20Image%202025-11-07%20at%203.00.50%20PM.jpeg?alt=media&token=1f22daa3-5466-441d-a078-fea3cbba84c0",
      "category": "Politics",
      "headLines":
          "Trump Tariffs: India can get 25% off its tariffs if NewDelhi stops buying Russia...",
      "updatedAt": "15Min ago",
    },
  ];
  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.config;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // Header
                  commonappBar(config.appNameLogo, () {
                    Navigator.pop(context);
                  }),
                  giveHeight(12),

                  // Title
                  Text(
                    LocalizationHelper.bookmarks(context),
                    style: GoogleFonts.playfairDisplay(
                      color: config.primaryColorValue,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  giveHeight(20),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    itemBuilder: (c, i) {
                      var details = newsList[0];
                      return NewsGridView(
                        type: 'listview',
                        newsDetails: details,
                        onListenTapped: () {},
                        onNewsTapped: () {},
                        onSaveTapped: () {},
                        onShareTapped: () {},
                      );
                    },
                  ),

                  // 🔹 User name section
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
