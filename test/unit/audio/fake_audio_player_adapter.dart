import 'package:just_audio/just_audio.dart';
import 'package:newson/data/services/audio_player_adapter.dart';

/// In-memory audio adapter for deterministic VM tests.
class FakeAudioPlayerAdapter implements AudioPlayerAdapter {
  bool initialized = false;
  bool playing = false;
  bool disposed = false;
  double volume = 1.0;
  AudioSource? source;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> initialize({required double volume}) async {
    this.volume = volume;
    initialized = true;
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> setAudioSource(AudioSource source) async {
    this.source = source;
  }

  @override
  bool get hasLoadedSource => source != null && !disposed;

  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
  }
}
