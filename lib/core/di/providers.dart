import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database/app_database.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/engine/ollama_engine.dart';
import '../../domain/repositories/chat_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(appDatabaseProvider));
});

final dioProvider = Provider<Dio>((ref) => Dio());

final ollamaEngineProvider = Provider<OllamaEngine>((ref) {
  return OllamaEngine(ref.watch(dioProvider));
});
