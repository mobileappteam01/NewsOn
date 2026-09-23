import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

/// Deterministic smoke — does not boot Firebase / NewsOnApp.
void main() {
  ensureTestBinding();

  testWidgets('MaterialApp smoke builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('NewsOn'),
        ),
      ),
    );
    expect(find.text('NewsOn'), findsOneWidget);
  });
}
