import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

part 'offline_storage.g.dart';

//Table definitions with indexes completely removed
@DataClassName('Conversation')
class Conversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userMessage => text().named('user_message')();
  TextColumn get aiResponse => text().named('ai_response')();
  TextColumn get emotionalState => text().nullable().named('emotional_state')();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isOffline => boolean().withDefault(const Constant(true)).named('is_offline')();
  TextColumn get sessionId => text().nullable().named('session_id')();
  RealColumn get sentimentScore => real().nullable().named('sentiment_score')();

}

@DataClassName('UserPreference')
class UserPreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get preferenceKey => text().named('preference_key').unique()();
  TextColumn get preferenceValue => text().named('preference_value')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

}

@DataClassName('MoodEntry')
class MoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mood => text()();
  RealColumn get intensity => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();

}

@DriftDatabase(tables: [Conversations, UserPreferences, MoodEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  //  FIXED: Enhanced conversation operations with error handling
  Future<List<Conversation>> getAllConversations() async {
    try {
      return await (select(conversations)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
    } catch (e) {
      debugPrint('Error getting all conversations: $e');
      return [];
    }
  }

  Future<List<Conversation>> getRecentConversations({int limit = 100}) async {
    try {
      return await (select(conversations)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(limit)).get();
    } catch (e) {
      debugPrint('Error getting recent conversations: $e');
      return [];
    }
  }

  Future<int> insertConversation(ConversationsCompanion entry) async {
    try {
      return await into(conversations).insert(entry);
    } catch (e) {
      debugPrint('Error inserting conversation: $e');
      rethrow;
    }
  }

  Future<bool> updateConversation(Conversation entry) async {
    try {
      return await update(conversations).replace(entry);
    } catch (e) {
      debugPrint('Error updating conversation: $e');
      return false;
    }
  }

  Future<int> updateConversationById(int id, ConversationsCompanion entry) async {
    try {
      return await (update(conversations)..where((c) => c.id.equals(id))).write(entry);
    } catch (e) {
      debugPrint('Error updating conversation by ID: $e');
      return 0;
    }
  }

  Future<int> deleteAllConversations() async {
    try {
      return await delete(conversations).go();
    } catch (e) {
      debugPrint('Error deleting all conversations: $e');
      return 0;
    }
  }

  Future<int> deleteConversationById(int id) async {
    try {
      return await (delete(conversations)..where((c) => c.id.equals(id))).go();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return 0;
    }
  }

  Future<int> deleteOldConversations({required DateTime olderThan}) async {
    try {
      return await (delete(conversations)
        ..where((tbl) => tbl.timestamp.isSmallerThanValue(olderThan))).go();
    } catch (e) {
      debugPrint('Error deleting old conversations: $e');
      return 0;
    }
  }

  // FIXED: Search conversations by text content
  Future<List<Conversation>> searchConversations(String query) async {
    try {
      if (query.trim().isEmpty) return await getAllConversations();
      
      final lowercaseQuery = query.toLowerCase();
      return await (select(conversations)
        ..where((tbl) => 
          tbl.userMessage.lower().contains(lowercaseQuery) |
          tbl.aiResponse.lower().contains(lowercaseQuery))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
    } catch (e) {
      debugPrint('Error searching conversations: $e');
      return [];
    }
  }

  //FIXED: Get conversations by mood
  Future<List<Conversation>> getConversationsByMood(String mood) async {
    try {
      return await (select(conversations)
        ..where((tbl) => tbl.emotionalState.equals(mood))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
    } catch (e) {
      debugPrint('Error getting conversations by mood: $e');
      return [];
    }
  }

  // FIXED: Get conversation statistics
  Future<Map<String, dynamic>> getConversationStats() async {
    try {
      final totalQuery = await customSelect(
        'SELECT COUNT(*) as total FROM conversations',
      ).getSingle();
      
      final moodQuery = await customSelect(
        'SELECT emotional_state, COUNT(*) as count FROM conversations WHERE emotional_state IS NOT NULL GROUP BY emotional_state ORDER BY count DESC',
      ).get();

      final crisisQuery = await customSelect(
        '''SELECT COUNT(*) as crisis_count FROM conversations 
           WHERE LOWER(user_message) LIKE '%suicide%' 
           OR LOWER(user_message) LIKE '%kill myself%' 
           OR LOWER(user_message) LIKE '%end it all%'
           OR LOWER(user_message) LIKE '%want to die%' ''',
      ).getSingle();

      return {
        'total': totalQuery.data['total'] as int? ?? 0,
        'moodDistribution': Map.fromEntries(
          moodQuery.map((row) => MapEntry(
            row.data['emotional_state'] as String? ?? 'unknown',
            row.data['count'] as int? ?? 0,
          ))
        ),
        'crisisConversations': crisisQuery.data['crisis_count'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting conversation stats: $e');
      return {
        'total': 0,
        'moodDistribution': <String, int>{},
        'crisisConversations': 0,
      };
    }
  }

  //  User preferences operations with better error handling
  Future<String?> getPreference(String key) async {
    try {
      final query = select(userPreferences)..where((tbl) => tbl.preferenceKey.equals(key));
      final result = await query.getSingleOrNull();
      return result?.preferenceValue;
    } catch (e) {
      debugPrint('Error getting preference $key: $e');
      return null;
    }
  }

  Future<void> setPreference(String key, String value) async {
    try {
      await into(userPreferences).insertOnConflictUpdate(
        UserPreferencesCompanion(
          preferenceKey: Value(key),
          preferenceValue: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      debugPrint('Error setting preference $key: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> getAllPreferences() async {
    try {
      final prefs = await select(userPreferences).get();
      return Map.fromEntries(
        prefs.map((pref) => MapEntry(pref.preferenceKey, pref.preferenceValue))
      );
    } catch (e) {
      debugPrint('Error getting all preferences: $e');
      return {};
    }
  }

  Future<void> deletePreference(String key) async {
    try {
      await (delete(userPreferences)..where((tbl) => tbl.preferenceKey.equals(key))).go();
    } catch (e) {
      debugPrint('Error deleting preference $key: $e');
    }
  }

  // Mood operations with better functionality
  Future<List<MoodEntry>> getMoodHistory({int limit = 30}) async {
    try {
      return await (select(moodEntries)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(limit)).get();
    } catch (e) {
      debugPrint('Error getting mood history: $e');
      return [];
    }
  }

  Future<int> insertMoodEntry(MoodEntriesCompanion entry) async {
    try {
      return await into(moodEntries).insert(entry);
    } catch (e) {
      debugPrint('Error inserting mood entry: $e');
      rethrow;
    }
  }

  Future<List<MoodEntry>> getMoodsByDate({required DateTime date}) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      return await (select(moodEntries)
        ..where((tbl) => tbl.timestamp.isBetweenValues(startOfDay, endOfDay))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
    } catch (e) {
      debugPrint('Error getting moods by date: $e');
      return [];
    }
  }

  Future<Map<String, int>> getMoodSummary({int days = 7}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final query = await customSelect(
        'SELECT mood, COUNT(*) as count FROM mood_entries WHERE timestamp > ? GROUP BY mood ORDER BY count DESC',
        variables: [Variable.withDateTime(since)]
      ).get();

      return Map.fromEntries(
        query.map((row) => MapEntry(
          row.data['mood'] as String? ?? 'unknown',
          row.data['count'] as int? ?? 0,
        ))
      );
    } catch (e) {
      debugPrint('Error getting mood summary: $e');
      return {};
    }
  }

  // Database maintenance operations
  Future<void> vacuum() async {
    try {
      await customStatement('VACUUM');
      debugPrint('Database vacuum completed');
    } catch (e) {
      debugPrint('Error vacuuming database: $e');
    }
  }

  Future<int> getDatabaseSize() async {
    try {
      final result = await customSelect('PRAGMA page_count').getSingle();
      final pageCount = result.data['page_count'] as int? ?? 0;
      return pageCount * 4096; // Approximate size in bytes (4KB per page)
    } catch (e) {
      debugPrint('Error getting database size: $e');
      return 0;
    }
  }

  // Batch operations for better performance
  Future<void> insertMultipleConversations(List<ConversationsCompanion> conversations) async {
    try {
      await batch((batch) {
        batch.insertAll(this.conversations, conversations);
      });
    } catch (e) {
      debugPrint('Error inserting multiple conversations: $e');
      rethrow;
    }
  }

  // Export/Import functionality
  Future<List<Map<String, dynamic>>> exportConversations() async {
    try {
      final conversations = await getAllConversations();
      return conversations.map((conv) => {
        'userMessage': conv.userMessage,
        'aiResponse': conv.aiResponse,
        'emotionalState': conv.emotionalState,
        'timestamp': conv.timestamp.toIso8601String(),
        'isOffline': conv.isOffline,
        'sessionId': conv.sessionId,
        'sentimentScore': conv.sentimentScore,
      }).toList();
    } catch (e) {
      debugPrint('Error exporting conversations: $e');
      return [];
    }
  }
}

// Database connection with proper error handling
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      // Use app documents directory for database storage
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'vent_ai.db'));
      
      debugPrint('Database path: ${file.path}');
      
      // Ensure directory exists
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      
      return NativeDatabase(file);
    } catch (e) {
      debugPrint('Error opening database connection: $e');
      rethrow;
    }
  });
}

// Database initialization helper
Future<AppDatabase> initializeDatabase() async {
  try {
    final database = AppDatabase();
    
    // Run a simple query to ensure database is working
    await database.customSelect('SELECT 1').getSingle();
    debugPrint('Database initialized successfully');
    
    return database;
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    rethrow;
  }
}
