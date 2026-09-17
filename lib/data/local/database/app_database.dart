import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../domain/entities/message.dart' show ChatRole, MessageStatus;

part 'app_database.g.dart';

@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get systemPromptOverride => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => textEnum<ChatRole>()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => textEnum<MessageStatus>()();
  IntColumn get tokenCount => integer().nullable()();
  IntColumn get generationMs => integer().nullable()();
  RealColumn get tokensPerSecond => real().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingsRow')
class AppSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get ollamaBaseUrl => text().withDefault(const Constant('http://localhost'))();
  IntColumn get ollamaPort => integer().withDefault(const Constant(11434))();
  TextColumn get globalSystemPrompt => text().nullable()();
  TextColumn get defaultOllamaModel => text().nullable()();
  IntColumn get modelKeepAliveMinutes => integer().withDefault(const Constant(20))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Conversations, Messages, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'localai_db'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(appSettingsTable, appSettingsTable.modelKeepAliveMinutes);
          }
          if (from == 3) {
            // Only version 3 databases ever had this column (added and
            // dropped within the same unreleased dev cycle).
            await m.dropColumn(appSettingsTable, 'llama_library_path');
          }
          if (from < 5) {
            // The in-app (on-device) llama.cpp engine has been removed —
            // chat always goes through a remote Ollama server now.
            if (from >= 3) {
              await m.dropColumn(appSettingsTable, 'engine_mode');
              await m.dropColumn(appSettingsTable, 'default_local_model');
            }
          }
        },
      );

  Stream<List<ConversationRow>> watchConversations() {
    return (select(conversations)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<ConversationRow?> getConversation(String id) {
    return (select(conversations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertConversation(ConversationsCompanion entry) {
    return into(conversations).insertOnConflictUpdate(entry);
  }

  Future<void> deleteConversation(String id) async {
    await (delete(messages)..where((t) => t.conversationId.equals(id))).go();
    await (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllConversations() async {
    await delete(messages).go();
    await delete(conversations).go();
  }

  Stream<List<MessageRow>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<MessageRow>> getMessages(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> upsertMessage(MessagesCompanion entry) {
    return into(messages).insertOnConflictUpdate(entry);
  }

  Future<SettingsRow> getSettings() async {
    final existing = await (select(appSettingsTable)..where((t) => t.id.equals(0))).getSingleOrNull();
    if (existing != null) return existing;
    await into(appSettingsTable).insertOnConflictUpdate(const AppSettingsTableCompanion(id: Value(0)));
    return (select(appSettingsTable)..where((t) => t.id.equals(0))).getSingle();
  }

  Stream<SettingsRow> watchSettings() {
    return (select(appSettingsTable)..where((t) => t.id.equals(0)))
        .watchSingleOrNull()
        .asyncMap((row) async => row ?? getSettings());
  }

  Future<void> updateSettings(AppSettingsTableCompanion entry) {
    return (update(appSettingsTable)..where((t) => t.id.equals(0))).write(entry);
  }
}
