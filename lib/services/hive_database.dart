import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class HiveDatabase {
  static late Box<dynamic> conversationBox;
  static late Box<dynamic> preferenceBox;
  static bool _initialized = false;

  static const String conversationBoxName = 'conversations';
  static const String preferenceBoxName = 'preferences';

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🗄️ Initializing Hive database...');

      // Initialize Hive
      await Hive.initFlutter();

      // Open boxes
      conversationBox = await Hive.openBox(conversationBoxName);
      preferenceBox = await Hive.openBox(preferenceBoxName);

      _initialized = true;
      debugPrint('✅ Hive database initialized');
    } catch (e) {
      debugPrint('❌ Hive init error: $e');
      rethrow;
    }
  }

  // Conversations
  static Future<void> saveConversation({
    required String userMessage,
    required String aiResponse,
    String? mood,
    String? sessionId,
    bool? isOffline,
    double? sentimentScore,
  }) async {
    try {
      final conversation = {
        'timestamp': DateTime.now().toIso8601String(),
        'userMessage': userMessage,
        'aiResponse': aiResponse,
        'mood': mood ?? 'neutral',
        'sessionId': sessionId,
        'isOffline': isOffline ?? true,
        'sentimentScore': sentimentScore,
      };

      await conversationBox.add(conversation);
      debugPrint('✅ Conversation saved');
    } catch (e) {
      debugPrint('❌ Save error: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      final conversations = <Map<String, dynamic>>[];
      for (var i = 0; i < conversationBox.length; i++) {
        final conv = conversationBox.getAt(i);
        if (conv is Map) {
          conversations.add(Map<String, dynamic>.from(conv));
        }
      }
      conversations.sort((a, b) {
        final timeA = DateTime.parse(a['timestamp'] as String);
        final timeB = DateTime.parse(b['timestamp'] as String);
        return timeB.compareTo(timeA);
      });
      return conversations;
    } catch (e) {
      debugPrint('❌ Get conversations error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentConversations({int limit = 100}) async {
    try {
      final allConversations = await getAllConversations();
      return allConversations.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Get recent conversations error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchConversations(String query) async {
    try {
      if (query.trim().isEmpty) return await getAllConversations();

      final lowercaseQuery = query.toLowerCase();
      final allConversations = await getAllConversations();
      return allConversations
          .where((conv) =>
            ((conv['userMessage'] as String?)?.toLowerCase().contains(lowercaseQuery) ?? false) ||
            ((conv['aiResponse'] as String?)?.toLowerCase().contains(lowercaseQuery) ?? false))
          .toList();
    } catch (e) {
      debugPrint('❌ Search error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getConversationsByMood(String mood) async {
    try {
      final allConversations = await getAllConversations();
      return allConversations
          .where((conv) => (conv['mood'] as String?) == mood)
          .toList();
    } catch (e) {
      debugPrint('❌ Get by mood error: $e');
      return [];
    }
  }

  static Future<void> deleteAllConversations() async {
    try {
      await conversationBox.clear();
      debugPrint('✅ All conversations deleted');
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      rethrow;
    }
  }

  static Future<void> deleteConversationById(int id) async {
    try {
      await conversationBox.deleteAt(id);
      debugPrint('✅ Conversation $id deleted');
    } catch (e) {
      debugPrint('❌ Delete by id error: $e');
    }
  }

  static Future<void> deleteOldConversations({required DateTime olderThan}) async {
    try {
      final keysToDelete = <int>[];
      for (var i = 0; i < conversationBox.length; i++) {
        final conv = conversationBox.getAt(i);
        if (conv is Map) {
          final timestamp = DateTime.tryParse(conv['timestamp'] as String? ?? '');
          if (timestamp != null && timestamp.isBefore(olderThan)) {
            keysToDelete.add(i);
          }
        }
      }

      for (final key in keysToDelete.reversed) {
        await conversationBox.deleteAt(key);
      }
      debugPrint('✅ Old conversations deleted');
    } catch (e) {
      debugPrint('❌ Delete old error: $e');
    }
  }

  static Future<Map<String, dynamic>> getConversationStats() async {
    try {
      final conversations = await getAllConversations();
      final moodCounts = <String, int>{};
      int crisisCount = 0;

      for (final conv in conversations) {
        final mood = (conv['mood'] as String?) ?? 'neutral';
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;

        if (_detectCrisis(conv['userMessage'] as String? ?? '')) {
          crisisCount++;
        }
      }

      return {
        'total': conversations.length,
        'moodDistribution': moodCounts,
        'crisisConversations': crisisCount,
      };
    } catch (e) {
      debugPrint('❌ Get stats error: $e');
      return {
        'total': 0,
        'moodDistribution': <String, int>{},
        'crisisConversations': 0,
      };
    }
  }

  static bool _detectCrisis(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'suicidal', 'kill myself', 'end it all', 'want to die',
      'harm myself', 'hurt myself', 'can\'t go on', 'cannot go on',
      'no point living', 'better off dead', 'no reason to live'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }

  // Preferences
  static Future<void> setPreference(String key, String value) async {
    try {
      await preferenceBox.put(key, value);
      debugPrint('✅ Preference saved: $key');
    } catch (e) {
      debugPrint('❌ Preference save error: $e');
      rethrow;
    }
  }

  static Future<String?> getPreference(String key) async {
    try {
      final value = preferenceBox.get(key);
      return value is String ? value : null;
    } catch (e) {
      debugPrint('❌ Preference get error: $e');
      return null;
    }
  }

  static Future<Map<String, String>> getAllPreferences() async {
    try {
      final result = <String, String>{};
      for (final key in preferenceBox.keys) {
        final value = preferenceBox.get(key);
        if (value is String) {
          result[key.toString()] = value;
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ Get all preferences error: $e');
      return {};
    }
  }

  static Future<void> deletePreference(String key) async {
    try {
      await preferenceBox.delete(key);
      debugPrint('✅ Preference deleted: $key');
    } catch (e) {
      debugPrint('❌ Preference delete error: $e');
    }
  }

  static int getConversationCount() {
    return conversationBox.length;
  }

  static Future<void> close() async {
    try {
      await Hive.close();
      _initialized = false;
      debugPrint('✅ Hive closed');
    } catch (e) {
      debugPrint('❌ Close error: $e');
    }
  }
}
