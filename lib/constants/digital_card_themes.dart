import 'package:flutter/material.dart';

class DigitalCardThemeData {
  final String id;
  final String name;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;

  const DigitalCardThemeData({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
  });
}

class DigitalCardThemes {
  static const String defaultThemeId = 'sapphire-night';

  static const List<DigitalCardThemeData> themes = [
    DigitalCardThemeData(
      id: 'sapphire-night',
      name: 'Sapphire Night',
      gradientColors: [
        Color(0xFF0D47A1),
        Color(0xFF002171),
      ],
      borderColor: Color(0xFF6B8FAE),
      shadowColor: Color(0xFF0D47A1),
      textPrimaryColor: Colors.white,
      textSecondaryColor: Color(0xFFE0E7FF),
    ),
    DigitalCardThemeData(
      id: 'aurora-sunset',
      name: 'Aurora Sunset',
      gradientColors: [
        Color(0xFFFF7E5F),
        Color(0xFFFD3A84),
      ],
      borderColor: Color(0xFFFF9A8B),
      shadowColor: Color(0xFFFD3A84),
      textPrimaryColor: Color(0xFF2C1A1A),
      textSecondaryColor: Color(0xFF5C3B40),
    ),
    DigitalCardThemeData(
      id: 'emerald-horizon',
      name: 'Emerald Horizon',
      gradientColors: [
        Color(0xFF0BAB64),
        Color(0xFF3BB78F),
      ],
      borderColor: Color(0xFF5DD39E),
      shadowColor: Color(0xFF0BAB64),
      textPrimaryColor: Color(0xFF06251B),
      textSecondaryColor: Color(0xFF0C4B39),
    ),
    DigitalCardThemeData(
      id: 'plum-galaxy',
      name: 'Plum Galaxy',
      gradientColors: [
        Color(0xFF654EA3),
        Color(0xFFEA4C89),
      ],
      borderColor: Color(0xFFD17FFF),
      shadowColor: Color(0xFF654EA3),
      textPrimaryColor: Colors.white,
      textSecondaryColor: Color(0xFFEEDBFF),
    ),
  ];

  static DigitalCardThemeData themeById(String id) {
    return themes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => themes.first,
    );
  }

  static bool isValid(String id) {
    return themes.any((theme) => theme.id == id);
  }

  static String nameForId(String id) {
    return themeById(id).name;
  }
}

