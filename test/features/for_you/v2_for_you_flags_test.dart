import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';
import 'package:newson/features/for_you/data/for_you_repository.dart';

void main() {
  test('V2 For You flag defaults OFF so V1 tab remains', () {
    final config = RemoteConfigModel();
    expect(V2FeatureFlags.forYou(config), isFalse);
  });

  test('feed sources include cold start and empty', () {
    expect(ForYouFeedSource.values, contains(ForYouFeedSource.personalized));
    expect(ForYouFeedSource.values, contains(ForYouFeedSource.coldStartFallback));
    expect(ForYouFeedSource.values, contains(ForYouFeedSource.anonymousFallback));
    expect(ForYouFeedSource.values, contains(ForYouFeedSource.empty));
  });
}
