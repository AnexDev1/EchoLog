import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme Mode ---
const String PREF_THEME_MODE = 'selectedThemeMode';

// --- Category Tag Style ---
const String PREF_CATEGORY_TAG_STYLE =
    'categoryTagStyle'; // SharedPreferences key

enum CategoryTagStyle {
  original,
  neumorphic,
  glassmorphic,
} // Enum for the styles

// Helper to convert enum to string and back for SharedPreferences
String categoryTagStyleToString(CategoryTagStyle style) =>
    style.name; // Uses enum .name for simplicity
CategoryTagStyle stringToCategoryTagStyle(String? styleString) {
  return CategoryTagStyle.values.firstWhere(
    (e) => e.name == styleString,
    orElse: () =>
        CategoryTagStyle.original, // Default to original if not found or null
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  CategoryTagStyle _categoryTagStyle =
      CategoryTagStyle.original; // Default style

  ThemeMode get themeMode => _themeMode;
  CategoryTagStyle get categoryTagStyle =>
      _categoryTagStyle; // Getter for the style

  ThemeProvider() {
    _loadPreferences(); // Renamed to reflect loading multiple preferences
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load ThemeMode (existing logic)
    final themeString = prefs.getString(PREF_THEME_MODE);
    if (themeString != null) {
      if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    }

    // Load Category Tag Style
    final styleString = prefs.getString(PREF_CATEGORY_TAG_STYLE);
    _categoryTagStyle = stringToCategoryTagStyle(styleString);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return; // Avoid unnecessary operations
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String themeString;
    switch (mode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeString = 'system';
        break;
    }
    await prefs.setString(PREF_THEME_MODE, themeString);
    notifyListeners();
  }

  // Setter for Category Tag Style
  Future<void> setCategoryTagStyle(CategoryTagStyle style) async {
    if (_categoryTagStyle == style) return; // Avoid unnecessary operations
    _categoryTagStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PREF_CATEGORY_TAG_STYLE,
      categoryTagStyleToString(style),
    );
    notifyListeners();
  }

  String getThemeModeString(ThemeMode mode) {
    // Kept this as it was in your original
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
      default:
        return 'System Default';
    }
  }

  // ThemeData getters - these remain unchanged as category tag style is handled by the widget
  ThemeData get lightTheme {
    // Your existing light theme logic
    return ThemeData.light().copyWith(
      // Example: customize if needed, but not for category tag style here
      // appBarTheme: AppBarTheme(backgroundColor: Colors.blue),
    );
  }

  ThemeData get darkTheme {
    // Your existing dark theme logic
    return ThemeData.dark().copyWith(
      // Example: customize if needed, but not for category tag style here
      // appBarTheme: AppBarTheme(backgroundColor: Colors.grey[850]),
    );
  }
}
