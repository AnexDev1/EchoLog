import 'package:echolog/services/recording_service.dart';
import 'package:echolog/utils/color_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'home_screen.dart';
import 'models/recording_entry.dart';
import 'models/custom_category.dart';
import 'app_themes.dart';
import 'theme_provider.dart';
import 'utils/duration_adapter.dart';
// import 'screens/recording_player_screen.dart'; // REMOVE THIS
import 'providers/playback_provider.dart'; // ADD THIS

const String WIDGET_METHOD_CHANNEL_NAME = "com.anexon.echolog/widget";
const String recordingsBoxName = 'recordingsBoxv2';
const String customCategoriesBoxName = 'customCategoriesBox';
const String hiddenRecordingsBoxName = 'hiddenRecordingsBox';
const String appSettingsBoxName = 'appSettingsBox';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

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

  runApp(
    MultiProvider(
      // Use MultiProvider if you have more than one
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PlaybackProvider()), // ADD THIS
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

class _MyAppState extends State<MyApp> {
  static const MethodChannel _widgetMethodChannel = MethodChannel(
    WIDGET_METHOD_CHANNEL_NAME,
  );
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupWidgetListener();
    _initiallyUpdateWidget();
  }

  Future<void> _initiallyUpdateWidget() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await updateWidgetWithRecentRecording();
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
        // Ensure HomeScreen is visible (pop other routes if necessary)
        // This is important if the app was in the background with other screens open.
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);

        // Use Provider to tell HomeScreen to play this recording
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
    // ThemeProvider is already provided by MultiProvider
    // final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Echolog',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: context
          .watch<ThemeProvider>()
          .themeMode, // Use context.watch here
      debugShowCheckedModeBanner: false,
      // home: const HomeScreen(), // initialRoute will handle this
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        // NO '/recordingPlayer' route needed
      },
    );
  }
}
