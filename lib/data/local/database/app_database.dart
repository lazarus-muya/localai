import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../domain/entities/app_settings.dart' show InferenceBackend;
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
  TextColumn get defaultTtsVoice => text().nullable()();

  /// Active backend: `onDevice` (embedded llama.cpp) or `remote` (Ollama).
  TextColumn get engineBackend => textEnum<InferenceBackend>()
      .withDefault(const Constant('remote'))();

  /// Default model for the on-device engine (GGUF filename).
  TextColumn get defaultLocalModel => text().nullable()();

  /// Context window (tokens) for the on-device engine.
  IntColumn get localContextLength => integer().withDefault(const Constant(4096))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Conversations, Messages, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'localai_db'));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Every step below is guarded by an existence check so the upgrade
          // is idempotent. A previous build could have applied a step without
          // the schema version being persisted (crash/interrupt mid-upgrade,
          // a version bumped after the column was already added), which would
          // otherwise re-run `ADD COLUMN` on a column that already exists and
          // abort the whole migration with "duplicate column name".
          Future<void> addColumnIfMissing(GeneratedColumn column) async {
            if (await _hasColumn(appSettingsTable.actualTableName, column.name)) {
              return;
            }
            await m.addColumn(appSettingsTable, column);
          }

          Future<void> dropColumnIfPresent(String name) async {
            if (await _hasColumn(appSettingsTable.actualTableName, name)) {
              await m.dropColumn(appSettingsTable, name);
            }
          }

          if (from < 2) {
            await addColumnIfMissing(appSettingsTable.modelKeepAliveMinutes);
          }
          if (from == 3) {
            // Only version 3 databases ever had this column (added and
            // dropped within the same unreleased dev cycle).
            await dropColumnIfPresent('llama_library_path');
          }
          if (from < 5) {
            // The in-app (on-device) llama.cpp engine had been removed. Older
            // databases from that era may still carry these columns.
            if (from >= 3) {
              await dropColumnIfPresent('engine_mode');
              await dropColumnIfPresent('default_local_model');
            }
          }
          if (from < 6) {
            await addColumnIfMissing(appSettingsTable.defaultTtsVoice);
          }
          if (from < 7) {
            // Re-introduce a real on-device backend alongside the remote
            // Ollama one. `default_local_model` may have been dropped in v5,
            // so re-add it plus the new backend/context columns.
            await addColumnIfMissing(appSettingsTable.engineBackend);
            await addColumnIfMissing(appSettingsTable.defaultLocalModel);
            await addColumnIfMissing(appSettingsTable.localContextLength);
          }
        },
      );

  /// Whether [table] already has a column named [column], per SQLite's
  /// `PRAGMA table_info`. Used to make migration steps idempotent.
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table);').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

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
