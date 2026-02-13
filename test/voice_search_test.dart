import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import '../lib/core/services/voice_search_service.dart';

/// Voice Search Test Suite
/// Tests all scenarios for voice search to text and data filtering
void main() {
  // Initialize Flutter binding for tests
  WidgetsFlutterBinding.ensureInitialized();

  group('Voice Search Tests', () {
    late VoiceSearchService voiceSearchService;

    setUp(() {
      voiceSearchService = VoiceSearchService();
    });

    tearDown(() {
      voiceSearchService.dispose();
    });

    test('should initialize voice search service', () async {
      print('🧪 Testing voice search initialization...');

      final stopwatch = Stopwatch()..start();
      final success = await voiceSearchService.initialize();
      stopwatch.stop();

      expect(success, isTrue,
          reason: 'Voice search should initialize successfully');
      expect(voiceSearchService.isInitialized, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Initialization should complete within 5 seconds');

      print('✅ Voice search initialized in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('should handle voice search lifecycle', () async {
      print('🧪 Testing voice search lifecycle...');

      await voiceSearchService.initialize();

      bool listeningStarted = false;
      bool listeningEnded = false;
      String capturedText = '';
      String errorText = '';

      final success = await voiceSearchService.startListening(
        onListeningStart: () {
          listeningStarted = true;
          print('🎤 Listening started');
        },
        onListeningEnd: () {
          listeningEnded = true;
          print('🔇 Listening ended');
        },
        onResult: (result) {
          capturedText = result;
          print('📝 Voice result: $result');
        },
        onError: (error) {
          errorText = error;
          print('❌ Voice error: $error');
        },
      );

      expect(success, isTrue, reason: 'Should start listening successfully');
      expect(listeningStarted, isTrue,
          reason: 'Listening start callback should be called');
      expect(voiceSearchService.isListening, isTrue,
          reason: 'Should be listening');

      // Wait a moment for listening to establish
      await Future.delayed(const Duration(seconds: 1));

      // Test stopping listening
      await voiceSearchService.stopListening();

      expect(voiceSearchService.isListening, isFalse,
          reason: 'Should not be listening after stop');

      print('✅ Voice search lifecycle test completed');
    });

    test('should handle voice search timeout', () async {
      print('🧪 Testing voice search timeout...');

      await voiceSearchService.initialize();

      bool listeningEnded = false;
      String capturedText = '';

      await voiceSearchService.startListening(
        onListeningEnd: () {
          listeningEnded = true;
          print('🔇 Listening ended (timeout)');
        },
        onResult: (result) {
          capturedText = result;
          print('📝 Voice result: $result');
        },
      );

      expect(voiceSearchService.isListening, isTrue,
          reason: 'Should be listening');

      // Wait for timeout (35 seconds + buffer)
      print('⏳ Waiting for timeout...');
      await Future.delayed(const Duration(seconds: 40));

      expect(listeningEnded, isTrue,
          reason: 'Listening should end due to timeout');
      expect(voiceSearchService.isListening, isFalse,
          reason: 'Should not be listening after timeout');

      print('✅ Voice search timeout test completed');
    });

    test('should handle voice search errors', () async {
      print('🧪 Testing voice search error handling...');

      await voiceSearchService.initialize();

      String errorText = '';
      bool listeningEnded = false;

      // Simulate error by trying to start listening twice
      await voiceSearchService.startListening(
        onError: (error) {
          errorText = error;
          print('❌ Voice error: $error');
        },
        onListeningEnd: () {
          listeningEnded = true;
          print('🔇 Listening ended');
        },
      );

      // Try to start again while already listening
      final secondSuccess = await voiceSearchService.startListening(
        onError: (error) {
          errorText = error;
          print('❌ Second attempt error: $error');
        },
      );

      // Should handle gracefully (either succeed with stop first or fail gracefully)
      print('📊 Second start result: $secondSuccess');
      print('📊 Error text: $errorText');

      // Clean up
      await voiceSearchService.stopListening();

      print('✅ Voice search error handling test completed');
    });

    test('should handle voice search text capture', () async {
      print('🧪 Testing voice search text capture...');

      await voiceSearchService.initialize();

      List<String> capturedResults = [];
      bool listeningEnded = false;

      final success = await voiceSearchService.startListening(
        onResult: (result) {
          capturedResults.add(result);
          print('📝 Captured result: $result');
        },
        onListeningEnd: () {
          listeningEnded = true;
          print('🔇 Listening ended');
        },
      );

      expect(success, isTrue, reason: 'Should start listening successfully');
      expect(voiceSearchService.isListening, isTrue,
          reason: 'Should be listening');

      // Wait for some results or timeout
      await Future.delayed(const Duration(seconds: 5));

      // Stop listening manually
      await voiceSearchService.stopListening();

      expect(listeningEnded, isTrue,
          reason: 'Listening should end when stopped');
      expect(voiceSearchService.isListening, isFalse,
          reason: 'Should not be listening after stop');
      expect(voiceSearchService.lastWords, isNotEmpty,
          reason: 'Should have some captured text');

      print('📊 Total captured results: ${capturedResults.length}');
      print('📊 Final text: ${voiceSearchService.lastWords}');

      print('✅ Voice search text capture test completed');
    });

    test('should handle multiple voice search sessions', () async {
      print('🧪 Testing multiple voice search sessions...');

      await voiceSearchService.initialize();

      for (int i = 0; i < 3; i++) {
        print('🔄 Session ${i + 1}');

        bool listeningStarted = false;
        bool listeningEnded = false;
        String capturedText = '';

        final success = await voiceSearchService.startListening(
          onListeningStart: () {
            listeningStarted = true;
          },
          onListeningEnd: () {
            listeningEnded = true;
          },
          onResult: (result) {
            capturedText = result;
          },
        );

        expect(success, isTrue,
            reason: 'Session ${i + 1} should start successfully');
        expect(listeningStarted, isTrue,
            reason: 'Session ${i + 1} should start callback');

        // Listen briefly
        await Future.delayed(const Duration(seconds: 2));

        // Stop listening
        await voiceSearchService.stopListening();

        expect(listeningEnded, isTrue,
            reason: 'Session ${i + 1} should end callback');
        expect(voiceSearchService.isListening, isFalse,
            reason: 'Session ${i + 1} should not be listening');

        print('✅ Session ${i + 1} completed');
      }

      print('✅ Multiple voice search sessions test completed');
    });

    test('should handle voice search state management', () async {
      print('🧪 Testing voice search state management...');

      await voiceSearchService.initialize();

      // Initial state
      expect(voiceSearchService.isListening, isFalse,
          reason: 'Should not be listening initially');
      expect(voiceSearchService.lastWords, isEmpty,
          reason: 'Should have no text initially');
      expect(voiceSearchService.errorText, isEmpty,
          reason: 'Should have no error initially');

      // Start listening
      await voiceSearchService.startListening();
      expect(voiceSearchService.isListening, isTrue,
          reason: 'Should be listening after start');
      expect(voiceSearchService.errorText, isEmpty,
          reason: 'Should have no error after start');

      // Stop listening
      await voiceSearchService.stopListening();
      expect(voiceSearchService.isListening, isFalse,
          reason: 'Should not be listening after stop');

      // Cancel listening
      await voiceSearchService.startListening();
      expect(voiceSearchService.isListening, isTrue,
          reason: 'Should be listening before cancel');

      await voiceSearchService.cancelListening();
      expect(voiceSearchService.isListening, isFalse,
          reason: 'Should not be listening after cancel');
      expect(voiceSearchService.lastWords, isEmpty,
          reason: 'Should have cleared text after cancel');

      print('✅ Voice search state management test completed');
    });
  });

  group('Voice Search Integration Tests', () {
    test('should handle voice search to text pipeline', () async {
      print('🧪 Testing voice search to text pipeline...');

      final voiceSearchService = VoiceSearchService();

      try {
        await voiceSearchService.initialize();

        bool pipelineCompleted = false;
        String finalText = '';
        List<String> intermediateResults = [];

        final success = await voiceSearchService.startListening(
          onResult: (result) {
            intermediateResults.add(result);
            print('📝 Intermediate result: $result');
          },
          onListeningEnd: () {
            finalText = voiceSearchService.lastWords;
            pipelineCompleted = true;
            print('🔇 Pipeline completed with text: $finalText');
          },
        );

        expect(success, isTrue, reason: 'Pipeline should start successfully');

        // Wait for pipeline to complete or timeout
        await Future.delayed(const Duration(seconds: 10));

        // Ensure pipeline completes
        await voiceSearchService.stopListening();

        expect(pipelineCompleted, isTrue, reason: 'Pipeline should complete');
        expect(intermediateResults.isNotEmpty, isTrue,
            reason: 'Should have intermediate results');
        expect(finalText, isNotEmpty, reason: 'Should have final text');

        print('📊 Pipeline results:');
        print('   - Intermediate results: ${intermediateResults.length}');
        print('   - Final text: $finalText');
      } finally {
        voiceSearchService.dispose();
      }

      print('✅ Voice search to text pipeline test completed');
    });
  });
}
