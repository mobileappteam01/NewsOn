import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/config/v2_feature_flags.dart';
import 'package:newson/data/models/remote_config_model.dart';

void main() {
  test('without dart-defines, V2 flags stay OFF', () {
    final config = RemoteConfigModel(
      v2SearchEnabled: false,
      v2ForYouEnabled: false,
      v2NotificationsEnabled: false,
    );
    expect(V2FeatureFlags.search(config), isFalse);
    expect(V2FeatureFlags.forYou(config), isFalse);
    expect(V2FeatureFlags.notifications(config), isFalse);
  });

  test('Remote Config true values still respected when defines unset', () {
    final config = RemoteConfigModel(
      v2SearchEnabled: true,
      v2ForYouEnabled: true,
      v2NotificationsEnabled: true,
    );
    expect(V2FeatureFlags.search(config), isTrue);
    expect(V2FeatureFlags.forYou(config), isTrue);
    expect(V2FeatureFlags.notifications(config), isTrue);
  });
}
