import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/dynamic_localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('bundled Malayalam translations include bottom nav keys', () async {
    final json = await rootBundle.loadString('assets/languages/ml.json');
    expect(json.contains('"forYou"'), isTrue);
    expect(json.contains('"menu"'), isTrue);
    expect(json.contains('"today"'), isTrue);
    expect(json.contains('"forLater"'), isTrue);
    expect(json.contains('"search"'), isTrue);
    expect(json.contains('നിങ്ങൾക്കായി'), isTrue);
    expect(json.contains('മെനു'), isTrue);
  });

  test('bundled Telugu and Kannada include forYou', () async {
    final te = await rootBundle.loadString('assets/languages/te.json');
    final kn = await rootBundle.loadString('assets/languages/kn.json');
    expect(te.contains('"forYou"'), isTrue);
    expect(kn.contains('"forYou"'), isTrue);
    expect(te.contains('మీ కోసం'), isTrue);
    expect(kn.contains('ನಿಮಗಾಗಿ'), isTrue);
  });

  test('DynamicLocalizationService serves Malayalam after setLanguage', () async {
    final service = DynamicLocalizationService();
    await service.setLanguage('ml', forceReload: true);

    expect(service.currentLanguageCode, 'ml');
    expect(service.hasTranslation('forYou'), isTrue);
    expect(service.translate('forYou'), 'നിങ്ങൾക്കായി');
    expect(service.translate('menu'), 'മെനു');
    expect(service.translate('today'), 'ഇന്ന്');
    expect(service.translate('forLater'), 'പിന്നീട്');
    expect(service.translate('search'), 'തിരയുക');
  });

  test('switching Tamil → Malayalam → Telugu updates nav labels', () async {
    final service = DynamicLocalizationService();

    await service.setLanguage('ta', forceReload: true);
    expect(service.translate('forYou'), isNot(equals('നിങ്ങൾക്കായി')));

    await service.setLanguage('ml', forceReload: true);
    expect(service.translate('forYou'), 'നിങ്ങൾക്കായി');
    expect(service.translate('menu'), 'മെനു');

    await service.setLanguage('te', forceReload: true);
    expect(service.translate('forYou'), 'మీ కోసం');
    expect(service.translate('menu'), 'మెనూ');

    await service.setLanguage('kn', forceReload: true);
    expect(service.translate('forYou'), 'ನಿಮಗಾಗಿ');
    expect(service.translate('menu'), 'ಮೆನು');
  });
}
