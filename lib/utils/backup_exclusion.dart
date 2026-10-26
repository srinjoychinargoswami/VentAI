import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filename flutter_gemma uses for the model inside the Documents directory.
const String kGemmaModelFilename = 'gemma-4-E2B-it.litertlm';

/// Hive box file holding conversation history (Hive.initFlutter() uses Documents).
const String kChatHistoryFilename = 'conversations.hive';

/// Copy of the box taken before the per-install-key migration.
const String kChatHistoryPreMigrationSuffix = '.pre-encryption-v2';
const String kChatHistoryPreMigrationFilename =
    '$kChatHistoryFilename$kChatHistoryPreMigrationSuffix';

/// Hive box file holding chat records no key could decrypt (Hive box name
/// 'conversations.quarantine', so the file is `<name>.hive`).
const String kQuarantineFilename = 'conversations.quarantine.hive';

const MethodChannel _storageChannel = MethodChannel('com.ventai.app/storage');

/// iOS only: marks [filenames] in the Documents directory as excluded from
/// iCloud/Finder backup. Missing files are skipped; failures never throw.
Future<void> excludeDocumentsFromBackup(List<String> filenames) async {
  if (kIsWeb || !Platform.isIOS) return;

  try {
    final docsDir = await getApplicationDocumentsDirectory();
    for (final filename in filenames) {
      try {
        final excluded = await _storageChannel.invokeMethod<bool>(
          'excludeFromBackup',
          {'path': p.join(docsDir.path, filename)},
        );
        debugPrint('🗄️ Backup exclusion for $filename: ${excluded == true ? "set" : "file not present"}');
      } catch (e) {
        debugPrint('⚠️ Failed to exclude $filename from backup: $e');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Backup exclusion skipped: $e');
  }
}
