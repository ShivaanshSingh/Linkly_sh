import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/digital_card_themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _showOnlineStatus = true;
  bool _allowConnectionRequests = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _showOnlineStatus = prefs.getBool('show_online_status') ?? true;
      _allowConnectionRequests = prefs.getBool('allow_connection_requests') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
    setState(() {});
  }

  void _openDigitalCardThemePicker(AuthService authService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final currentThemeId = authService.digitalCardTheme;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.grey900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose Digital Card Theme',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...DigitalCardThemes.themes.map((theme) {
                    final isSelected = theme.id == currentThemeId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          if (!isSelected) {
                            await authService.updateDigitalCardTheme(theme.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Digital card theme set to ${theme.name}'),
                                  backgroundColor: AppColors.primary,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 48,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: theme.gradientColors,
                            ),
                            border: Border.all(
                              color: theme.borderColor.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                        ),
                        title: Text(
                          theme.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.secondary,
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: AppColors.grey600,
                              ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout(context, authService);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout(BuildContext context, AuthService authService) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Perform logout
      await authService.signOut();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey900, // Overall Background - matching homepage
      appBar: AppBar(
        backgroundColor: AppColors.grey800, // Sidebar/AppBar Background - matching homepage
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.textPrimary), // Bright White Text
        ),
        actions: [
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _showLogoutDialog(context, authService),
                tooltip: 'Sign Out',
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _SettingsSection(
            title: 'Profile',
            children: [
              _SettingsTile(
                icon: Icons.person,
                title: 'Edit Profile',
                onTap: () {
                  context.push('/profile-edit');
                },
              ),
              _SettingsTile(
                icon: Icons.business_center,
                title: 'Digital Card',
                onTap: () {
                  context.push('/digital-card');
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // App Settings Section
          _SettingsSection(
            title: 'App Settings',
            children: [
              _SwitchSettingsTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Enable app notifications',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _saveSetting('notifications_enabled', value);
                },
              ),
              _SwitchSettingsTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Use dark theme',
                value: _darkMode,
                onChanged: (value) {
                  setState(() {
                    _darkMode = value;
                  });
                  _saveSetting('dark_mode', value);
                },
              ),
              _SwitchSettingsTile(
                icon: Icons.visibility,
                title: 'Show Online Status',
                subtitle: 'Let others see when you\'re online',
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() {
                    _showOnlineStatus = value;
                  });
                  _saveSetting('show_online_status', value);
                },
              ),
              _SwitchSettingsTile(
                icon: Icons.person_add,
                title: 'Allow Connection Requests',
                subtitle: 'Allow others to send connection requests',
                value: _allowConnectionRequests,
                onChanged: (value) {
                  setState(() {
                    _allowConnectionRequests = value;
                  });
                  _saveSetting('allow_connection_requests', value);
                },
              ),
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  final themeName = DigitalCardThemes.nameForId(authService.digitalCardTheme);
                  return _SettingsTile(
                    icon: Icons.palette,
                    title: 'Digital Card Theme',
                    subtitle: themeName,
                    onTap: () => _openDigitalCardThemePicker(authService),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Support Section
          _SettingsSection(
            title: 'Support',
            children: [
              _SettingsTile(
                icon: Icons.help,
                title: 'Help & FAQ',
                onTap: () {
                  // TODO: Navigate to help
                },
              ),
              _SettingsTile(
                icon: Icons.contact_support,
                title: 'Contact Support',
                onTap: () {
                  // TODO: Navigate to contact support
                },
              ),
              _SettingsTile(
                icon: Icons.info,
                title: 'About',
                onTap: () {
                  // TODO: Show about dialog
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Sign Out
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return _SettingsTile(
                icon: Icons.logout,
                title: 'Sign Out',
                textColor: AppColors.error,
                onTap: () => _showLogoutDialog(context, authService),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.grey500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? AppColors.grey600,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppColors.grey900,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.grey600,
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.grey400,
      ),
      onTap: onTap,
    );
  }
}

class _SwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? AppColors.grey600 : AppColors.grey400,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? AppColors.grey900 : AppColors.grey400,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? AppColors.grey600 : AppColors.grey400,
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.primary,
      ),
    );
  }
}

class _RadioSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _RadioSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.grey600,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.grey900,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.grey600,
          fontSize: 12,
        ),
      ),
      trailing: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
        activeColor: AppColors.primary,
      ),
      onTap: () {
        onChanged(value);
      },
    );
  }
}


