import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared bootstrap for deterministic VM tests.
///
/// Does NOT initialize real platform plugins (speech_to_text, just_audio,
/// Firebase native, etc.).
void ensureTestBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Prevent google_fonts from hitting the network during VM tests.
  GoogleFonts.config.allowRuntimeFetching = false;
}
