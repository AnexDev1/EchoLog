import 'package:echolog/models/custom_category.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/providers/playback_provider.dart';
import 'package:echolog/providers/streak_provider.dart';
import 'package:echolog/providers/transcription_status_provider.dart';
import 'package:echolog/screens/home/home_screen.dart';
import 'package:echolog/screens/locked/locked_screen.dart';
import 'package:echolog/services/api_key_service.dart';
import 'package:echolog/services/security_service.dart';
import 'package:echolog/theme/app_themes.dart';
import 'package:echolog/theme/theme_provider.dart';
import 'package:echolog/utils/color_adapter.dart';
import 'package:echolog/utils/duration_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

const String WIDGET_METHOD_CHANNEL_NAME = "com.anexon.echolog/widget";
const String recordingsBoxName = 'recordingsBoxv2';
const String customCategoriesBoxName = 'customCategoriesBox';
const String hiddenRecordingsBoxName = 'hiddenRecordingsBox';
const String appSettingsBoxName = 'appSettingsBox';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await dotenv.load(fileName: ".env");
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  final apiKey = await ApiKeyService.getApiKey();
  Gemini.init(apiKey: apiKey ?? '');

  if (!Hive.isAdapterRegistered(ColorAdapter().typeId)) {
    Hive.registerAdapter(ColorAdapter());
  }
  if (!Hive.isAdapterRegistered(RecordingEntryAdapter().typeId)) {
    Hive.registerAdapter(RecordingEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(CustomCategoryAdapter().typeId)) {
    Hive.registerAdapter(CustomCategoryAdapter());
  }
  if (!Hive.isAdapterRegistered(DurationAdapter().typeId)) {
    Hive.registerAdapter(DurationAdapter());
  }

  await Hive.openBox<RecordingEntry>(recordingsBoxName);
  await Hive.openBox<CustomCategory>(customCategoriesBoxName);
  await Hive.openBox<RecordingEntry>(hiddenRecordingsBoxName);
  await Hive.openBox<String>(appSettingsBoxName);

  // Pre-initialize the security service to load its settings
  final securityService = SecurityService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StreakProvider()),
        ChangeNotifierProvider(create: (_) => PlaybackProvider()),
        ChangeNotifierProvider(create: (_) => TranscriptionStatusProvider()),
        // Use .value for the pre-initialized service
        ChangeNotifierProvider.value(value: securityService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const MethodChannel _widgetMethodChannel = MethodChannel(
    WIDGET_METHOD_CHANNEL_NAME,
  );
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupWidgetListener();
    _initiallyUpdateWidget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final securityService = Provider.of<SecurityService>(
      context,
      listen: false,
    );
    // Use the new grace period logic from the service
    if (state == AppLifecycleState.paused) {
      securityService.didPause();
    } else if (state == AppLifecycleState.resumed) {
      securityService.didResume();
    }
  }

  Future<void> _initiallyUpdateWidget() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // The function `updateWidgetWithRecentRecording` was not defined in the provided code.
    // It is commented out to prevent errors. Please ensure it exists in your project.
    // await updateWidgetWithRecentRecording();
  }

  Future<void> _setupWidgetListener() async {
    try {
      _widgetMethodChannel.setMethodCallHandler(_handleWidgetMethodCalls);
      print("[Dart Main] Widget method call handler set up successfully.");
    } on PlatformException catch (e) {
      print(
        "[Dart Main] Failed to set method call handler for widget: '${e.message}'.",
      );
    }
  }

  Future<dynamic> _handleWidgetMethodCalls(MethodCall call) async {
    switch (call.method) {
      case 'startQuickRecord':
        print(
          "[Dart Main] Received 'startQuickRecord' call from native widget.",
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _performQuickRecordAction();
        });
        return "Quick record action received by Dart.";

      case 'openRecording':
        final String? recordingId = call.arguments as String?;
        print("[Dart Main] Received 'openRecording' call for ID: $recordingId");
        if (recordingId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _performOpenRecordingAction(recordingId);
          });
        }
        return "Open recording action received by Dart.";

      case 'widgetLaunchedApp':
        final String? sourceDetails = call.arguments as String?;
        print(
          "[Dart Main] App launched from widget (generic). Details: $sourceDetails",
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_navigatorKey.currentContext != null) {
            // Optional: Bring HomeScreen to front if other screens are on top
            // _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
        });
        return "Generic widget launch received.";

      default:
        print('[Dart Main] Unknown method call from widget: ${call.method}');
        throw MissingPluginException(
          'No implementation found for method ${call.method} on channel $WIDGET_METHOD_CHANNEL_NAME',
        );
    }
  }

  void _performQuickRecordAction() {
    if (_navigatorKey.currentState != null &&
        _navigatorKey.currentContext != null) {
      print("[Dart Main] Navigator is ready. Performing quick record action.");
      showDialog(
        context: _navigatorKey.currentContext!,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text("Quick Record Triggered"),
          content: const Text(
            "The app widget requested to start a new recording.",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                print(
                  "[Dart Main] OK pressed on dialog. Implement actual recording logic here.",
                );
              },
            ),
          ],
        ),
      );
    } else {
      print(
        "[Dart Main] Navigator not ready or context unavailable for quick record action.",
      );
    }
  }

  void _performOpenRecordingAction(String recordingId) {
    final currentContext = _navigatorKey.currentContext;
    if (currentContext != null) {
      print(
        "[Dart Main] Context is available. Opening recording ID: $recordingId",
      );

      final box = Hive.box<RecordingEntry>(recordingsBoxName);
      RecordingEntry? entry;
      try {
        entry = box.values.firstWhere((e) => e.id == recordingId);
      } catch (e) {
        entry = null;
        print(
          "[Dart Main] Recording with ID $recordingId not found in box. Error: $e",
        );
      }

      if (entry != null) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);

        Provider.of<PlaybackProvider>(
          currentContext,
          listen: false,
        ).setRecordingToPlay(entry);
        print(
          "[Dart Main] Told PlaybackProvider to play: ${entry.displayName}",
        );
      } else {
        _showFallbackDialog("Recording with ID $recordingId not found.");
      }
    } else {
      print(
        "[Dart Main] Navigator context not available for opening recording action.",
      );
    }
  }

  void _showFallbackDialog(String message) {
    if (_navigatorKey.currentContext != null) {
      showDialog(
        context: _navigatorKey.currentContext!,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text("Widget Action"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the service once here. No need to listen in the build method itself.
    final securityService = Provider.of<SecurityService>(
      context,
      listen: false,
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Echolog',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: context.watch<ThemeProvider>().themeMode,
      debugShowCheckedModeBanner: false,
      home: ValueListenableBuilder<bool>(
        // Listen directly to the isLocked notifier for efficiency
        valueListenable: securityService.isLocked,
        builder: (context, isLocked, child) {
          // Use a Stack to overlay the LockScreen
          return Stack(
            children: [
              // The main app (HomeScreen) is the child, built only once
              child!,
              // Conditionally show the LockScreen on top
              if (isLocked) const LockScreen(),
            ],
          );
        },
        // This is the child that the builder will receive
        child: const HomeScreen(),
      ),
    );
  }
}
