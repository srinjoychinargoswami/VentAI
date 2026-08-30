import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AppPaths {
  static String? _appVersion;
  static String? _cachedAppDirectory;
  
  /// Initialize version (call once at app startup)
  static Future<void> initialize({String? version}) async {
    print('🔍 [APP-PATHS] initialize() called');
    if (version != null) {
      _appVersion = version;
      print('🔍 [APP-PATHS] Using provided version: $version');
    } else {
      // Use timestamp for development/testing
      _appVersion = DateTime.now().millisecondsSinceEpoch.toString();
      print('🔍 [APP-PATHS] Generated timestamp version: $_appVersion');
      // TODO: For production, use package_info_plus:
      // final packageInfo = await PackageInfo.fromPlatform();
      // _appVersion = packageInfo.version;
    }

    // Pre-create essential directories
    print('🔍 [APP-PATHS] Pre-creating app data directory...');
    final appDir = await getAppDataDirectory();
    print('✅ [APP-PATHS] App directory ready: $appDir');

    print('✅ [APP-PATHS] Initialization complete with version: $_appVersion');
  }
  
  /// Get main application data directory
  static Future<String> getAppDataDirectory() async {
    print('📁 [APP-PATHS] getAppDataDirectory() called');
    if (_cachedAppDirectory != null) {
      print('📁 [APP-PATHS] Returning cached directory: $_cachedAppDirectory');
      return _cachedAppDirectory!;
    }

    try {
      if (_appVersion == null) {
        print('📁 [APP-PATHS] Version not set, initializing...');
        await initialize();
      }

      print('📁 [APP-PATHS] Getting application support directory...');
      final baseDir = await getApplicationSupportDirectory();
      print('📁 [APP-PATHS] Base dir: ${baseDir.path}');

      final appPath = path.join(baseDir.path, 'VentAI_$_appVersion');
      print('📁 [APP-PATHS] App path: $appPath');

      final directory = Directory(appPath);
      if (!await directory.exists()) {
        print('📁 [APP-PATHS] Directory does not exist, creating: $appPath');
        await directory.create(recursive: true);
        print('✅ [APP-PATHS] Created app directory: $appPath');
      } else {
        print('✅ [APP-PATHS] Directory already exists: $appPath');
      }

      _cachedAppDirectory = appPath;
      print('✅ [APP-PATHS] Cached: $_cachedAppDirectory');
      return appPath;
    } catch (e) {
      print('❌ [APP-PATHS] FAILED to create app directory: $e');
      print('❌ [APP-PATHS] Stack: ${StackTrace.current}');
      throw Exception('Could not create application data directory: $e');
    }
  }
  
  
  /// Get models storage directory
  static Future<String> getModelsDirectory() async {
    final appDir = await getAppDataDirectory();
    final modelsPath = path.join(appDir, 'models');
    
    final directory = Directory(modelsPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('Created models directory: $modelsPath');
    }
    
    return modelsPath;
  }
  
  /// Get chat history storage directory
  static Future<String> getChatHistoryDirectory() async {
    final appDir = await getAppDataDirectory();
    final chatPath = path.join(appDir, 'chats');
    
    final directory = Directory(chatPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('Created chat history directory: $chatPath');
    }
    
    return chatPath;
  }
  
  /// Get logs directory
  static Future<String> getLogsDirectory() async {
    final appDir = await getAppDataDirectory();
    final logsPath = path.join(appDir, 'logs');
    
    final directory = Directory(logsPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('Created logs directory: $logsPath');
    }
    
    return logsPath;
  }
  
  /// Get configuration file path
  static Future<String> getConfigFilePath() async {
    final appDir = await getAppDataDirectory();
    return path.join(appDir, 'config.json');
  }
  
  /// Get setup completion marker file path
  static Future<String> getSetupMarkerPath() async {
    final appDir = await getAppDataDirectory();
    return path.join(appDir, '.setup_complete');
  }
  
  
  /// Get temporary directory for downloads
  static Future<String> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final ventTempPath = path.join(tempDir.path, 'VentAI_temp');
    
    final directory = Directory(ventTempPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return ventTempPath;
  }
  
  /// Check if setup is complete
  static Future<bool> isSetupComplete() async {
    try {
      final markerPath = await getSetupMarkerPath();
      final markerFile = File(markerPath);
      return await markerFile.exists();
    } catch (e) {
      return false;
    }
  }
  
  /// Mark setup as complete
  static Future<void> markSetupComplete() async {
    try {
      final markerPath = await getSetupMarkerPath();
      final markerFile = File(markerPath);
      await markerFile.writeAsString('setup_complete_${DateTime.now().toIso8601String()}');
      print('Setup marked as complete: $markerPath');
    } catch (e) {
      print('Could not mark setup complete: $e');
    }
  }
  
  /// Get all directories that need cleanup
  static Future<List<String>> getAllDataDirectories() async {
    final directories = <String>[];

    try {
      directories.add(await getAppDataDirectory());
    } catch (e) {
      print('Error getting directories for cleanup: $e');
    }

    return directories;
  }
  
  /// Create a fresh directory for new installations
  static Future<String> createFreshInstallation() async {
    // Clear caches to force new directory creation
    _cachedAppDirectory = null;

    // Generate new version for fresh install
    _appVersion = 'fresh_${DateTime.now().millisecondsSinceEpoch}';

    return await getAppDataDirectory();
  }
  
  /// Verify all essential directories exist
  static Future<bool> verifyDirectoryStructure() async {
    try {
      await getAppDataDirectory();
      await getChatHistoryDirectory();
      await getLogsDirectory();

      print('Directory structure verified');
      return true;
    } catch (e) {
      print('Directory structure verification failed: $e');
      return false;
    }
  }
  
  /// Get disk space info for the app directory
  static Future<Map<String, int>> getDiskSpaceInfo() async {
    try {
      final appDir = await getAppDataDirectory();
      final directory = Directory(appDir);
      
      if (Platform.isWindows) {
        // Get disk space using Windows command
        final result = await Process.run(
          'fsutil', 
          ['volume', 'diskfree', appDir.substring(0, 3)], // C:\
          runInShell: true
        );
        
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          // Parse Windows diskfree output
          // This is simplified - you might want more robust parsing
          return {
            'available_bytes': 1000000000, // Placeholder
            'total_bytes': 1000000000000,   // Placeholder
          };
        }
      }
      
      return {
        'available_bytes': 1000000000, // 1GB fallback
        'total_bytes': 1000000000000,  // 1TB fallback
      };
    } catch (e) {
      print('Could not get disk space info: $e');
      return {
        'available_bytes': 1000000000,
        'total_bytes': 1000000000000,
      };
    }
  }
  
  /// Reset all cached paths and version (for testing)
  static void resetForTesting() {
    _appVersion = null;
    _cachedAppDirectory = null;
    print('AppPaths reset for testing');
  }
  
  /// Get current app version
  static String? get currentVersion => _appVersion;
}
