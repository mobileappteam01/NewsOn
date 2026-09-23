import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/search/presentation/news_search_controller.dart';

void main() {
  test('V2 search + for you flags default OFF', () {
    final config = RemoteConfigModel();
    expect(V2FeatureFlags.search(config), isFalse);
    expect(V2FeatureFlags.forYou(config), isFalse);
    expect(config.v2SearchEnabled, isFalse);
    expect(config.v2ForYouEnabled, isFalse);
  });

  test('suggestion debounce duration is bounded', () {
    expect(
      NewsSearchController.suggestionDebounce,
      const Duration(milliseconds: 350),
    );
  });
}
