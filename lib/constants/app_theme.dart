import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Explicit ColorScheme to prevent system theme interference
  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    secondary: AppColors.secondary,
    onSecondary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textPrimary,
    surfaceVariant: AppColors.grey800,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.grey600,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.grey800,
    onInverseSurface: AppColors.textPrimary,
    inversePrimary: AppColors.primaryLight,
    surfaceTint: AppColors.primary,
  );

  // Explicit text theme with high contrast colors
  static const TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(color: AppColors.textPrimary, fontSize: 57, fontWeight: FontWeight.w400),
    displayMedium: TextStyle(color: AppColors.textPrimary, fontSize: 45, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w400),
    headlineLarge: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w400),
    headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w400),
    headlineSmall: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w400),
    titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme, // Use dark scheme even for "light" theme
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: _darkTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey50,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.grey900,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(color: AppColors.grey400, fontWeight: FontWeight.w400),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: const DividerThemeData(
        color: AppColors.grey600,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _darkTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.grey900,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey800,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.grey600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.grey600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.grey900,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.grey400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(color: AppColors.grey400, fontWeight: FontWeight.w400),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: const DividerThemeData(
        color: AppColors.grey600,
        thickness: 1,
      ),
    );
  }
}
