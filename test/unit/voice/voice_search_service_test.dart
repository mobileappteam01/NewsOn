@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:newson/core/services/voice_search_service.dart';

import 'fake_speech_recognition_engine.dart';
import '../../test_setup.dart';

void main() {
  ensureTestBinding();

  group('VoiceSearchService with FakeSpeechRecognitionEngine', () {
    late FakeSpeechRecognitionEngine engine;
    late VoiceSearchService service;

    setUp(() {
      engine = FakeSpeechRecognitionEngine();
      service = VoiceSearchService.withEngine(engine);
    });

    tearDown(() {
      service.dispose();
      VoiceSearchService.debugOverrideInstance(null);
    });

    test('initialize succeeds without native plugin', () async {
      final ok = await service.initialize();
      expect(ok, isTrue);
      expect(service.isInitialized, isTrue);
      expect(engine.initializeCalls, 1);
    });

    test('initialize failure surfaces error', () async {
      engine.initializeSucceeds = false;
      final ok = await service.initialize();
      expect(ok, isFalse);
      expect(service.isInitialized, isFalse);
      expect(service.errorText, isNotEmpty);
    });

    test('start/stop listening state transitions', () async {
      await service.initialize();
      final started = await service.startListening(
        maxListeningDuration: const Duration(seconds: 5),
        silenceTimeout: const Duration(seconds: 2),
      );
      expect(started, isTrue);
      expect(service.isListening, isTrue);
      expect(engine.listenCalls, 1);

      engine.emitResult('hello world', isFinal: false);
      expect(service.lastWords, 'hello world');
      expect(service.isListening, isTrue);

      engine.emitResult('hello world final', isFinal: true);
      expect(service.lastWords, 'hello world final');
      expect(service.isListening, isFalse);

      await service.stopListening();
      // Already stopped via final result — stop is a no-op path.
    });

    test('stopListening calls engine.stop when listening', () async {
      await service.initialize();
      await service.startListening(
        maxListeningDuration: const Duration(seconds: 5),
      );
      expect(service.isListening, isTrue);
      await service.stopListening();
      expect(engine.stopCalls, 1);
      expect(service.isListening, isFalse);
    });

    test('cancelListening calls engine.cancel', () async {
      await service.initialize();
      await service.startListening(
        maxListeningDuration: const Duration(seconds: 5),
      );
      await service.cancelListening();
      expect(engine.cancelCalls, 1);
      expect(service.isListening, isFalse);
    });

    test('language enforcement uses english locale', () async {
      await service.initialize(language: VoiceSearchLanguage.english);
      expect(service.currentLanguage, VoiceSearchLanguage.english);
      final set = await service.setLanguage(VoiceSearchLanguage.english);
      expect(set, isTrue);
    });

    test('rapid session start/stop does not throw', () async {
      await service.initialize();
      for (var i = 0; i < 5; i++) {
        await service.startListening(
          maxListeningDuration: const Duration(seconds: 2),
        );
        engine.emitResult('session $i', isFinal: true);
        await service.stopListening();
      }
      expect(engine.listenCalls, 5);
      expect(service.isListening, isFalse);
    });

    test('error callback on start when language set fails empty locales',
        () async {
      engine.availableLocales = const [];
      await service.initialize();
      // setLanguage still succeeds via fallback SpeechLocaleInfo
      final ok = await service.setLanguage(VoiceSearchLanguage.english);
      expect(ok, isTrue);
    });
  });
}
