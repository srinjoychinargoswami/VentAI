import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'services/hive_database.dart';
import 'services/gemma_service.dart';
import 'utils/secure_logger.dart';
import 'providers/conversation_provider.dart';
import 'providers/setup_state_provider.dart';
import 'screens/app_setup_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/legal_page.dart';
import 'screens/model_license_screen.dart';
import 'themes/app_theme.dart';

// Platform detection
bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
bool get _isWeb => kIsWeb;

/// Bootstrap Gemma with LiteRT-LM engine (flutter_gemma 1.5.9)
/// LiteRtLmEngine: For .litertlm models (ARM64 optimized)
/// Works on BOTH mobile and desktop platforms
Future<void> _bootstrapGemma() async {
  try {
    final platformPrefix = _isMobile ? '📱' : '🖥️';
    debugPrint('$platformPrefix Bootstrapping Gemma LiteRT-LM engine...');
    debugPrint('📥 Model will download when user accepts license (~500MB)...');

    // Initialize flutter_gemma with LiteRtLmEngine for .litertlm models
    await FlutterGemma.initialize(
      inferenceEngines: const [
        LiteRtLmEngine(),
      ],
    );
    debugPrint('✅ Gemma initialized (LiteRT-LM engine for .litertlm format)');
  } catch (e) {
    debugPrint('⚠️ Gemma bootstrap error: $e');
    // Non-fatal — will use fallback responses
  }
}

/// Initialize Gemma AI service (both platforms)
Future<void> _initGemmaAI() async {
  try {
    final platformPrefix = _isMobile ? '📱' : '🖥️';
    debugPrint('$platformPrefix Initializing Gemma AI service...');
    await GemmaService().initialize();
    debugPrint('✅ Gemma AI initialized');
  } catch (e) {
    debugPrint('⚠️ Gemma AI initialization error: $e');
    // Non-fatal — will use fallback responses
  }
}

Future<void> main() async {
  // Suppress ALL debug output in release builds
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      // No-op: suppress all debugPrint() calls in release
      // This prevents conversation content and sensitive data from appearing in system logs
    };
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Restrict keyboard input to system keyboard only (security)
  try {
    debugPrint('🔐 Restricting keyboard to system input method only...');
    await SystemChannels.textInput.invokeMethod('TextInput.setClientHandler', null);
    debugPrint('✅ Keyboard restricted to system input method');
  } catch (e) {
    debugPrint('⚠️ Keyboard restriction not fully supported on this platform: $e');
  }

  // Print storage paths in debug mode for diagnostics
  if (kDebugMode) {
    await HiveDatabase.printStoragePaths();
  }

  // Initialize Hive FIRST - before everything else
  try {
    debugPrint('🗄️ Initializing Hive...');
    await HiveDatabase.initialize();
    debugPrint('✅ Hive initialized');
  } catch (e) {
    debugPrint('❌ Hive init failed: $e');
    // Don't crash - app can work without database
  }

  // Handle app termination - cleanup model and temp files on exit
  SystemChannels.lifecycle.setMessageHandler((msg) async {
    if (msg?.contains('AppLifecycleState.detached') ?? false) {
      debugPrint('🧹 App terminating - running cleanup...');
      try {
        // Delete the Gemma model (~500MB)
        debugPrint('🗑️ Deleting Gemma model...');
        await HiveDatabase.deleteModel();
        debugPrint('✅ Gemma model deleted');
        SecureLogger.debug('✅ Gemma model deleted');

        // Clean up temporary files
        debugPrint('🧹 Cleaning temporary files...');
        await HiveDatabase.cleanupTempDirectory();
        debugPrint('✅ Temporary files cleaned');
        SecureLogger.debug('✅ Temporary files cleaned');

        SecureLogger.debug('✅ App termination cleanup complete');
        debugPrint('✅ App termination cleanup complete');
      } catch (e) {
        debugPrint('⚠️ Termination cleanup error: $e');
        SecureLogger.redacted('⚠️ Termination cleanup error: $e');
        // Don't rethrow - cleanup errors shouldn't block uninstall
      }
    }
    return null;
  });

  // Initialize Gemma for both mobile and desktop
  if (_isMobile) {
    debugPrint('📱 Running on mobile platform');
    await _bootstrapGemma();
    await _initGemmaAI();
  } else if (_isDesktop) {
    debugPrint('🖥️ Running on desktop platform');
    await _bootstrapGemma();
    await _initGemmaAI();
  } else if (_isWeb) {
    debugPrint('🌐 Running on web platform');
  }

  // Then run app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SetupStateProvider>(
          create: (_) => SetupStateProvider(),
        ),

        ChangeNotifierProvider<ConversationProvider>(
          create: (context) => ConversationProvider(
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

  /// Platform-aware app initialization
  Future<void> _initializeApp() async {
    try {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Starting app initialization...');

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

  /// Platform-aware force reset (for testing only)
  Future<void> _forceResetForTesting() async {
    try {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix FORCING FRESH SETUP FOR TESTING...');

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      debugPrint('$platformPrefix Setup data cleared');

    } catch (e) {
      debugPrint('❌ Force reset error: $e');
    }
  }

  /// Platform-aware disposal
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Mobile: Dispose Gemma service
    if (_isMobile) {
      GemmaService().dispose();
      debugPrint('📱 Gemma service disposed');
    }
    
    super.dispose();
  }
  
  /// Platform-aware lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final platformPrefix = _isMobile ? '📱' : '🖥️';

    switch (state) {
      case AppLifecycleState.detached:
        debugPrint('$platformPrefix App detached - running cleanup');
        // Cleanup model and temporary files on app exit (fire and forget)
        HiveDatabase.deleteModel();
        HiveDatabase.cleanupTempDirectory();
        break;
        
      case AppLifecycleState.paused:
        debugPrint('$platformPrefix App paused');
        break;
        
      case AppLifecycleState.resumed:
        debugPrint('$platformPrefix App resumed');
        _ensureServiceHealthy();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Service health check
  Future<void> _ensureServiceHealthy() async {
    try {
      if (_isMobile) {
        final status = await GemmaService().getStatus();
        final canGenerate = status['can_generate'] as bool? ?? false;
        debugPrint('📱 Gemma AI ${canGenerate ? "ready" : "not ready"}');
      }
    } catch (e) {
      debugPrint('⚠️ Service health check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vent AI - Emotional Support Companion',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Consumer<SetupStateProvider>(
        builder: (context, setupState, child) {
          if (setupState.needsSetup || setupState.isInitializing) {
            final platformName = _isMobile ? 'mobile' : 'desktop';
            String message = 'Setting up your $platformName AI companion...';

            if (setupState.isInitializing) {
              message = 'Initializing Gemma AI...\n\nThis may take a moment on first run.';
            }

            return AppSetupScreen(message: message);
          } else {
            return const ChatScreen();
          }
        },
      ),
      routes: {
        '/legal': (context) => const LegalPage(),
        '/license': (context) => const ModelLicenseScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}