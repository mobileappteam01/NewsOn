import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/background_music_service.dart';

void main() {
  group('BackgroundMusicService Tests', () {
    late BackgroundMusicService service;

    setUp(() {
      service = BackgroundMusicService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should initialize correctly', () async {
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect(service.volume, equals(0.19)); // Default background volume
    });

    test('should set volume within bounds', () async {
      await service.initialize();

      await service.setVolume(0.5);
      expect(service.volume, equals(0.5));

      await service.setVolume(1.5); // Should be clamped to 1.0
      expect(service.volume, equals(1.0));

      await service.setVolume(-0.5); // Should be clamped to 0.0
      expect(service.volume, equals(0.0));
    });

    test('should track playing state correctly', () async {
      await service.initialize();

      expect(service.isPlaying, isFalse);
      expect(service.currentMusicUrl,
          isNotNull); // Should have URL from Firebase or fallback
    });

    test('should handle Firebase URL fetch', () async {
      await service.initialize();

      // The service should fetch URL from Firebase or use fallback
      final url = service.currentMusicUrl;
      expect(url, isNotNull);
      expect(url, isNotEmpty);

      print('Background music URL: $url');
    });
  });
}
