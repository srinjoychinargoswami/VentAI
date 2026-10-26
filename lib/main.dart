import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'services/hive_database.dart';
import 'services/gemma_service.dart';
import 'providers/conversation_provider.dart';
import 'providers/setup_state_provider.dart';
import 'screens/app_setup_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/legal_page.dart';
import 'screens/licenses_page.dart';
import 'screens/model_license_screen.dart';
import 'themes/app_theme.dart';
import 'utils/backup_exclusion.dart';
import 'utils/platform_utils.dart' as platform;

// Platform detection
bool get _isWeb => kIsWeb;

/// Bootstrap Gemma with LiteRT-LM engine (flutter_gemma 1.5.9)
/// LiteRtLmEngine: For .litertlm models (ARM64 optimized)
/// Works on BOTH mobile and desktop platforms
Future<void> _bootstrapGemma() async {
  try {
    final platformPrefix = platform.isMobileOS() ? '📱' : '🖥️';
    debugPrint('$platformPrefix Bootstrapping Gemma LiteRT-LM engine...');
    debugPrint('📥 Model will download when user accepts license (~2.6GB)...');

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
    // _DatabaseGate shows an error screen with Retry; the chat list is never
    // opened on top of an unmigrated or unreadable database.
    debugPrint('❌ Hive init failed: $e');
  }

  // Register the Gemma engine only (fast). The ~2.6GB model itself is loaded
  // lazily by ChatScreen so the first frame is never blocked on it.
  if (platform.isMobileOS()) {
    debugPrint('📱 Running on mobile platform');
    await _bootstrapGemma();
  } else if (platform.isDesktop()) {
    debugPrint('🖥️ Running on desktop platform');
    await _bootstrapGemma();
  } else if (_isWeb) {
    debugPrint('🌐 Running on web platform');
  }

  // iOS: keep the ~2.6GB model and chat history out of iCloud backup.
  // Runs every launch so installs from earlier builds are covered too.
  await excludeDocumentsFromBackup(
      [
    kGemmaModelFilename,
    kChatHistoryFilename,
    kChatHistoryPreMigrationFilename,
    kQuarantineFilename,
  ]);

  // Then run app with providers (gated on the database being ready)
  runApp(const _DatabaseGate());
}

/// Builds the app only once [HiveDatabase] has initialized (boxes open, key
/// migration done, key loaded). Otherwise shows an error with Retry. Sits above
/// the providers because ConversationProvider reads conversations on creation.
class _DatabaseGate extends StatefulWidget {
  const _DatabaseGate();

  @override
  State<_DatabaseGate> createState() => _DatabaseGateState();
}

class _DatabaseGateState extends State<_DatabaseGate> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await HiveDatabase.initialize();
    } catch (e) {
      debugPrint('❌ Hive init retry failed: $e');
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (HiveDatabase.isInitialized) {
      return MultiProvider(
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
      );
    }

    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Your conversations couldn't be opened",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nothing has been deleted. Try again, and if this keeps '
                    'happening, restart your device and reopen Vent AI.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retrying ? null : _retry,
                    child: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      final platformPrefix = platform.isMobileOS() ? '📱' : '🖥️';
      debugPrint('$platformPrefix Starting app initialization...');

      // Initialize setup provider
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final setupProvider = context.read<SetupStateProvider>();
        // Setup itself is started by AppSetupScreen (the only caller of
        // startCompleteSetup), which waits for this initialize() to finish.
        await setupProvider.initialize();
      });

    } catch (e) {
      debugPrint('❌ App initialization error: $e');
    }
  }

  /// Platform-aware force reset (for testing only)
  Future<void> _forceResetForTesting() async {
    try {
      final platformPrefix = platform.isMobileOS() ? '📱' : '🖥️';
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
    if (platform.isMobileOS()) {
      GemmaService().dispose();
      debugPrint('📱 Gemma service disposed');
    }
    
    super.dispose();
  }
  
  /// Platform-aware lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final platformPrefix = platform.isMobileOS() ? '📱' : '🖥️';

    switch (state) {
      case AppLifecycleState.detached:
        // Not reliably delivered on iOS, and the ~2.6GB model must persist
        // between launches, so there is deliberately no cleanup here.
        debugPrint('$platformPrefix App detached');
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
      if (platform.isMobileOS()) {
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
            final platformName = platform.isMobileOS() ? 'mobile' : 'desktop';
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
        '/licenses': (context) => const LicensesPage(),
        '/license': (context) => const ModelLicenseScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}