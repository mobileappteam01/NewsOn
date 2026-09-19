import 'package:flutter_test/flutter_test.dart';
import 'package:newson/data/services/background_music_service.dart';

/// Integration tests for background music functionality
/// Tests core functionality without Firebase dependencies
void main() {
  group('Background Music Integration Tests', () {
    late BackgroundMusicService service;

    setUp(() async {
      service = BackgroundMusicService();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('Service Lifecycle', () {
      test('should initialize with fallback URL when Firebase unavailable',
          () async {
        // This simulates the real scenario where Firebase might not be available
        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.currentMusicUrl, isNotNull);
        expect(service.currentMusicUrl, isNotEmpty);
        expect(service.volume, equals(0.19)); // Updated volume

        print(
            '✅ Service initialized with fallback URL: ${service.currentMusicUrl}');
      });

      test('should handle dispose correctly', () async {
        await service.initialize();
        expect(service.isInitialized, isTrue);

        await service.dispose();
        // After dispose, service should be reset
        expect(service.isPlaying, isFalse);

        print('✅ Service disposed correctly');
      });
    });

    group('Volume Control', () {
      test('should set and get volume correctly', () async {
        await service.initialize();

        // Test various volume levels
        await service.setVolume(0.5);
        expect(service.volume, equals(0.5));

        await service.setVolume(0.8);
        expect(service.volume, equals(0.8));

        await service.setVolume(1.0);
        expect(service.volume, equals(1.0));

        print('✅ Volume control working correctly');
      });

      test('should clamp volume to valid range', () async {
        await service.initialize();

        // Test volume clamping
        await service.setVolume(1.5); // Should clamp to 1.0
        expect(service.volume, equals(1.0));

        await service.setVolume(-0.5); // Should clamp to 0.0
        expect(service.volume, equals(0.0));

        await service.setVolume(0.0);
        expect(service.volume, equals(0.0));

        print('✅ Volume clamping working correctly');
      });
    });

    group('State Management', () {
      test('should track playing state correctly', () async {
        await service.initialize();

        expect(service.isPlaying, isFalse);
        expect(service.isInitialized, isTrue);

        print('✅ State tracking working correctly');
      });

      test('should expose current music URL', () async {
        await service.initialize();

        final url = service.currentMusicUrl;
        expect(url, isNotNull);
        expect(url, isNotEmpty);
        expect(url!.startsWith('http'), isTrue);

        print('✅ Music URL exposure working: $url');
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors gracefully', () async {
        // Test multiple initializations
        await service.initialize();
        await service.initialize(); // Should not crash

        expect(service.isInitialized, isTrue);

        print('✅ Multiple initialization handled gracefully');
      });

      test('should handle operations before initialization', () async {
        // Test operations before initialization
        expect(service.isInitialized, isFalse);

        // These should not crash
        await service.setVolume(0.5);
        expect(service.volume, equals(0.5));

        print('✅ Pre-initialization operations handled gracefully');
      });
    });

    group('Real-world Scenarios', () {
      test('should simulate app startup scenario', () async {
        // Simulate app startup
        await service.initialize();

        expect(service.isInitialized, isTrue);
        // Note: Volume might be from previous test due to singleton
        expect(service.volume, greaterThanOrEqualTo(0.0));
        expect(service.volume, lessThanOrEqualTo(1.0));
        expect(service.currentMusicUrl, isNotNull);

        // Simulate user adjusting volume
        await service.setVolume(0.25);
        expect(service.volume, equals(0.25));

        print('✅ App startup scenario working');
      });

      test('should simulate background music lifecycle', () async {
        // Simulate complete lifecycle
        await service.initialize();

        // Check initial state
        expect(service.isPlaying, isFalse);
        // Note: Volume might be from previous test due to singleton
        expect(service.volume, greaterThanOrEqualTo(0.0));
        expect(service.volume, lessThanOrEqualTo(1.0));

        // Simulate volume adjustment by user
        await service.setVolume(0.3);
        expect(service.volume, equals(0.3));

        // Simulate app backgrounding/foregrounding
        // (In real app, this would pause/resume)

        print('✅ Background music lifecycle scenario working');
      });
    });

    group('Performance Tests', () {
      test('should initialize quickly', () async {
        final stopwatch = Stopwatch()..start();

        await service.initialize();

        stopwatch.stop();

        // Should initialize within reasonable time (even with fallback)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));

        print('✅ Initialization time: ${stopwatch.elapsedMilliseconds}ms');
      });

      test('should handle rapid volume changes', () async {
        await service.initialize();

        // Rapid volume changes
        for (int i = 0; i < 10; i++) {
          await service.setVolume((i % 10) / 10.0);
        }

        expect(service.volume, equals(0.9)); // Last value set

        print('✅ Rapid volume changes handled correctly');
      });
    });
  });
}
