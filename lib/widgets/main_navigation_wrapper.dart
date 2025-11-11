import 'dart:ui';
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

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _NavDestination(
      label: 'Connections',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    _NavDestination(
      label: 'Groups',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
    ),
    _NavDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
    _NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

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
    final mediaQuery = MediaQuery.of(context);
    final bool isCompactWidth = mediaQuery.size.width <= 360;
    final double horizontalPadding = isCompactWidth ? 12 : 18;
    final double topPadding = isCompactWidth ? 6 : 10;
    final double bottomPadding =
        (mediaQuery.viewPadding.bottom > 0 ? 8 : 0) + (isCompactWidth ? 6 : 12);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark.withOpacity(0.9),
                  AppColors.primary.withOpacity(0.65),
                  AppColors.grey900.withOpacity(0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.22),
                  blurRadius: 36,
                  offset: const Offset(0, 26),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark.withOpacity(0.68),
                        AppColors.primary.withOpacity(0.54),
                        AppColors.grey900.withOpacity(0.72),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                  child: _GlassNavigationBar(
                    destinations: _destinations,
                    selectedIndex: _selectedIndex,
                    onTap: _onTabTapped,
                  ),
                ),
              ),
            ),
          ),
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

class _GlassNavigationBar extends StatelessWidget {
  final List<_NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _GlassNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 360;
        final double itemWidth = constraints.maxWidth / destinations.length;
        final double indicatorWidth = itemWidth * (isCompact ? 0.78 : 0.82);
        final double barHeight = isCompact ? 68 : 76;
        final double indicatorHeight = isCompact ? 50 : 56;
        final double indicatorTop = isCompact ? 8 : 10;
        final double indicatorRadius = isCompact ? 20 : 22;

        return SizedBox(
          height: barHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutQuint,
                left: (itemWidth * selectedIndex) + ((itemWidth - indicatorWidth) / 2),
                top: indicatorTop,
                child: Container(
                  width: indicatorWidth,
                  height: indicatorHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(indicatorRadius),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.55),
                        AppColors.primaryLight.withOpacity(0.45),
                        AppColors.primary.withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
              ),
              Row(
                children: List.generate(destinations.length, (index) {
                  final destination = destinations[index];
                  return Expanded(
                    child: _NavButton(
                      destination: destination,
                      selected: index == selectedIndex,
                      onTap: () => onTap(index),
                      isCompact: isCompact,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool isCompact;

  const _NavButton({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
          onTap: onTap,
          splashColor: AppColors.primary.withOpacity(0.2),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: isCompact ? 10 : 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  padding: EdgeInsets.all(
                    selected
                        ? (isCompact ? 7 : 8)
                        : (isCompact ? 5 : 6),
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.primaryLight.withOpacity(0.18)
                        : AppColors.grey800.withOpacity(0.48),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryLight.withOpacity(0.35),
                              blurRadius: isCompact ? 18 : 22,
                              offset: Offset(0, isCompact ? 10 : 12),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedScale(
                    scale: selected ? 1.08 : 0.96,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: Icon(
                      selected ? destination.activeIcon : destination.icon,
                      color: selected ? AppColors.white : AppColors.grey200,
                      size: selected
                          ? (isCompact ? 24 : 26)
                          : (isCompact ? 21 : 23),
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 6 : 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontSize: selected
                        ? (isCompact ? 12.5 : 13)
                        : (isCompact ? 11.5 : 12),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.3,
                    color: selected ? AppColors.white : AppColors.grey300,
                  ),
                  child: Text(destination.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
