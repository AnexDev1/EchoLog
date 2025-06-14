import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_screen.dart';
import 'models/recording_entry.dart';
import 'models/custom_category.dart'; // Import CustomCategory model

const String recordingsBoxName = 'recordingsBox';
const String customCategoriesBoxName =
    'customCategoriesBox'; // Define new box name
const String hiddenRecordingsBoxName = 'hiddenRecordingsBox';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register Adapters
  // It's good practice to check if an adapter is already registered.
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
  await Hive.openBox<CustomCategory>(
    customCategoriesBoxName,
  ); // Open the new box
  await Hive.openBox<RecordingEntry>(hiddenRecordingsBoxName);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echolog',
      themeMode: ThemeMode.dark, // Force dark mode
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple.shade300,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple.shade300,
          secondary: Colors.teal.shade300,
          surface: Colors.grey.shade800,
          surfaceVariant: Colors.grey.shade700,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white70,
          background: Colors.grey.shade900,
          error: Colors.red.shade400,
          onError: Colors.black,
          inverseSurface: Colors.grey.shade300, // Added for SnackBar background
          onInverseSurface: Colors.black, // Added for SnackBar text/icon
        ),
        scaffoldBackgroundColor: Colors.grey.shade900,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade800,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        textTheme: TextTheme(
          bodyLarge: GoogleFonts.poppins(color: Colors.white),
          bodyMedium: GoogleFonts.poppins(color: Colors.white70),
          titleLarge: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        dialogTheme: DialogThemeData(
          // Added for consistent dialog styling
          backgroundColor: Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        cardTheme: CardThemeData(
          // Corrected from CardThemeData
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.grey.shade800,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          // Added for consistent button styling
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple.shade300,
            foregroundColor: Colors.black,
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          // Added for consistent text button styling
          style: TextButton.styleFrom(
            foregroundColor: Colors.teal.shade300,
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          // Added for consistent text field styling
          filled: true,
          fillColor: Colors
              .grey
              .shade800, // Slightly different from surface for contrast
          hintStyle: GoogleFonts.poppins(color: Colors.white54),
          labelStyle: GoogleFonts.poppins(color: Colors.deepPurple.shade200),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.deepPurple.shade300, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          // Added for consistent chip styling
          backgroundColor: Colors.grey.shade700,
          selectedColor: Colors.deepPurple.shade300,
          labelStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          secondaryLabelStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ), // For selected chips
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          iconTheme: const IconThemeData(
            color: Colors.black,
            size: 16,
          ), // For selected chip avatar
        ),
        // ... other theme properties
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
