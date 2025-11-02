import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../screens/profile/profile_edit_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainNavigationWrapper extends StatefulWidget {
  final Widget child;
  final int initialIndex;

  const MainNavigationWrapper({
    super.key,
    required this.child,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Home
        context.go('/home');
        break;
      case 1: // Connections
        context.go('/home');
        // Navigate to connections tab within home
        break;
      case 2: // Groups
        context.go('/home');
        // Navigate to groups tab within home
        break;
      case 3: // Profile
        context.push('/profile-edit');
        break;
      case 4: // Settings
        context.push('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primary.withOpacity(0.7),
              AppColors.grey800,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.5),
              blurRadius: 25,
              offset: const Offset(0, -8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.grey400,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(color: AppColors.grey400, fontWeight: FontWeight.w400),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outlined),
              activeIcon: Icon(Icons.people),
              label: 'Connections',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_work_outlined),
              activeIcon: Icon(Icons.group_work),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// Specific wrappers for each screen
class ProfileEditWrapper extends StatelessWidget {
  const ProfileEditWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationWrapper(
      child: ProfileEditScreen(),
      initialIndex: 3, // Profile tab
    );
  }
}

class SettingsWrapper extends StatelessWidget {
  const SettingsWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationWrapper(
      child: SettingsScreen(),
      initialIndex: 4, // Settings tab
    );
  }
}
