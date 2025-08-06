import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'services/offline_storage.dart';
import 'services/ollama_manager.dart';
import 'services/voice_input_service.dart';
import 'services/voice_emotion_analyzer.dart';
import 'providers/conversation_provider.dart';
import 'providers/setup_state_provider.dart';
import 'screens/app_setup_screen.dart';
import 'screens/chat_screen.dart';
import 'themes/app_theme.dart';

/// Initialize voice services with proper permission handling
Future<void> _initVoiceServices() async {
  try {
    debugPrint('🎤 Requesting microphone permissions...');
    
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        debugPrint('Microphone permission granted');
      } else {
        debugPrint('Microphone permission denied');
        return; // Don't initialize voice services without permission
      }
    } else {
      debugPrint('Microphone permission already granted');
    }

    // Pre-initialize voice services for faster first-use experience
    await VoiceInputService.initialize();
    await VoiceEmotionAnalyzer.initialize();
    
    debugPrint('Voice services initialized successfully');
  } catch (e) {
    debugPrint('Voice services initialization error: $e');
    // Continue app initialization even if voice services fail
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize voice services early for better UX
  await _initVoiceServices();

  // Initialize database with error handling
  late final AppDatabase database;
  try {
    database = AppDatabase();
    debugPrint('Database initialized successfully');
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    rethrow;
  }

  runApp(
    MultiProvider(
      providers: [
        // Provide the database instance
        Provider<AppDatabase>.value(value: database),

        // Setup provider first to ensure dependency order
        ChangeNotifierProvider<SetupStateProvider>(
          create: (_) => SetupStateProvider(),
        ),

        // Conversation provider with proper dependency injection
        ChangeNotifierProvider<ConversationProvider>(
          create: (context) => ConversationProvider(
            database: context.read<AppDatabase>(),
            setupStateProvider: context.read<SetupStateProvider>(),
          ),
        ),
      ],
      child: const VentAiApp(),
    ),
  );
}

class VentAiApp extends StatefulWidget {
  const VentAiApp({super.key});

  @override
  State<VentAiApp> createState() => _VentAiAppState();
}

class _VentAiAppState extends State<VentAiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  /// Initialize app with proper service lifecycle management
  Future<void> _initializeApp() async {
    try {
      // Clean up orphaned processes first
      await OllamaManager.cleanupOrphanedProcesses();

      // COMMENTED OUT: Force reset to preserve cached models
      // if (kDebugMode) {
      //   await _forceResetForTesting();
      // }
      debugPrint('Force reset disabled - preserving cached models');

      // Proper timing for setup initialization
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final setupProvider = context.read<SetupStateProvider>();
        await setupProvider.initialize();

        // Start complete setup process that manages Ollama service
        if (setupProvider.needsSetup) {
          await setupProvider.startCompleteSetup();
        }
      });

    } catch (e) {
      debugPrint('App initialization error: $e');
    }
  }

  /// Force reset all setup data for fresh testing (DISABLED by default)
  Future<void> _forceResetForTesting() async {
    try {
      debugPrint('FORCING FRESH SETUP FOR TESTING...');
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clean Ollama data directories
      await _cleanAllOllamaData();
      
      // Reset OllamaManager state
      OllamaManager.resetForTesting();
      
      debugPrint('🧹 All setup data cleared - will run fresh installation');
      
    } catch (e) {
      debugPrint('Error during force reset: $e');
    }
  }

  /// Clean all Ollama data from system
  Future<void> _cleanAllOllamaData() async {
    try {
      // Clean app-specific Ollama directory
      final appDir = await getApplicationSupportDirectory();
      final ollamaAppDir = Directory(path.join(appDir.path, 'ollama'));
      if (await ollamaAppDir.exists()) {
        await ollamaAppDir.delete(recursive: true);
        debugPrint('Deleted app Ollama directory');
      }

      // Clean system Ollama directory (Windows)
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final systemOllamaDir = Directory(path.join(userProfile, '.ollama'));
          if (await systemOllamaDir.exists()) {
            await systemOllamaDir.delete(recursive: true);
            debugPrint('Deleted system .ollama directory');
          }
        }
      }

      // Clean temp directories that might contain Ollama data
      final tempDir = Directory.systemTemp;
      final tempOllamaDir = Directory(path.join(tempDir.path, 'ollama'));
      if (await tempOllamaDir.exists()) {
        await tempOllamaDir.delete(recursive: true);
        debugPrint('🗑️ Deleted temp Ollama directory');
      }

    } catch (e) {
      debugPrint('Error cleaning Ollama data: $e');
    }
  }

  /// Proper service shutdown on app termination
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Shutdown persistent Ollama service
    OllamaManager.shutdown();
    super.dispose();
  }
  
  /// Handle app lifecycle changes for service management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        // App is terminating - shutdown service
        debugPrint('App detached - shutting down Ollama service');
        OllamaManager.shutdown();
        break;
      case AppLifecycleState.paused:
        // App is backgrounded - service can continue running
        debugPrint('App paused - Ollama service continues running');
        break;
      case AppLifecycleState.resumed:
        // App is foregrounded - ensure service is healthy
        debugPrint('App resumed - checking Ollama service health');
        _ensureServiceHealthy();
        break;
      case AppLifecycleState.inactive:
        // App is becoming inactive - no action needed
        break;
      case AppLifecycleState.hidden:
        // App is hidden - no action needed  
        break;
    }
  }

  /// Ensure Ollama service is healthy when app resumes
  Future<void> _ensureServiceHealthy() async {
    try {
      if (OllamaManager.isInitialized) {
        final serviceReady = await OllamaManager.ensureServiceRunning();
        if (serviceReady) {
          debugPrint('Ollama service healthy on app resume');
        } else {
          debugPrint('Ollama service unhealthy on app resume');
        }
      }
    } catch (e) {
      debugPrint('Error checking service health: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vent AI - Voice-Enabled Mental Health Companion',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Consumer<SetupStateProvider>(
        builder: (context, setupState, child) {
          // Proper setup flow control
          if (setupState.needsSetup || setupState.isInitializing) {
            String message = 'Setting up your voice-enabled AI companion...';
            if (setupState.isInitializing) {
              message = 'Installing AI and downloading models...\n\nThis may take several minutes on first run.';
            }
            return AppSetupScreen(message: message);
          } else {
            return const ChatScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
