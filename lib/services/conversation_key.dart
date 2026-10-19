import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'hive_database.dart';

/// Secure-storage entry holding this install's base64 conversation key.
const kKeyStorageName = 'ventai_conversation_key_v2';

/// Preference (in the Hive preferences box) set once every record has been
/// moved off the legacy fixed key.
const kMigrationFlagName = 'ventai_key_migration_v2_done';

const int _keyLength = 32;

const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
  // usesDataProtectionKeychain: false avoids the Keychain Sharing entitlement,
  // which needs a provisioning profile and breaks DMG distribution.
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
    usesDataProtectionKeychain: false,
  ),
  // resetOnError: false so a failed read throws instead of silently wiping
  // the stored key.
  aOptions: AndroidOptions(resetOnError: false),
  wOptions: WindowsOptions(),
);

/// Thrown when the key is missing or unusable and must not be regenerated.
class ConversationKeyException implements Exception {
  final String message;
  const ConversationKeyException(this.message);

  @override
  String toString() => 'ConversationKeyException: $message';
}

List<int>? _cachedKey;

/// Returns this install's 32-byte conversation key, creating it on first use.
///
/// - A read error from secure storage is rethrown; a key is never generated
///   after a failed read.
/// - If no key is stored but already-migrated records exist, the key was lost
///   (e.g. a restore without secure storage), so this throws instead of
///   generating a key the existing data can't be decrypted with.
Future<List<int>> getConversationKey() async {
  final cached = _cachedKey;
  if (cached != null) return cached;

  final stored = await _secureStorage.read(key: kKeyStorageName);
  if (stored != null) {
    final key = base64.decode(stored);
    if (key.length != _keyLength) {
      throw ConversationKeyException(
          'Stored conversation key has ${key.length} bytes, expected $_keyLength.');
    }
    return _cachedKey = key;
  }

  // Before migration, existing records use the legacy key and are expected.
  // After migration, records without a stored key mean the key was lost.
  if (HiveDatabase.isKeyMigrationDone && HiveDatabase.hasConversationRecords) {
    throw const ConversationKeyException(
        'No conversation key found, but encrypted conversations exist.');
  }

  final random = Random.secure();
  final newKey = List<int>.generate(_keyLength, (_) => random.nextInt(256));
  final encoded = base64.encode(newKey);
  await _secureStorage.write(key: kKeyStorageName, value: encoded);

  final readBack = await _secureStorage.read(key: kKeyStorageName);
  if (readBack != encoded) {
    throw const ConversationKeyException(
        'Conversation key could not be verified after writing it.');
  }
  debugPrint('🔐 Generated new per-install conversation key');
  return _cachedKey = newKey;
}
