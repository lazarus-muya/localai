import 'dart:io';

import 'bootstrap.dart';
import 'domain/engine/llama_cpp_engine.dart';
import 'domain/entities/inference_settings.dart';
import 'domain/engine/inference_engine.dart';
import 'domain/entities/message.dart' show ChatRole;

void main() {
  bootstrap();
  if (Platform.environment['LLAMA_REPRO'] == '1') {
    Future.delayed(const Duration(seconds: 3), () async {
      print('REPRO: start');
      try {
        await for (final d in LlamaCppEngine().chatStream(
          baseUrl: '',
          model: 'meta-llama-3-8b-instruct-healed.q6_k',
          messages: const [ChatTurn(role: ChatRole.user, content: 'Say hi')],
          settings: const InferenceSettings(contextLength: 4096),
        )) {
          print(
            'REPRO delta: "${d.contentDelta}" loading=${d.loading} done=${d.done}',
          );
        }
        print('REPRO: finished');
      } catch (e, s) {
        print('REPRO error: $e\n$s');
      }
    });
  }
}
