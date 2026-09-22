import 'package:flutter_test/flutter_test.dart';

import 'package:localai/presentation/chat/chat_controller.dart';

void main() {
  group('titleFromPrompt', () {
    test('uses the first non-empty line', () {
      expect(titleFromPrompt('Hello model'), 'Hello model');
    });

    test('falls back to New chat when the prompt is blank', () {
      expect(titleFromPrompt('   \n\t'), 'New chat');
    });

    test('truncates long prompts at a word boundary', () {
      final long = List.filled(20, 'word').join(' ');
      final title = titleFromPrompt(long);
      expect(title.length, lessThanOrEqualTo(49));
      expect(title, endsWith('…'));
    });
  });
}