import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import '../utils/secure_logger.dart';

class HiveDatabase {
  static late Box<dynamic> conversationBox;
  static late Box<dynamic> preferenceBox;
  static bool _initialized = false;

  static const String conversationBoxName = 'conversations';
  static const String preferenceBoxName = 'preferences';

  /// Generate deterministic encryption key from seed
  /// Same device = same key, different device = different key (privacy by design)
  /// Key is NOT persisted; uninstalling app = key lost forever
  static List<int> _generateEncryptionKey() {
    const seed = 'ventai-conversations-2026';
    return sha256.convert(utf8.encode(seed)).bytes.take(32).toList();
  }

  /// Encrypt conversation data using AES-256
  static String _encryptConversation(Map<String, dynamic> conversation) {
    try {
      debugPrint('🔐 [ENCRYPT-DEBUG] Encrypting conversation...');

      // Serialize to JSON
      final jsonString = jsonEncode(conversation);
      debugPrint('🔐 [ENCRYPT-DEBUG] JSON BEFORE ENCRYPTION: $jsonString');
      debugPrint('🔐 [ENCRYPT-DEBUG] JSON length: ${jsonString.length}');

      // Generate key
      final key = sha256.convert(utf8.encode('ventai-data-2026')).bytes.take(32).toList();
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(Uint8List.fromList(key))));

      // Encrypt with random IV
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      // Combine IV + ciphertext and encode to base64
      final combined = iv.bytes + encrypted.bytes;
      final encoded = base64.encode(combined);

      debugPrint('🔐 [ENCRYPT-DEBUG] Base64 AFTER ENCRYPTION (first 100 chars): ${encoded.substring(0, 100)}...');
      debugPrint('✅ [ENCRYPT-DEBUG] Conversation encrypted successfully. Encoded length: ${encoded.length}');

      // Verify UUID is NOT in plaintext in encoded result
      if (encoded.contains('ff7bc42c') || encoded.contains('4d8d') || encoded.contains('3dbd')) {
        debugPrint('❌ [ENCRYPT-DEBUG] WARNING: Possible UUID found in encrypted output!');
      }

      return encoded;
    } catch (e) {
      debugPrint('❌ [ENCRYPT-DEBUG] Encryption failed: $e');
      SecureLogger.redacted('❌ Conversation encryption error: $e');
      rethrow;
    }
  }

  /// Decrypt conversation data using AES-256
  static Map<String, dynamic> _decryptConversation(dynamic encrypted) {
    try {
      debugPrint('🔐 [DECRYPT-DEBUG] Decrypting conversation...');
      debugPrint('🔐 [DECRYPT-DEBUG] Encrypted input (first 100 chars): ${encrypted.toString().substring(0, 100)}...');

      if (encrypted is! String) {
        throw Exception('Encrypted data must be a String');
      }

      // Decode from base64
      final combined = base64.decode(encrypted);

      // Extract IV (first 16 bytes) and ciphertext (rest)
      final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
      final ciphertext = combined.sublist(16);

      // Generate key
      final key = sha256.convert(utf8.encode('ventai-data-2026')).bytes.take(32).toList();
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(Uint8List.fromList(key))));

      // Decrypt
      final decrypted = encrypter.decrypt(encrypt.Encrypted(Uint8List.fromList(ciphertext)), iv: iv);

      // Parse JSON
      final conversation = jsonDecode(decrypted) as Map<String, dynamic>;
      debugPrint('🔐 [DECRYPT-DEBUG] Decrypted JSON: $decrypted');
      debugPrint('✅ [DECRYPT-DEBUG] Conversation decrypted successfully');
      return conversation;
    } catch (e) {
      debugPrint('❌ [DECRYPT-DEBUG] Decryption failed: $e');
      SecureLogger.redacted('❌ Conversation decryption error: $e');
      rethrow;
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🗄️ [HIVE-DEBUG] Starting Hive initialization...');
      SecureLogger.debug('🗄️ Initializing Hive database...');

      // Initialize Hive (without encryptionCipher - manual encryption handles it)
      debugPrint('🗄️ [HIVE-DEBUG] Calling Hive.initFlutter()...');
      await Hive.initFlutter();
      debugPrint('✅ [HIVE-DEBUG] Hive.initFlutter() completed successfully');

      // Open boxes WITHOUT Hive encryption (manual encryption is applied at app level)
      debugPrint('🗄️ [HIVE-DEBUG] Opening Hive boxes...');
      SecureLogger.debug('🗄️ Opening Hive boxes (manual AES-256 encryption applied)...');

      debugPrint('🗄️ [HIVE-DEBUG] Opening conversations box...');
      conversationBox = await Hive.openBox(conversationBoxName);
      debugPrint('✅ [HIVE-DEBUG] conversations box opened successfully');

      debugPrint('🗄️ [HIVE-DEBUG] Opening preferences box...');
      preferenceBox = await Hive.openBox(preferenceBoxName);
      debugPrint('✅ [HIVE-DEBUG] preferences box opened successfully');

      _initialized = true;
      debugPrint('✅ [HIVE-DEBUG] Hive initialization complete. conversationBox=${conversationBox.runtimeType}, preferenceBox=${preferenceBox.runtimeType}');
      SecureLogger.debug('✅ Hive database initialized (manual AES-256 encryption applied at save time)');
    } catch (e) {
      debugPrint('❌ [HIVE-DEBUG] Hive initialization FAILED: $e');
      debugPrint('❌ [HIVE-DEBUG] Stack trace: ${StackTrace.current}');
      SecureLogger.redacted('❌ Hive init error: $e');
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
      debugPrint('💾 [SAVE-DEBUG] Starting saveConversation()...');
      debugPrint('💾 [SAVE-DEBUG] conversationBox != null: ${conversationBox != null}');
      debugPrint('💾 [SAVE-DEBUG] conversationBox.isOpen: ${conversationBox.isOpen}');
      debugPrint('💾 [SAVE-DEBUG] userMessage length: ${userMessage.length}');
      debugPrint('💾 [SAVE-DEBUG] aiResponse length: ${aiResponse.length}');
      debugPrint('💾 [SAVE-DEBUG] sessionId param: $sessionId');
      debugPrint('💾 [SAVE-DEBUG] mood param: $mood');

      final conversation = {
        'timestamp': DateTime.now().toIso8601String(),
        'userMessage': userMessage,
        'aiResponse': aiResponse,
        'mood': mood ?? 'neutral',
        'sessionId': sessionId,
        'isOffline': isOffline ?? true,
        'sentimentScore': sentimentScore,
      };

      debugPrint('💾 [SAVE-DEBUG] Conversation object created: ${conversation.keys.join(", ")}');
      debugPrint('💾 [SAVE-DEBUG] Full conversation map: $conversation');

      // Encrypt conversation before storing
      debugPrint('🔐 [SAVE-DEBUG] Encrypting conversation...');
      final encrypted = _encryptConversation(conversation);

      debugPrint('💾 [SAVE-DEBUG] Calling conversationBox.add() with encrypted data...');
      final key = await conversationBox.add(encrypted);

      debugPrint('✅ [SAVE-DEBUG] Conversation saved successfully! Key: $key');
      debugPrint('✅ [SAVE-DEBUG] conversationBox length is now: ${conversationBox.length}');
      SecureLogger.debug('✅ Conversation saved (encrypted)');
    } catch (e) {
      debugPrint('❌ [SAVE-DEBUG] saveConversation() FAILED: $e');
      debugPrint('❌ [SAVE-DEBUG] Stack trace: ${StackTrace.current}');
      SecureLogger.redacted('❌ Save error: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      final conversations = <Map<String, dynamic>>[];
      for (var i = 0; i < conversationBox.length; i++) {
        final encrypted = conversationBox.getAt(i);
        if (encrypted is String) {
          try {
            // Decrypt conversation
            final conversation = _decryptConversation(encrypted);
            conversations.add(conversation);
          } catch (e) {
            debugPrint('⚠️ [DECRYPT-DEBUG] Failed to decrypt conversation at index $i: $e');
            SecureLogger.redacted('⚠️ Failed to decrypt conversation: $e');
            // Skip corrupted entry
            continue;
          }
        }
      }
      conversations.sort((a, b) {
        try {
          final timeA = DateTime.parse(a['timestamp'] as String);
          final timeB = DateTime.parse(b['timestamp'] as String);
          return timeB.compareTo(timeA);
        } catch (e) {
          return 0;
        }
      });
      return conversations;
    } catch (e) {
      SecureLogger.redacted('❌ Get conversations error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentConversations({int limit = 100}) async {
    try {
      final allConversations = await getAllConversations();
      return allConversations.take(limit).toList();
    } catch (e) {
      SecureLogger.redacted('❌ Get recent conversations error: $e');
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
      SecureLogger.redacted('❌ Search error: $e');
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
      SecureLogger.redacted('❌ Get by mood error: $e');
      return [];
    }
  }

  static Future<void> deleteAllConversations() async {
    try {
      debugPrint('🗑️ [DELETE-DEBUG] Starting complete data deletion...');
      SecureLogger.debug('🗑️ Starting complete data deletion...');

      // 1. Delete the model first
      debugPrint('🗑️ [DELETE-DEBUG] Deleting model...');
      await deleteModel();
      debugPrint('✅ [DELETE-DEBUG] Model deleted');

      // 2. Close the Hive boxes
      debugPrint('🗑️ [DELETE-DEBUG] Closing Hive boxes...');
      if (conversationBox.isOpen) {
        await conversationBox.close();
        debugPrint('✅ [DELETE-DEBUG] Closed conversations box');
        SecureLogger.debug('✅ Closed conversations box');
      }
      if (preferenceBox.isOpen) {
        await preferenceBox.close();
        debugPrint('✅ [DELETE-DEBUG] Closed preferences box');
        SecureLogger.debug('✅ Closed preferences box');
      }

      // 3. Delete the Hive database files on all platforms
      debugPrint('🗑️ [DELETE-DEBUG] Deleting Hive files...');

      // Primary location: Application Documents Directory (works on all platforms)
      final appDir = await getApplicationDocumentsDirectory();
      final conversationFile = File('${appDir.path}/conversations.hive');
      final conversationLock = File('${appDir.path}/conversations.lock');
      final preferencesFile = File('${appDir.path}/preferences.hive');
      final preferencesLock = File('${appDir.path}/preferences.lock');

      for (final file in [conversationFile, conversationLock, preferencesFile, preferencesLock]) {
        if (await file.exists()) {
          try {
            await file.delete();
            debugPrint('✅ [DELETE-DEBUG] Deleted: ${file.path}');
            SecureLogger.debug('✅ Deleted: ${file.path}');
          } catch (e) {
            debugPrint('⚠️ [DELETE-DEBUG] Failed to delete ${file.path}: $e');
          }
        }
      }

      // 4. Also check App Support directory (used on some platforms)
      debugPrint('🗑️ [DELETE-DEBUG] Checking alternate Hive locations...');
      final appDataDir = await getApplicationSupportDirectory();
      final altConversationFile = File('${appDataDir.path}/conversations.hive');
      final altConversationLock = File('${appDataDir.path}/conversations.lock');

      for (final file in [altConversationFile, altConversationLock]) {
        if (await file.exists()) {
          try {
            await file.delete();
            debugPrint('✅ [DELETE-DEBUG] Deleted alt location: ${file.path}');
            SecureLogger.debug('✅ Deleted alt location: ${file.path}');
          } catch (e) {
            debugPrint('⚠️ [DELETE-DEBUG] Failed to delete ${file.path}: $e');
          }
        }
      }

      // 5. Clean up temp directory
      debugPrint('🗑️ [DELETE-DEBUG] Cleaning temp directory...');
      await cleanupTempDirectory();
      debugPrint('✅ [DELETE-DEBUG] Temp directory cleaned');

      // 6. Reinitialize Hive with fresh empty boxes
      debugPrint('🗑️ [DELETE-DEBUG] Reinitializing Hive...');
      _initialized = false;
      await initialize();
      debugPrint('✅ [DELETE-DEBUG] Hive reinitialized');

      SecureLogger.debug('✅ Complete data deletion finished - Hive reinitialized');
      debugPrint('✅ [DELETE-DEBUG] Complete data deletion finished');
    } catch (e) {
      debugPrint('⚠️ [DELETE-DEBUG] Deletion error (non-fatal): $e');
      SecureLogger.redacted('⚠️ Deletion error (non-fatal): $e');
      // Don't rethrow - user should still see success message
    }
  }

  static Future<void> deleteConversationById(int id) async {
    try {
      await conversationBox.deleteAt(id);
      SecureLogger.debug('✅ Conversation $id deleted');
    } catch (e) {
      SecureLogger.redacted('❌ Delete by id error: $e');
    }
  }

  static Future<void> deleteOldConversations({required DateTime olderThan}) async {
    try {
      final keysToDelete = <int>[];
      for (var i = 0; i < conversationBox.length; i++) {
        final encrypted = conversationBox.getAt(i);
        if (encrypted is String) {
          try {
            // Decrypt to read timestamp
            final conv = _decryptConversation(encrypted);
            final timestamp = DateTime.tryParse(conv['timestamp'] as String? ?? '');
            if (timestamp != null && timestamp.isBefore(olderThan)) {
              keysToDelete.add(i);
            }
          } catch (e) {
            debugPrint('⚠️ [DECRYPT-DEBUG] Failed to decrypt conversation at index $i: $e');
          }
        }
      }

      for (final key in keysToDelete.reversed) {
        await conversationBox.deleteAt(key);
      }
      SecureLogger.debug('✅ Old conversations deleted');
    } catch (e) {
      SecureLogger.redacted('❌ Delete old error: $e');
    }
  }

  // ===== Multi-Conversation Sessions (New System) =====

  static Future<void> saveConversationSession(String conversationId, Map<String, dynamic> conversationJson) async {
    try {
      // Encrypt before storing
      final encrypted = _encryptConversation(conversationJson);
      await conversationBox.put(conversationId, encrypted);
      SecureLogger.debug('💾 Conversation session saved: $conversationId');
    } catch (e) {
      SecureLogger.redacted('❌ Save conversation session error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getConversationSession(String conversationId) async {
    try {
      final encrypted = conversationBox.get(conversationId);
      if (encrypted is String) {
        return _decryptConversation(encrypted);
      }
      return null;
    } catch (e) {
      SecureLogger.redacted('❌ Get conversation session error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllConversationSessions() async {
    try {
      final sessions = <Map<String, dynamic>>[];
      for (final key in conversationBox.keys) {
        try {
          final encrypted = conversationBox.get(key);
          if (encrypted is String) {
            // Decrypt if it's encrypted (new system)
            final sessionMap = _decryptConversation(encrypted);
            // Only include if it has required fields (new system conversation)
            if (sessionMap.containsKey('id') && sessionMap.containsKey('title')) {
              sessions.add(sessionMap);
            }
          } else if (encrypted is Map) {
            // Fallback for old unencrypted data
            final sessionMap = Map<String, dynamic>.from(encrypted);
            if (sessionMap.containsKey('id') && sessionMap.containsKey('title')) {
              sessions.add(sessionMap);
            }
          }
        } catch (e) {
          SecureLogger.redacted('⚠️ Error loading session for key $key: $e');
          // Continue loading other sessions
        }
      }
      // Sort by lastModifiedAt in descending order
      sessions.sort((a, b) {
        try {
          final dateA = DateTime.tryParse(a['lastModifiedAt'] as String? ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['lastModifiedAt'] as String? ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });
      SecureLogger.debug('✅ Loaded ${sessions.length} conversation sessions from Hive');
      return sessions;
    } catch (e) {
      SecureLogger.redacted('❌ Get all conversation sessions error: $e');
      return [];
    }
  }

  static Future<void> deleteConversationSession(String conversationId) async {
    try {
      await conversationBox.delete(conversationId);
      SecureLogger.debug('✅ Conversation session deleted: $conversationId');
    } catch (e) {
      SecureLogger.redacted('❌ Delete conversation session error: $e');
      rethrow;
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
      SecureLogger.redacted('❌ Get stats error: $e');
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

  /// Delete Gemma model from disk (called when clearing all data)
  static Future<void> deleteModel() async {
    try {
      SecureLogger.debug('🗑️ Deleting cached Gemma model...');

      // Get application documents directory
      final docsDir = await getApplicationDocumentsDirectory();

      // Possible model directory names (varies by flutter_gemma version)
      final possibleDirs = [
        'gemma_model',
        'flutter_gemma',
        '.flutter_gemma',
        'models',
      ];

      // Try deleting from each possible location
      for (final dirName in possibleDirs) {
        final modelDir = Directory('${docsDir.path}/$dirName');
        if (await modelDir.exists()) {
          try {
            await modelDir.delete(recursive: true);
            SecureLogger.debug('✅ Deleted model directory: $dirName');
          } catch (e) {
            SecureLogger.redacted('⚠️ Failed to delete $dirName: $e');
          }
        }
      }

      // Also check temporary directory for cached model
      try {
        final tempDir = await getTemporaryDirectory();
        final tempModelDir = Directory('${tempDir.path}/flutter_gemma');
        if (await tempModelDir.exists()) {
          await tempModelDir.delete(recursive: true);
          SecureLogger.debug('✅ Deleted temp model directory');
        }
      } catch (e) {
        SecureLogger.redacted('⚠️ Failed to clean temp model cache: $e');
      }

      SecureLogger.debug('✅ Model deletion complete');
    } catch (e) {
      SecureLogger.redacted('⚠️ Model deletion error (non-fatal): $e');
      // Don't rethrow - model deletion failure shouldn't block data clearing
    }
  }

  /// Cleanup temporary directories and caches
  static Future<void> cleanupTempDirectory() async {
    try {
      SecureLogger.debug('🗑️ Cleaning up temporary files...');

      final tempDir = await getTemporaryDirectory();
      final ventaiTempDir = Directory('${tempDir.path}/ventai_temp');

      if (await ventaiTempDir.exists()) {
        try {
          await ventaiTempDir.delete(recursive: true);
          SecureLogger.debug('✅ Temp directory cleaned');
        } catch (e) {
          SecureLogger.redacted('⚠️ Failed to delete ventai_temp: $e');
        }
      }

      // Also clean flutter_gemma cache
      final gemmaTemp = Directory('${tempDir.path}/flutter_gemma');
      if (await gemmaTemp.exists()) {
        try {
          await gemmaTemp.delete(recursive: true);
          SecureLogger.debug('✅ Gemma temp cache cleaned');
        } catch (e) {
          SecureLogger.redacted('⚠️ Failed to delete gemma temp: $e');
        }
      }
    } catch (e) {
      SecureLogger.redacted('Temp cleanup error: non-fatal');
    }
  }

  // Preferences
  static Future<void> setPreference(String key, String value) async {
    try {
      await preferenceBox.put(key, value);
      SecureLogger.debug('✅ Preference saved: $key');
    } catch (e) {
      SecureLogger.redacted('❌ Preference save error: $e');
      rethrow;
    }
  }

  static Future<String?> getPreference(String key) async {
    try {
      final value = preferenceBox.get(key);
      return value is String ? value : null;
    } catch (e) {
      SecureLogger.redacted('❌ Preference get error: $e');
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
      SecureLogger.redacted('❌ Get all preferences error: $e');
      return {};
    }
  }

  static Future<void> deletePreference(String key) async {
    try {
      await preferenceBox.delete(key);
      SecureLogger.debug('✅ Preference deleted: $key');
    } catch (e) {
      SecureLogger.redacted('❌ Preference delete error: $e');
    }
  }

  static int getConversationCount() {
    return conversationBox.length;
  }

  /// Print all storage paths used by the app (for debugging)
  static Future<void> printStoragePaths() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final appSupport = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();

      debugPrint('');
      debugPrint('📁 ================== STORAGE PATHS ==================');
      debugPrint('📁 Platform: ${Platform.operatingSystem}');
      debugPrint('📁');
      debugPrint('📁 Documents Directory:');
      debugPrint('📁   ${docDir.path}');
      debugPrint('📁');
      debugPrint('📁 App Support Directory:');
      debugPrint('📁   ${appSupport.path}');
      debugPrint('📁');
      debugPrint('📁 Temp Directory:');
      debugPrint('📁   ${tempDir.path}');
      debugPrint('📁');
      debugPrint('📁 ✅ Hive Database Files:');
      debugPrint('📁   Conversations: ${docDir.path}/conversations.hive');
      debugPrint('📁   Preferences:   ${docDir.path}/preferences.hive');
      debugPrint('📁');
      debugPrint('📁 ✅ Lock Files:');
      debugPrint('📁   Conversations: ${docDir.path}/conversations.lock');
      debugPrint('📁   Preferences:   ${docDir.path}/preferences.lock');
      debugPrint('📁');
      debugPrint('📁 ✅ Model Cache:');
      debugPrint('📁   ${docDir.path}/gemma_model');
      debugPrint('📁   ${docDir.path}/flutter_gemma');
      debugPrint('📁');
      debugPrint('📁 ✅ Temp Cleanup:');
      debugPrint('📁   ${tempDir.path}/ventai_temp');
      debugPrint('📁   ${tempDir.path}/flutter_gemma');
      debugPrint('📁 ================== END PATHS ==================');
      debugPrint('');

      // Also log via SecureLogger
      SecureLogger.debug('📁 Storage paths logged to console');
    } catch (e) {
      debugPrint('❌ Error printing storage paths: $e');
    }
  }

  static Future<void> close() async {
    try {
      await Hive.close();
      _initialized = false;
      SecureLogger.debug('✅ Hive closed');
    } catch (e) {
      SecureLogger.redacted('❌ Close error: $e');
    }
  }
}
