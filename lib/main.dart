import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider

import 'home_screen.dart';
import 'models/recording_entry.dart';
import 'models/custom_category.dart';
import 'app_themes.dart'; // Import your AppThemes
import 'theme_provider.dart'; // Import your ThemeProvider

const String recordingsBoxName = 'recordingsBox';
const String customCategoriesBoxName = 'customCategoriesBox';
const String hiddenRecordingsBoxName = 'hiddenRecordingsBox';
// It's good practice to also have a box for app settings like password
const String appSettingsBoxName = 'appSettingsBox';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register Adapters
  if (!Hive.isAdapterRegistered(ColorAdapter().typeId)) {
    Hive.registerAdapter(ColorAdapter());
  }
  if (!Hive.isAdapterRegistered(RecordingEntryAdapter().typeId)) {
    Hive.registerAdapter(RecordingEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(CustomCategoryAdapter().typeId)) {
    Hive.registerAdapter(CustomCategoryAdapter());
  }

  // Open your boxes
  await Hive.openBox<RecordingEntry>(recordingsBoxName);
  await Hive.openBox<CustomCategory>(customCategoriesBoxName);
  await Hive.openBox<RecordingEntry>(hiddenRecordingsBoxName);
  await Hive.openBox<String>(
    appSettingsBoxName,
  ); // For password and other settings

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(), // Provide ThemeProvider
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to ThemeProvider for themeMode changes
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Echolog',
      theme: AppThemes.lightTheme, // Set your light theme
      darkTheme: AppThemes.darkTheme, // Set your dark theme
      themeMode: themeProvider.themeMode, // Controlled by ThemeProvider
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
