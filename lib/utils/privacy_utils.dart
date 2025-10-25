import '../models/user_model.dart';

class PrivacyUtils {
  /// Determines if personal information (email and phone) should be visible
  /// based on the user's account type and connection status
  static bool shouldShowPersonalInfo({
    required String accountType,
    required bool isConnected,
  }) {
    switch (accountType.toLowerCase()) {
      case 'public':
        // Public accounts: personal info visible to connections
        return isConnected;
      case 'private':
        // Private accounts: personal info never visible to connections
        return false;
      default:
        // Default to private behavior for safety
        return false;
    }
  }

  /// Gets the appropriate display text for personal information
  /// Returns the actual info if visible, or a placeholder if not
  static String getPersonalInfoDisplay({
    required String? personalInfo,
    required String accountType,
    required bool isConnected,
    String placeholder = 'Connect to view',
  }) {
    if (shouldShowPersonalInfo(
      accountType: accountType,
      isConnected: isConnected,
    )) {
      return personalInfo ?? '';
    } else {
      return placeholder;
    }
  }

  /// Gets the appropriate icon for personal information visibility
  static String getPersonalInfoIcon({
    required String accountType,
    required bool isConnected,
  }) {
    if (shouldShowPersonalInfo(
      accountType: accountType,
      isConnected: isConnected,
    )) {
      return 'visible';
    } else {
      return 'hidden';
    }
  }
}
