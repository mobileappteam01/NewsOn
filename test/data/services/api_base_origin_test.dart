import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Uri.origin preserves non-default staging port', () {
    final staging = Uri.parse('http://127.0.0.1:8010');
    expect(staging.origin, 'http://127.0.0.1:8010');

    final prod = Uri.parse('https://api.newson.app');
    expect(prod.origin, 'https://api.newson.app');

    // Regression: host-only construction drops :8010 and breaks V2 getByPath.
    final broken = '${staging.scheme}://${staging.host}';
    expect(broken, 'http://127.0.0.1');
    expect(broken, isNot(staging.origin));
  });
}
