import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';

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
      appBar: AppBar(
        title: const Text('Settings'),
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
                  context.push('/profile-edit');
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
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
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

