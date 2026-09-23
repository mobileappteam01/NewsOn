@Tags(['unit'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/services/font_manager.dart';

import '../test_setup.dart';

/// Deterministic font checks that use the registered Crassula asset family
/// via [FontManager.applyCustomFont] — no Google Fonts CDN.
void main() {
  ensureTestBinding();

  test('applyCustomFont sets Crassula family', () {
    final style = FontManager.applyCustomFont(const TextStyle(fontSize: 16));
    expect(style.fontFamily, 'Crassula');
    expect(style.fontSize, 16);
  });

  test('crassula extension sets Crassula family', () {
    const base = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
    expect(base.crassula.fontFamily, 'Crassula');
    expect(base.crassulaWithWeight(FontWeight.w700).fontWeight, FontWeight.w700);
  });

  test('isFontLoaded placeholder remains true', () {
    expect(FontManager.isFontLoaded(), isTrue);
  });
}
