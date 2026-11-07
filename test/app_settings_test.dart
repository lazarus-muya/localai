import 'package:flutter_test/flutter_test.dart';

import 'package:localai/domain/entities/app_settings.dart';

void main() {
  group('AppSettings', () {
    const base = AppSettings(
      ollamaBaseUrl: 'http://localhost',
      ollamaPort: 11434,
    );

    test('defaults to the remote backend', () {
      expect(base.backend, InferenceBackend.remote);
      expect(base.localContextLength, 4096);
    });

    test('activeDefaultModel follows the active backend', () {
      final settings = base.copyWith(
        defaultOllamaModel: 'llama3.2',
        defaultLocalModel: 'llama-3.2-1b-q4_k_m',
      );

      expect(settings.activeDefaultModel, 'llama3.2');
      expect(
        settings.copyWith(backend: InferenceBackend.onDevice).activeDefaultModel,
        'llama-3.2-1b-q4_k_m',
      );
    });

    test('copyWith preserves unspecified fields', () {
      final updated = base.copyWith(backend: InferenceBackend.onDevice);
      expect(updated.ollamaBaseUrl, 'http://localhost');
      expect(updated.ollamaPort, 11434);
      expect(updated.backend, InferenceBackend.onDevice);
    });

    test('ollamaServerUrl joins the base URL and port', () {
      expect(base.ollamaServerUrl, 'http://localhost:11434');
    });
  });
}
