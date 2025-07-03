import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  // --- Light Theme Colors ---
  static final Color _lightPrimaryColor = Colors.deepPurple.shade600;
  static final Color _lightSecondaryColor = Colors.teal.shade600;
  static final Color _lightSurfaceColor = Colors.grey.shade100;
  static final Color _lightBackgroundColor = Colors.grey.shade50;
  static final Color _lightCardColor = Colors.white;
  static final Color _lightOnPrimary = Colors.white;
  static final Color _lightOnSecondary = Colors.white;
  static final Color _lightOnSurface = Colors.black87;
  static final Color _lightOnBackground = Colors.black87;
  static final Color _lightErrorColor = Colors.red.shade700;
  static final Color _lightOnError = Colors.white;
  static final Color _lightInverseSurface = Colors.grey.shade800;
  static final Color _lightOnInverseSurface = Colors.white;

  // --- Dark Theme Colors (from your provided main.dart) ---
  static final Color _darkPrimaryColor = Colors.deepPurple.shade300;
  static final Color _darkSecondaryColor = Colors.teal.shade300;
  static final Color _darkSurfaceColor = Colors.grey.shade800;
  static final Color _darkSurfaceVariantColor = Colors.grey.shade700;
  static final Color _darkBackgroundColor = Colors.grey.shade900;
  static final Color _darkCardColor = Colors.grey.shade800;
  static final Color _darkOnPrimary = Colors.black;
  static final Color _darkOnSecondary = Colors.black;
  static final Color _darkOnSurface = Colors.white;
  static final Color _darkOnBackground = Colors.white; // Added missing color
  static final Color _darkOnSurfaceVariant = Colors.white70;
  static final Color _darkErrorColor = Colors.red.shade400;
  static final Color _darkOnError = Colors.black;
  static final Color _darkInverseSurface = Colors.grey.shade300;
  static final Color _darkOnInverseSurface = Colors.black;

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _lightPrimaryColor,
    scaffoldBackgroundColor: _lightBackgroundColor,
    colorScheme: ColorScheme.light(
      primary: _lightPrimaryColor,
      secondary: _lightSecondaryColor,
      surface: _lightSurfaceColor,
      surfaceVariant: Colors.grey.shade200,
      onPrimary: _lightOnPrimary,
      onSecondary: _lightOnSecondary,
      onSurface: _lightOnSurface,
      onSurfaceVariant: Colors.black54,
      background: _lightBackgroundColor,
      error: _lightErrorColor,
      onError: _lightOnError,
      inverseSurface: _lightInverseSurface,
      onInverseSurface: _lightOnInverseSurface,
    ),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightSurfaceColor,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: _lightOnSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: _lightOnSurface),
    ),
    textTheme: TextTheme(
      bodyLarge: GoogleFonts.poppins(color: _lightOnBackground),
      bodyMedium: GoogleFonts.poppins(
        color: _lightOnBackground.withOpacity(0.85),
      ),
      titleLarge: GoogleFonts.poppins(
        color: _lightOnBackground,
        fontWeight: FontWeight.bold,
      ),
    ).apply(bodyColor: _lightOnBackground, displayColor: _lightOnBackground),
    dialogTheme: DialogThemeData(
      backgroundColor: _lightCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _lightOnSurface,
      ),
      contentTextStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: _lightOnSurface.withOpacity(0.85),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1, // Subtle elevation for light theme
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _lightCardColor,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: _lightOnPrimary,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightSecondaryColor,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurfaceColor,
      hintStyle: GoogleFonts.poppins(color: _lightOnSurface.withOpacity(0.5)),
      labelStyle: GoogleFonts.poppins(color: _lightPrimaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightErrorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightErrorColor, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade300,
      selectedColor: _lightPrimaryColor,
      labelStyle: GoogleFonts.poppins(
        color: _lightOnSurface,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: GoogleFonts.poppins(
        color: _lightOnPrimary,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      iconTheme: IconThemeData(color: _lightOnPrimary, size: 16),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _darkPrimaryColor,
    scaffoldBackgroundColor: _darkBackgroundColor,
    colorScheme: ColorScheme.dark(
      primary: _darkPrimaryColor,
      secondary: _darkSecondaryColor,
      surface: _darkSurfaceColor,
      surfaceVariant: _darkSurfaceVariantColor,
      onPrimary: _darkOnPrimary,
      onSecondary: _darkOnSecondary,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
      background: _darkBackgroundColor,
      error: _darkErrorColor,
      onError: _darkOnError,
      inverseSurface: _darkInverseSurface,
      onInverseSurface: _darkOnInverseSurface,
    ),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: _darkSurfaceColor,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: _darkOnSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: _darkOnSurface),
    ),
    textTheme: TextTheme(
      bodyLarge: GoogleFonts.poppins(color: _darkOnBackground),
      bodyMedium: GoogleFonts.poppins(
        color: _darkOnBackground.withOpacity(0.85),
      ),
      titleLarge: GoogleFonts.poppins(
        color: _darkOnBackground,
        fontWeight: FontWeight.bold,
      ),
    ).apply(bodyColor: _darkOnBackground, displayColor: _darkOnBackground),
    dialogTheme: DialogThemeData(
      backgroundColor: _darkSurfaceColor, // Use surface for dialogs
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkOnSurface,
      ),
      contentTextStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: _darkOnSurface.withOpacity(0.85),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _darkCardColor, // Use card color
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimaryColor,
        foregroundColor: _darkOnPrimary,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _darkSecondaryColor,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceVariantColor, // Slightly different from surface
      hintStyle: GoogleFonts.poppins(color: _darkOnSurface.withOpacity(0.5)),
      labelStyle: GoogleFonts.poppins(
        color: _darkPrimaryColor,
      ), // Use primary for label
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: _darkSurfaceVariantColor.withAlpha(150),
        ), // Subtle border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkErrorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkErrorColor, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _darkSurfaceVariantColor,
      selectedColor: _darkPrimaryColor,
      labelStyle: GoogleFonts.poppins(
        color: _darkOnSurface,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: GoogleFonts.poppins(
        color: _darkOnPrimary,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      iconTheme: IconThemeData(color: _darkOnPrimary, size: 16),
    ),
  );
}
