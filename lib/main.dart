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
import 'services/ai_edge_service.dart'; // ADDED: Mobile AI service
import 'services/voice_input_service.dart';
import 'services/voice_emotion_analyzer.dart';
import 'providers/conversation_provider.dart';
import 'providers/setup_state_provider.dart';
import 'screens/app_setup_screen.dart';
import 'screens/chat_screen.dart';
import 'themes/app_theme.dart';

// ADDED: Platform detection
bool get _isMobile => Platform.isAndroid || Platform.isIOS;
bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Initialize voice services with proper permission handling
Future<void> _initVoiceServices() async {
  try {
    debugPrint('Requesting microphone permissions...');
    
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        debugPrint('✅ Microphone permission granted');
      } else {
        debugPrint('⚠️ Microphone permission denied');
        return;
      }
    } else {
      debugPrint('✅ Microphone permission already granted');
    }

    // Pre-initialize voice services
    await VoiceInputService.initialize();
    await VoiceEmotionAnalyzer.initialize();
    
    debugPrint('✅ Voice services initialized');
  } catch (e) {
    debugPrint('❌ Voice services error: $e');
  }
}

/// ADDED: Initialize mobile AI services
Future<void> _initMobileAI() async {
  if (!_isMobile) return;
  
  try {
    final platformPrefix = '📱';
    debugPrint('$platformPrefix Initializing mobile AI...');
    
    await AIService.instance.initialize();
    
    debugPrint('$platformPrefix Mobile AI initialized');
  } catch (e) {
    debugPrint('📱 Mobile AI initialization error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-specific initialization
  if (_isMobile) {
    debugPrint('📱 Running on mobile platform');
    await _initMobileAI();
  } else {
    debugPrint('🖥️ Running on desktop platform');
  }

  // Initialize voice services (works on all platforms)
  await _initVoiceServices();

  // Initialize database
  late final AppDatabase database;
  try {
    database = AppDatabase();
    debugPrint('✅ Database initialized');
  } catch (e) {
    debugPrint('❌ Database initialization failed: $e');
    rethrow;
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        
        ChangeNotifierProvider<SetupStateProvider>(
          create: (_) => SetupStateProvider(),
        ),
        
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

  /// UPDATED: Platform-aware app initialization
  Future<void> _initializeApp() async {
    try {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Starting app initialization...');
      
      // Desktop-only: Clean up orphaned processes
      if (_isDesktop) {
        await OllamaManager.cleanupOrphanedProcesses();
      }

      // Debug mode: Force reset (commented by default)
      // if (kDebugMode) {
      //   await _forceResetForTesting();
      // }

      // Initialize setup provider
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final setupProvider = context.read<SetupStateProvider>();
        await setupProvider.initialize();

        if (setupProvider.needsSetup) {
          await setupProvider.startCompleteSetup();
        }
      });

    } catch (e) {
      debugPrint('❌ App initialization error: $e');
    }
  }

  /// UPDATED: Platform-aware force reset
  Future<void> _forceResetForTesting() async {
    try {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix FORCING FRESH SETUP FOR TESTING...');
      
      // Clear SharedPreferences (all platforms)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Desktop-only: Clean Ollama data
      if (_isDesktop) {
        await _cleanAllOllamaData();
        OllamaManager.resetForTesting();
      }
      
      // Mobile-only: Clear AI service cache (if method exists)
      if (_isMobile) {
        // Note: AIService doesn't have clearModelCache method
        debugPrint('📱 Mobile AI cache cleanup skipped');
      }
      
      debugPrint('$platformPrefix Setup data cleared');
      
    } catch (e) {
      debugPrint('❌ Force reset error: $e');
    }
  }

  /// Clean Ollama data (Desktop only)
  Future<void> _cleanAllOllamaData() async {
    if (!_isDesktop) return;
    
    try {
      debugPrint('🖥️ Cleaning Ollama data...');
      
      // Clean app-specific directory
      final appDir = await getApplicationSupportDirectory();
      final ollamaAppDir = Directory(path.join(appDir.path, 'ollama'));
      if (await ollamaAppDir.exists()) {
        await ollamaAppDir.delete(recursive: true);
        debugPrint('Deleted app Ollama directory');
      }

      // Windows-specific cleanup
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

      // Clean temp directories
      final tempDir = Directory.systemTemp;
      final tempOllamaDir = Directory(path.join(tempDir.path, 'ollama'));
      if (await tempOllamaDir.exists()) {
        await tempOllamaDir.delete(recursive: true);
        debugPrint('Deleted temp Ollama directory');
      }

    } catch (e) {
      debugPrint('❌ Error cleaning Ollama data: $e');
    }
  }

  /// UPDATED: Platform-aware disposal
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Desktop-only: Shutdown Ollama service
    if (_isDesktop) {
      OllamaManager.shutdown();
    }
    
    // Mobile-only: Dispose AIService
    if (_isMobile) {
      AIService.instance.dispose();
    }
    
    super.dispose();
  }
  
  /// UPDATED: Platform-aware lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final platformPrefix = _isMobile ? '📱' : '🖥️';
    
    switch (state) {
      case AppLifecycleState.detached:
        debugPrint('$platformPrefix App detached');
        if (_isDesktop) {
          OllamaManager.shutdown();
        }
        break;
        
      case AppLifecycleState.paused:
        debugPrint('$platformPrefix App paused');
        // Services can continue running
        break;
        
      case AppLifecycleState.resumed:
        debugPrint('$platformPrefix App resumed');
        _ensureServiceHealthy();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // No action needed
        break;
    }
  }

  /// UPDATED: Platform-aware service health check
  Future<void> _ensureServiceHealthy() async {
    try {
      if (_isDesktop && OllamaManager.isInitialized) {
        final serviceReady = await OllamaManager.ensureServiceRunning();
        debugPrint('🖥️ Ollama service ${serviceReady ? "healthy" : "unhealthy"}');
      } else if (_isMobile) {
        final status = await AIService.instance.getStatus();
        final canGenerate = status['can_generate'] as bool? ?? false;
        debugPrint('📱 Mobile AI ${canGenerate ? "ready" : "not ready"}');
      }
    } catch (e) {
      debugPrint('❌ Service health check error: $e');
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
          if (setupState.needsSetup || setupState.isInitializing) {
            final platformName = _isMobile ? 'mobile' : 'desktop';
            String message = 'Setting up your $platformName AI companion...';
            
            if (setupState.isInitializing) {
              message = _isMobile
                  ? 'Initializing mobile AI...\n\nThis may take a moment on first run.'
                  : 'Installing AI and downloading models...\n\nThis may take several minutes on first run.';
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
