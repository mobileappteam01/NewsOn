# Testing Guide — NewsOn Flutter

## Fast default (local development)

```bash
fvm flutter test
# or
flutter test
```

Runs **Category A + safe Category B** only:

- pure Dart / models / parsers
- V2 feature flags, routing contracts, analytics contracts
- notification payload resolution
- search / For You / publishers unit tests
- font unit/widget tests (no native plugins)
- voice/audio **unit** tests using fakes

Configured via root [`dart_test.yaml`](../dart_test.yaml):

```yaml
exclude_tags: integration || platform || network || performance
```

## Why platform tests are separate

The Dart VM test harness does **not** provide native implementations for:

- `speech_to_text`
- `just_audio` / `audio_session`
- Firebase platform channels
- FCM / device permissions

Those suites hang, throw `MissingPluginException`, or depend on network/Firebase.
They are preserved under `test/integration/` and tagged — not deleted.

## Integration / platform suites

Default `exclude_tags` still applies when a path is given. Select tags explicitly:

```bash
# All classified integration suites
fvm flutter test --tags "integration || platform || network || performance"

# By tag
fvm flutter test --tags integration
fvm flutter test --tags platform
fvm flutter test --tags network
fvm flutter test --tags performance

# Path + tags. Note: CLI `--exclude-tags` is **merged with** root
# `dart_test.yaml` exclude_tags (not replaced). To run network suites you must
# temporarily clear/adjust root exclude_tags, or invoke a dedicated runner.
fvm flutter test test/integration --tags "integration || platform || network || performance"

# Phase 10B staging live checks are captured as fixtures under
# test/fixtures/phase10b/ plus curl probes documented in
# docs/V2_PHASE10B_FLUTTER_STAGING_VALIDATION.md.
# Tagged live file: test/integration/network/phase10b_staging_validation_test.dart
# Staging Flutter base URL (optional, does not change Firebase):
#   --dart-define=NEWSON_API_BASE_URL=http://127.0.0.1:8010
```

### Voice (real plugin)

```bash
fvm flutter test test/integration/platform/voice_search_test.dart
fvm flutter test test/integration/platform/enhanced_voice_search_test.dart
```

Prefer a device/simulator. VM runs will fail without the plugin.

### Deterministic voice unit tests (default suite)

```bash
fvm flutter test test/unit/voice
```

Uses `FakeSpeechRecognitionEngine` injected via `VoiceSearchService.withEngine`.

### Audio / background music (real plugin + network/Firebase)

```bash
fvm flutter test test/integration/platform
fvm flutter test test/integration/network
```

Includes:

- `background_music_full_integration_test.dart` (bounded 2‑minute group timeout)
- `comprehensive_background_music_test.dart`
- `background_music_service_test.dart`
- `firebase_integration_test.dart`
- `background_music_integration_test.dart`

### Deterministic audio unit tests (default suite)

```bash
fvm flutter test test/unit/audio
```

Uses `FakeAudioPlayerAdapter`. Production still uses `JustAudioPlayerAdapter`
with **lazy** `AudioPlayer` creation inside `BackgroundMusicService`.

### Firebase

```bash
fvm flutter test --tags network
# or
fvm flutter test test/integration/network/firebase_integration_test.dart
```

### Performance

Wall-clock / timing suites are tagged `performance` (e.g. enhanced voice).

```bash
fvm flutter test --tags performance
```

Do not rely on tight local machine timing in CI via the default suite.

### Fonts

`FontManager` styles use `GoogleFonts.openSans` (CDN). Those widget/integration
font suites live under `test/integration/network/` and need either network or
bundled OpenSans assets.

Deterministic Crassula asset checks remain in:

```bash
fvm flutter test test/unit/font_crassula_unit_test.dart
```

```
test/
  unit/            # deterministic fakes (voice, audio)
  features/        # V2 + feature unit/widget tests
  integration/
    platform/      # native plugin required
    network/       # Firebase / remote URLs
  *.dart           # remaining fast unit/widget tests
  test_setup.dart  # TestWidgetsFlutterBinding only — no real plugins
```

## Rules

- Default `flutter test` must stay deterministic: no 10‑minute sync tests,
  no real native plugin init, no external network.
- Do not delete integration coverage — reclassify with tags/directories.
- Production code keeps real plugins; tests inject fakes where needed.
