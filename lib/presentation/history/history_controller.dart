import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/conversation.dart';

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

class HistoryActions {
  HistoryActions(this._ref);

  final Ref _ref;

  Future<void> rename(String id, String title) =>
      _ref.read(chatRepositoryProvider).renameConversation(id, title);

  Future<void> delete(String id) => _ref.read(chatRepositoryProvider).deleteConversation(id);

  Future<void> deleteAll() => _ref.read(chatRepositoryProvider).deleteAllConversations();
}

final historyActionsProvider = Provider<HistoryActions>((ref) => HistoryActions(ref));
