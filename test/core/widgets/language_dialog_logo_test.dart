import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/utils/shared_functions.dart';
import 'package:newson/core/widgets/language_selector_dialog.dart';
import 'package:newson/providers/dynamic_language_provider.dart';
import 'package:newson/providers/language_provider.dart';
import 'package:newson/providers/remote_config_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue7 language dialog logo', () {
    testWidgets('uses bundled asset path (no indefinite shimmer)', (tester) async {
      expect(kNewsOnLogoAsset, 'assets/images/newson.png');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => DynamicLanguageProvider()),
            ChangeNotifierProvider(create: (_) => RemoteConfigProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LanguageSelectorDialog(type: LanguageSelectorType.news),
            ),
          ),
        ),
      );
      await tester.pump();

      // Prefer local Image.asset — never stuck on network/shimmer-only.
      expect(find.byType(Image), findsWidgets);
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final assetImages = images.where((i) => i.image is AssetImage).toList();
      expect(assetImages, isNotEmpty);
      final asset = assetImages.first.image as AssetImage;
      expect(asset.assetName, kNewsOnLogoAsset);

      // No CircularProgressIndicator left as a permanent logo placeholder.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders in dark theme without hanging', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => DynamicLanguageProvider()),
            ChangeNotifierProvider(create: (_) => RemoteConfigProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: LanguageSelectorDialog(type: LanguageSelectorType.news),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
