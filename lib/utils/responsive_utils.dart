import 'package:flutter/material.dart';

/// Utility class for responsive design across different screen sizes
class ResponsiveUtils {
  // Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  
  /// Get responsive padding based on screen width
  static EdgeInsets getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
  }
  
  /// Get responsive horizontal padding
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 16;
    } else if (width < tabletBreakpoint) {
      return 24;
    }
    return 32;
  }
  
  /// Get responsive vertical padding
  static double getVerticalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 12;
    } else if (width < tabletBreakpoint) {
      return 16;
    }
    return 20;
  }
  
  /// Get responsive spacing (SizedBox height/width)
  static double getSpacing(BuildContext context, {double small = 8, double medium = 12, double large = 16}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width < mobileBreakpoint ? 0.9 : (width < tabletBreakpoint ? 1.0 : 1.1);
    return (small + medium + large) / 3 * scale;
  }
  
  /// Get responsive font size
  static double getFontSize(BuildContext context, {required double baseSize}) {
    final width = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2);
    
    if (width < mobileBreakpoint) {
      return baseSize * 0.95 * textScale;
    } else if (width < tabletBreakpoint) {
      return baseSize * textScale;
    }
    return baseSize * 1.05 * textScale;
  }
  
  /// Get responsive avatar size
  static double getAvatarSize(BuildContext context, {double small = 40, double medium = 50, double large = 60}) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return small;
    } else if (width < tabletBreakpoint) {
      return medium;
    }
    return large;
  }
  
  /// Get responsive icon size
  static double getIconSize(BuildContext context, {double baseSize = 24}) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return baseSize * 0.9;
    } else if (width < tabletBreakpoint) {
      return baseSize;
    }
    return baseSize * 1.1;
  }
  
  /// Get responsive card max width
  static double getCardMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return double.infinity;
    } else if (width < tabletBreakpoint) {
      return 500;
    }
    return 600;
  }
  
  /// Get responsive button height
  static double getButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 44;
    } else if (width < tabletBreakpoint) {
      return 48;
    }
    return 52;
  }
  
  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }
  
  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }
  
  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
  
  /// Get responsive border radius
  static double getBorderRadius(BuildContext context, {double base = 12}) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return base * 0.9;
    } else if (width < tabletBreakpoint) {
      return base;
    }
    return base * 1.1;
  }
}

