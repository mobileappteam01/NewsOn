@Tags(['integration', 'platform', 'performance'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:newson/core/services/voice_search_service.dart';

/// Enhanced Voice Search Test Suite
/// Tests all real-world voice search scenarios and edge cases
void main() {
  // Initialize Flutter binding for tests
  WidgetsFlutterBinding.ensureInitialized();

  group('Enhanced Voice Search Tests', () {
    late VoiceSearchService voiceSearchService;

    setUp(() {
      voiceSearchService = VoiceSearchService();
    });

    tearDown(() {
      voiceSearchService.dispose();
    });

    group('Initialization and Basic Functionality', () {
      test('should initialize voice search service quickly', () async {
        print('🧪 Testing voice search initialization...');

        final stopwatch = Stopwatch()..start();
        final success = await voiceSearchService.initialize();
        stopwatch.stop();

        expect(success, isTrue,
            reason: 'Voice search should initialize successfully');
        expect(voiceSearchService.isInitialized, isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(3000),
            reason: 'Initialization should complete within 3 seconds');

        print(
            '✅ Voice search initialized in ${stopwatch.elapsedMilliseconds}ms');
      });

      test('should handle enhanced listening parameters', () async {
        print('🧪 Testing enhanced listening parameters...');

        await voiceSearchService.initialize();

        bool listeningStarted = false;
        bool listeningEnded = false;
        String capturedText = '';
        List<String> intermediateResults = [];

        final success = await voiceSearchService.startListening(
          silenceTimeout: const Duration(seconds: 2), // Shorter for testing
          maxListeningDuration:
              const Duration(seconds: 10), // Shorter for testing
          onListeningStart: () {
            listeningStarted = true;
            print('🎤 Enhanced listening started');
          },
          onListeningEnd: () {
            listeningEnded = true;
            print('🔇 Enhanced listening ended');
          },
          onResult: (result) {
            capturedText = result;
            intermediateResults.add(result);
            print('📝 Enhanced result: $result');
          },
        );

        expect(success, isTrue,
            reason: 'Should start enhanced listening successfully');
        expect(listeningStarted, isTrue,
            reason: 'Listening start callback should be called');
        expect(voiceSearchService.isListening, isTrue,
            reason: 'Should be listening');

        // Wait a moment for listening to establish
        await Future.delayed(const Duration(seconds: 1));

        // Test stopping listening
        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue,
            reason: 'Listening should end when stopped');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Should not be listening after stop');

        print('✅ Enhanced listening parameters test completed');
        print('📊 Intermediate results: ${intermediateResults.length}');
        print('📊 Final text: $capturedText');
      });
    });

    group('Real-World Scenarios', () {
      test('should handle slow speech with pauses', () async {
        print('🧪 Testing slow speech with pauses...');

        await voiceSearchService.initialize();

        bool listeningStarted = false;
        bool listeningEnded = false;
        List<String> capturedResults = [];
        DateTime? startTime;
        DateTime? endTime;

        final success = await voiceSearchService.startListening(
          silenceTimeout: const Duration(seconds: 5), // Longer for slow speech
          maxListeningDuration: const Duration(seconds: 15),
          onListeningStart: () {
            listeningStarted = true;
            startTime = DateTime.now();
            print('🎤 Slow speech listening started');
          },
          onListeningEnd: () {
            listeningEnded = true;
            endTime = DateTime.now();
            print('🔇 Slow speech listening ended');
          },
          onResult: (result) {
            capturedResults.add(result);
            print('📝 Slow speech result: $result');
          },
        );

        expect(success, isTrue,
            reason: 'Should start listening for slow speech');
        expect(listeningStarted, isTrue, reason: 'Should start listening');

        // Simulate slow speech with pauses
        print('🗣️ Simulating slow speech with pauses...');
        await Future.delayed(const Duration(seconds: 8));

        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue, reason: 'Should end listening');
        expect(capturedResults.isNotEmpty, isTrue,
            reason: 'Should capture some results');

        if (startTime != null && endTime != null) {
          final duration = endTime!.difference(startTime!);
          print('⏱️ Slow speech duration: ${duration.inSeconds}s');
          expect(duration.inSeconds, greaterThan(5),
              reason: 'Should handle slow speech duration');
        }

        print('✅ Slow speech test completed');
        print('📊 Captured results: ${capturedResults.length}');
      });

      test('should handle no speech detected scenario', () async {
        print('🧪 Testing no speech detected scenario...');

        await voiceSearchService.initialize();

        bool listeningStarted = false;
        bool listeningEnded = false;
        String capturedText = '';

        final success = await voiceSearchService.startListening(
          silenceTimeout: const Duration(seconds: 3), // Shorter timeout
          maxListeningDuration: const Duration(seconds: 8),
          onListeningStart: () {
            listeningStarted = true;
            print('🎤 No speech test listening started');
          },
          onListeningEnd: () {
            listeningEnded = true;
            print('🔇 No speech test listening ended');
          },
          onResult: (result) {
            capturedText = result;
            print('📝 No speech test result: $result');
          },
        );

        expect(success, isTrue, reason: 'Should start listening');
        expect(listeningStarted, isTrue, reason: 'Should start listening');

        // Wait for timeout (no speech)
        print('⏳ Waiting for silence timeout...');
        await Future.delayed(const Duration(seconds: 10));

        expect(listeningEnded, isTrue,
            reason: 'Should end due to silence timeout');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Should not be listening after timeout');
        expect(capturedText.isEmpty, isTrue,
            reason: 'Should have no captured text');

        print('✅ No speech detected test completed');
        print('📊 Captured text: "$capturedText"');
      });

      test('should handle background noise scenario', () async {
        print('🧪 Testing background noise scenario...');

        await voiceSearchService.initialize();

        bool listeningStarted = false;
        bool listeningEnded = false;
        List<String> capturedResults = [];
        String errorText = '';

        final success = await voiceSearchService.startListening(
          silenceTimeout: const Duration(seconds: 4),
          maxListeningDuration: const Duration(seconds: 12),
          onListeningStart: () {
            listeningStarted = true;
            print('🎤 Background noise test started');
          },
          onListeningEnd: () {
            listeningEnded = true;
            print('🔇 Background noise test ended');
          },
          onResult: (result) {
            capturedResults.add(result);
            print('📝 Background noise result: $result');
          },
          onError: (error) {
            errorText = error;
            print('❌ Background noise error: $error');
          },
        );

        expect(success, isTrue, reason: 'Should start listening despite noise');
        expect(listeningStarted, isTrue, reason: 'Should start listening');

        // Simulate background noise scenario
        print('🔊 Simulating background noise...');
        await Future.delayed(const Duration(seconds: 6));

        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue, reason: 'Should end listening');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Should not be listening after stop');

        print('✅ Background noise test completed');
        print('📊 Captured results: ${capturedResults.length}');
        print('📊 Error text: "$errorText"');
      });

      test('should prevent premature cut-off while speaking', () async {
        print('🧪 Testing premature cut-off prevention...');

        await voiceSearchService.initialize();

        bool listeningStarted = false;
        bool listeningEnded = false;
        List<String> capturedResults = [];
        DateTime? startTime;
        DateTime? lastResultTime;

        final success = await voiceSearchService.startListening(
          silenceTimeout:
              const Duration(seconds: 4), // Reasonable silence timeout
          maxListeningDuration:
              const Duration(seconds: 20), // Longer max duration
          onListeningStart: () {
            listeningStarted = true;
            startTime = DateTime.now();
            print('🎤 Cut-off prevention test started');
          },
          onListeningEnd: () {
            listeningEnded = true;
            print('🔇 Cut-off prevention test ended');
          },
          onResult: (result) {
            capturedResults.add(result);
            lastResultTime = DateTime.now();
            print('📝 Cut-off result: $result');
          },
        );

        expect(success, isTrue, reason: 'Should start listening');
        expect(listeningStarted, isTrue, reason: 'Should start listening');

        // Simulate continuous speech with short pauses
        print('🗣️ Simulating continuous speech...');
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(seconds: 2));
          print('📝 Simulated speech segment $i');
        }

        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue,
            reason: 'Should end listening when stopped');
        expect(capturedResults.isNotEmpty, isTrue,
            reason: 'Should capture continuous speech');

        if (startTime != null && lastResultTime != null) {
          final duration = lastResultTime!.difference(startTime!);
          print('⏱️ Continuous speech duration: ${duration.inSeconds}s');
          expect(duration.inSeconds, greaterThan(4),
              reason: 'Should handle continuous speech');
        }

        print('✅ Premature cut-off prevention test completed');
        print('📊 Captured results: ${capturedResults.length}');
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle rapid start/stop cycles', () async {
        print('🧪 Testing rapid start/stop cycles...');

        await voiceSearchService.initialize();

        for (int i = 0; i < 3; i++) {
          print('🔄 Cycle ${i + 1}');

          bool listeningStarted = false;
          bool listeningEnded = false;

          final success = await voiceSearchService.startListening(
            onListeningStart: () => listeningStarted = true,
            onListeningEnd: () => listeningEnded = true,
          );

          expect(success, isTrue,
              reason: 'Cycle ${i + 1} should start successfully');
          expect(listeningStarted, isTrue,
              reason: 'Cycle ${i + 1} should start callback');

          // Listen briefly
          await Future.delayed(const Duration(milliseconds: 500));

          // Stop listening
          await voiceSearchService.stopListening();

          expect(listeningEnded, isTrue,
              reason: 'Cycle ${i + 1} should end callback');
          expect(voiceSearchService.isListening, isFalse,
              reason: 'Cycle ${i + 1} should not be listening');

          print('✅ Cycle ${i + 1} completed');
        }

        print('✅ Rapid start/stop cycles test completed');
      });

      test('should handle multiple concurrent requests', () async {
        print('🧪 Testing multiple concurrent requests...');

        await voiceSearchService.initialize();

        bool firstListeningStarted = false;
        bool secondListeningStarted = false;
        bool listeningEnded = false;

        // Start first listening session
        final firstSuccess = await voiceSearchService.startListening(
          onListeningStart: () => firstListeningStarted = true,
          onListeningEnd: () => listeningEnded = true,
        );

        expect(firstSuccess, isTrue, reason: 'First session should start');
        expect(firstListeningStarted, isTrue,
            reason: 'First session should start callback');
        expect(voiceSearchService.isListening, isTrue,
            reason: 'Should be listening');

        // Try to start second session while first is active
        final secondSuccess = await voiceSearchService.startListening();

        // Should handle gracefully (either stop first and start second, or fail gracefully)
        print('📊 Second session result: $secondSuccess');

        // Clean up
        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue, reason: 'Should end listening');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Should not be listening after stop');

        print('✅ Multiple concurrent requests test completed');
      });

      test('should handle service disposal and recreation', () async {
        print('🧪 Testing service disposal and recreation...');

        // Initialize and use service
        await voiceSearchService.initialize();
        expect(voiceSearchService.isInitialized, isTrue,
            reason: 'Should initialize initially');

        final success = await voiceSearchService.startListening();
        expect(success, isTrue, reason: 'Should start listening');
        expect(voiceSearchService.isListening, isTrue,
            reason: 'Should be listening');

        // Dispose service
        voiceSearchService.dispose();
        expect(voiceSearchService.isInitialized, isFalse,
            reason: 'Should not be initialized after disposal');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Should not be listening after disposal');

        // Create new service instance
        final newService = VoiceSearchService();
        await newService.initialize();
        expect(newService.isInitialized, isTrue,
            reason: 'New service should initialize');

        final newSuccess = await newService.startListening();
        expect(newSuccess, isTrue,
            reason: 'New service should start listening');
        expect(newService.isListening, isTrue,
            reason: 'New service should be listening');

        // Clean up
        newService.dispose();

        print('✅ Service disposal and recreation test completed');
      });
    });

    group('Performance and Reliability', () {
      test('should maintain consistent performance across sessions', () async {
        print('🧪 Testing consistent performance...');

        await voiceSearchService.initialize();

        final List<Duration> sessionDurations = [];
        final List<int> resultCounts = [];

        for (int i = 0; i < 3; i++) {
          print('🔄 Performance session ${i + 1}');

          final stopwatch = Stopwatch()..start();
          List<String> sessionResults = [];

          await voiceSearchService.startListening(
            onResult: (result) => sessionResults.add(result),
          );

          // Listen for a consistent duration
          await Future.delayed(const Duration(seconds: 2));

          await voiceSearchService.stopListening();

          stopwatch.stop();
          sessionDurations.add(stopwatch.elapsed);
          resultCounts.add(sessionResults.length);

          print(
              '📊 Session ${i + 1}: ${stopwatch.elapsedMilliseconds}ms, ${sessionResults.length} results');
        }

        // Check consistency (variations should be within reasonable bounds)
        final avgDuration = sessionDurations.reduce((a, b) => a + b)
            // / sessionDurations.length
            ;
        final avgResults =
            resultCounts.reduce((a, b) => a + b) / resultCounts.length;

        print('📊 Average duration: ${avgDuration.inMilliseconds}ms');
        print('📊 Average results: $avgResults');

        // Performance should be consistent (within 50% of average)
        for (int i = 0; i < sessionDurations.length; i++) {
          final variance = (sessionDurations[i] - avgDuration).abs();
          final maxVariance = Duration(
              milliseconds: (avgDuration.inMilliseconds * 0.5).round());
          expect(variance.inMilliseconds, lessThan(maxVariance.inMilliseconds),
              reason: 'Session ${i + 1} duration should be consistent');
        }

        print('✅ Consistent performance test completed');
      });

      test('should handle long-duration listening sessions', () async {
        print('🧪 Testing long-duration listening...');

        await voiceSearchService.initialize();

        bool listeningStarted = false;
        bool listeningEnded = false;
        List<String> longSessionResults = [];
        DateTime? startTime;
        DateTime? endTime;

        final success = await voiceSearchService.startListening(
          maxListeningDuration: const Duration(seconds: 15), // Long duration
          onListeningStart: () {
            listeningStarted = true;
            startTime = DateTime.now();
            print('🎤 Long-duration session started');
          },
          onListeningEnd: () {
            listeningEnded = true;
            endTime = DateTime.now();
            print('🔇 Long-duration session ended');
          },
          onResult: (result) => longSessionResults.add(result),
        );

        expect(success, isTrue, reason: 'Should start long-duration session');
        expect(listeningStarted, isTrue, reason: 'Should start listening');

        // Let it run for a while
        print('⏳ Running long-duration session...');
        await Future.delayed(const Duration(seconds: 12));

        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue,
            reason: 'Should end long-duration session');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Should not be listening after stop');

        if (startTime != null && endTime != null) {
          final duration = endTime!.difference(startTime!);
          print('⏱️ Long session duration: ${duration.inSeconds}s');
          expect(duration.inSeconds, greaterThan(10),
              reason: 'Should handle long duration');
        }

        print('✅ Long-duration listening test completed');
        print('📊 Long session results: ${longSessionResults.length}');
      });
    });
  });

  group('Enhanced Voice Search Integration Tests', () {
    test('should handle complete voice search pipeline with enhanced features',
        () async {
      print('🧪 Testing complete enhanced voice search pipeline...');

      final voiceSearchService = VoiceSearchService();

      try {
        await voiceSearchService.initialize();

        bool pipelineCompleted = false;
        String finalText = '';
        List<String> intermediateResults = [];
        DateTime? pipelineStart;
        DateTime? pipelineEnd;

        final success = await voiceSearchService.startListening(
          silenceTimeout: const Duration(seconds: 3),
          maxListeningDuration: const Duration(seconds: 10),
          onListeningStart: () {
            pipelineStart = DateTime.now();
            print('🎤 Enhanced pipeline started');
          },
          onResult: (result) {
            intermediateResults.add(result);
            print('📝 Enhanced pipeline result: $result');
          },
          onListeningEnd: () {
            pipelineEnd = DateTime.now();
            finalText = voiceSearchService.lastWords;
            pipelineCompleted = true;
            print('🔇 Enhanced pipeline completed with text: $finalText');
          },
        );

        expect(success, isTrue,
            reason: 'Enhanced pipeline should start successfully');

        // Wait for pipeline to complete
        await Future.delayed(const Duration(seconds: 8));

        // Ensure pipeline completes
        await voiceSearchService.stopListening();

        expect(pipelineCompleted, isTrue,
            reason: 'Enhanced pipeline should complete');
        expect(intermediateResults.isNotEmpty, isTrue,
            reason: 'Should have intermediate results');

        if (pipelineStart != null && pipelineEnd != null) {
          final pipelineDuration = pipelineEnd!.difference(pipelineStart!);
          print(
              '⏱️ Enhanced pipeline duration: ${pipelineDuration.inMilliseconds}ms');
          expect(pipelineDuration.inMilliseconds, lessThan(15000),
              reason: 'Pipeline should complete within 15 seconds');
        }

        print('📊 Enhanced pipeline results:');
        print('   - Intermediate results: ${intermediateResults.length}');
        print('   - Final text: $finalText');
      } finally {
        voiceSearchService.dispose();
      }

      print('✅ Enhanced voice search pipeline test completed');
    });
  });
}
