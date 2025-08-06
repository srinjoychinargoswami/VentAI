import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AppPaths {
  static String? _appVersion;
  static String? _cachedAppDirectory;
  static String? _cachedOllamaDirectory;
  
  /// Initialize version (call once at app startup)
  static Future<void> initialize({String? version}) async {
    if (version != null) {
      _appVersion = version;
    } else {
      // Use timestamp for development/testing
      _appVersion = DateTime.now().millisecondsSinceEpoch.toString();
      // TODO: For production, use package_info_plus:
      // final packageInfo = await PackageInfo.fromPlatform();
      // _appVersion = packageInfo.version;
    }
    
    // Pre-create essential directories
    await getAppDataDirectory();
    await getOllamaDirectory();
    
    print('AppPaths initialized with version: $_appVersion');
  }
  
  /// Get main application data directory
  static Future<String> getAppDataDirectory() async {
    if (_cachedAppDirectory != null) return _cachedAppDirectory!;
    
    try {
      if (_appVersion == null) {
        await initialize();
      }
      
      final baseDir = await getApplicationSupportDirectory();
      final appPath = path.join(baseDir.path, 'VentAI_$_appVersion');
      
      final directory = Directory(appPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print('Created app directory: $appPath');
      }
      
      _cachedAppDirectory = appPath;
      return appPath;
    } catch (e) {
      print('Failed to create app directory: $e');
      throw Exception('Could not create application data directory: $e');
    }
  }
  
  /// Get Ollama installation directory
  static Future<String> getOllamaDirectory() async {
    if (_cachedOllamaDirectory != null) return _cachedOllamaDirectory!;
    
    try {
      final appDir = await getAppDataDirectory();
      final ollamaPath = path.join(appDir, 'ollama');
      
      final directory = Directory(ollamaPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print('Created Ollama directory: $ollamaPath');
      }
      
      _cachedOllamaDirectory = ollamaPath;
      return ollamaPath;
    } catch (e) {
      print('Failed to create Ollama directory: $e');
      throw Exception('Could not create Ollama directory: $e');
    }
  }
  
  /// Get Ollama executable path
  static Future<String> getOllamaExecutablePath() async {
    final ollamaDir = await getOllamaDirectory();
    return path.join(ollamaDir, 'ollama.exe');
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
  
  /// Get system Ollama directory (for cleanup)
  static String getSystemOllamaDirectory() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return path.join(userProfile, '.ollama');
      }
    }
    return path.join(Platform.environment['HOME'] ?? '', '.ollama');
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
      directories.add(getSystemOllamaDirectory());
    } catch (e) {
      print('Error getting directories for cleanup: $e');
    }
    
    return directories;
  }
  
  /// Create a fresh directory for new installations
  static Future<String> createFreshInstallation() async {
    // Clear caches to force new directory creation
    _cachedAppDirectory = null;
    _cachedOllamaDirectory = null;
    
    // Generate new version for fresh install
    _appVersion = 'fresh_${DateTime.now().millisecondsSinceEpoch}';
    
    return await getAppDataDirectory();
  }
  
  /// Verify all essential directories exist
  static Future<bool> verifyDirectoryStructure() async {
    try {
      await getAppDataDirectory();
      await getOllamaDirectory();
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
    _cachedOllamaDirectory = null;
    print('AppPaths reset for testing');
  }
  
  /// Get current app version
  static String? get currentVersion => _appVersion;
}
