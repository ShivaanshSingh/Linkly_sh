import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Beautiful Blue Theme from Coolors Palette
  static const Color primary = Color(0xFF219EBC); // Medium Blue
  static const Color primaryLight = Color(0xFF8ECAE6); // Light Blue
  static const Color primaryDark = Color(0xFF023047); // Dark Blue
  
  // Secondary Colors
  static const Color secondary = Color(0xFFFB8500); // Orange
  static const Color secondaryLight = Color(0xFFFFB703); // Golden Yellow
  static const Color secondaryDark = Color(0xFFE67E00); // Darker Orange
  
  // Accent Colors
  static const Color accent = Color(0xFFFFB703); // Golden Yellow
  static const Color accentLight = Color(0xFFFFD54F); // Light Yellow
  static const Color accentDark = Color(0xFFE6A500); // Darker Yellow
  
  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF8F9FA); // Very Light Grey
  static const Color grey100 = Color(0xFFE9ECEF); // Light Grey
  static const Color grey200 = Color(0xFFDEE2E6); // Medium Light Grey
  static const Color grey300 = Color(0xFFCED4DA); // Medium Grey
  static const Color grey400 = Color(0xFF6C757D); // Medium Dark Grey
  static const Color grey500 = Color(0xFF495057); // Dark Grey
  static const Color grey600 = Color(0xFF343A40); // Darker Grey
  static const Color grey700 = Color(0xFF212529); // Very Dark Grey
  static const Color grey800 = Color(0xFF1A1D20); // Almost Black
  static const Color grey900 = Color(0xFF000000); // Pure Black
  
  // Status Colors
  static const Color success = Color(0xFF219EBC); // Medium Blue
  static const Color warning = Color(0xFFFFB703); // Golden Yellow
  static const Color error = Color(0xFFE53E3E); // Red for liked hearts
  static const Color info = Color(0xFF8ECAE6); // Light Blue
  
  // Background Colors - Beautiful Blue Theme
  static const Color backgroundLight = Color(0xFFF0F8FF); // Very Light Blue
  static const Color backgroundDark = Color(0xFF023047); // Dark Blue
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceDark = Color(0xFF219EBC); // Medium Blue
  
  // Card Theme Colors - Updated with new palette
  static const Color navyCard = Color(0xFF023047); // Dark Blue
  static const Color platinumCard = Color(0xFF8ECAE6); // Light Blue
  static const Color emeraldCard = Color(0xFF219EBC); // Medium Blue
  static const Color amberCard = Color(0xFFFFB703); // Golden Yellow
  static const Color roseCard = Color(0xFFFB8500); // Orange
  static const Color indigoCard = Color(0xFF219EBC); // Medium Blue
  
  // Gradient Colors - Beautiful gradients with new palette
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Additional beautiful gradients
  static const LinearGradient oceanGradient = LinearGradient(
    colors: [Color(0xFF023047), Color(0xFF219EBC), Color(0xFF8ECAE6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFB8500), Color(0xFFFFB703)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
