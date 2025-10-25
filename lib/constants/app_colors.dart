import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Clean Teal/Green Theme from Coolors
  static const Color primary = Color(0xFF22577A); // Deep Teal
  static const Color primaryLight = Color(0xFF38A3A5); // Medium Teal
  static const Color primaryDark = Color(0xFF1A4A6B); // Darker Teal
  
  // Secondary Colors
  static const Color secondary = Color(0xFF57CC99); // Fresh Green
  static const Color secondaryLight = Color(0xFF80ED99); // Light Green
  static const Color secondaryDark = Color(0xFF4AB88A); // Darker Green
  
  // Accent Colors
  static const Color accent = Color(0xFFC7F9CC); // Lightest Green
  static const Color accentLight = Color(0xFFE8FCE8); // Very Light Green
  static const Color accentDark = Color(0xFFB0F5B0); // Light Green
  
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
  static const Color success = Color(0xFF57CC99); // Fresh Green
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE53E3E); // Red for liked hearts
  static const Color info = Color(0xFF38A3A5); // Medium Teal
  
  // Background Colors - Clean Teal/Green Theme
  static const Color backgroundLight = Color(0xFFF0FDF4); // Very Light Green
  static const Color backgroundDark = Color(0xFF22577A); // Deep Teal
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceDark = Color(0xFF38A3A5); // Medium Teal
  
  // Card Theme Colors
  static const Color navyCard = Color(0xFF1E3A8A);
  static const Color platinumCard = Color(0xFFE5E7EB);
  static const Color emeraldCard = Color(0xFF10B981);
  static const Color amberCard = Color(0xFFF59E0B);
  static const Color roseCard = Color(0xFFF43F5E);
  static const Color indigoCard = Color(0xFF6366F1);
  
  // Gradient Colors
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
}
