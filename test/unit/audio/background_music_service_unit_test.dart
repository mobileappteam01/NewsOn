@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:newson/data/services/background_music_service.dart';

import '../audio/fake_audio_player_adapter.dart';
import '../../test_setup.dart';

void main() {
  ensureTestBinding();

  group('BackgroundMusicService with FakeAudioPlayerAdapter', () {
    late FakeAudioPlayerAdapter player;
    late BackgroundMusicService service;

    setUp(() {
      player = FakeAudioPlayerAdapter();
      service = BackgroundMusicService.forTesting(player: player);
    });

    tearDown(() async {
      await service.dispose();
      BackgroundMusicService.debugOverrideInstance(null);
    });

    test('constructor does not create native AudioPlayer', () {
      // If construction reached here with a fake, eager native init was avoided.
      expect(player.initialized, isFalse);
      expect(service.isInitialized, isFalse);
    });

    test('initialize uses adapter and sets volume', () async {
      // Force fallback path by initializing (Firebase may fail in VM).
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect(player.initialized, isTrue);
      expect(player.volume, closeTo(0.19, 0.001));
    });

    test('setVolume updates without requiring play', () async {
      await service.initialize();
      await service.setVolume(0.5);
      expect(service.volume, 0.5);
      expect(player.volume, 0.5);
    });

    test('stop/pause are safe before start', () async {
      await service.stop();
      await service.pause();
      expect(service.isPlaying, isFalse);
    });

    test('dispose marks adapter disposed', () async {
      await service.initialize();
      await service.dispose();
      expect(player.disposed, isTrue);
    });
  });

  group('FakeAudioPlayerAdapter contract', () {
    test('play/pause/stop/source lifecycle', () async {
      final p = FakeAudioPlayerAdapter();
      await p.initialize(volume: 0.2);
      await p.setAudioSource(AudioSource.uri(Uri.parse('https://example.test/a.mp3')));
      expect(p.hasLoadedSource, isTrue);
      await p.play();
      expect(p.playing, isTrue);
      await p.pause();
      expect(p.playing, isFalse);
      await p.stop();
      expect(p.stopCalls, 1);
      await p.dispose();
      expect(p.disposed, isTrue);
    });
  });
}
