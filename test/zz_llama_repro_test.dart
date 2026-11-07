import 'package:flutter_test/flutter_test.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';

void main() {
  test('load model', () async {
    final repo = LlamaCppChatRepository.withModelPath(
      r'C:\Users\dev.chairman\AppData\Roaming\com.localai\localai\models\meta-llama-3-8b-instruct-healed.q6_k.gguf',
      contextSize: 4096,
      nGpuLayers: 0,
    );
    await for (final c in repo.streamChatWithGenerationOptions('m',
        messages: [LLMMessage(role: LLMRole.user, content: 'Say hi')],
        generationOptions: const GenerationOptions(maxTokens: 16))) {
      print('CHUNK: ${c.message?.content} done=${c.done}');
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
