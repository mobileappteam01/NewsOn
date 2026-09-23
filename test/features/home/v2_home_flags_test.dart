import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';

void main() {
    test('V2 home flags default OFF so V1 remains default', () {
    final config = RemoteConfigModel();
    expect(V2FeatureFlags.newsCuts(config), isFalse);
    expect(V2FeatureFlags.newArticleDetail(config), isFalse);
    expect(V2FeatureFlags.fullArticle(config), isFalse);
    expect(V2FeatureFlags.relatedNews(config), isFalse);
    expect(V2FeatureFlags.pageTurn(config), isFalse);
    expect(V2FeatureFlags.publisherPages(config), isFalse);
    expect(V2FeatureFlags.search(config), isFalse);
    expect(V2FeatureFlags.forYou(config), isFalse);
    expect(V2FeatureFlags.audio(config), isFalse);
    expect(V2FeatureFlags.audioGeneration(config), isFalse);
    expect(V2FeatureFlags.notifications(config), isFalse);
    expect(V2FeatureFlags.homeReader(config), isFalse);
  });
}
