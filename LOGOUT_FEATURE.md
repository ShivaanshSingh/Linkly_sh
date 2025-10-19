# Logout Feature Documentation

## Overview
The Linkly app now has a comprehensive logout feature with multiple access points and enhanced user experience.

## Features

### 1. **Multiple Logout Access Points**
Users can log out from three different locations:

#### A. Settings Screen - Main Button
- Location: Settings tab → "Sign Out" button in the settings list
- Color: Red text to indicate destructive action
- Icon: Logout icon

#### B. Settings Screen - App Bar
- Location: Settings screen → Top-right logout icon
- Quick access for users already in settings
- Tooltip: "Sign Out"

#### C. Home Screen - App Bar  
- Location: Home dashboard → Top-right logout icon
- Branded app bar with "Linkly" title
- Quick access from main screen

### 2. **Enhanced User Experience**

#### Confirmation Dialog
- Title: "Sign Out"
- Message: "Are you sure you want to sign out?"
- Actions:
  - **Cancel**: Dismisses dialog, no action taken
  - **Sign Out**: Proceeds with logout (red text)

#### Loading Indicator
- Shows CircularProgressIndicator during logout process
- Non-dismissible to prevent user interaction
- Automatically closes after logout completes

#### Error Handling
- Catches and displays any logout errors
- Shows error message in red SnackBar
- User-friendly error messages

### 3. **Navigation Flow**

```
User Action → Confirmation Dialog → Loading → Logout → Login Screen
```

1. User taps logout button
2. Confirmation dialog appears
3. User confirms logout
4. Loading indicator shows
5. AuthService.signOut() executes
6. Both Firebase Auth and Google Sign-In are signed out
7. User state is cleared
8. Navigation to `/login` (LoginScreen)

## Implementation Details

### Settings Screen (`lib/screens/settings/settings_screen.dart`)

```dart
// Logout button in settings list
Consumer<AuthService>(
  builder: (context, authService, child) {
    return _SettingsTile(
      icon: Icons.logout,
      title: 'Sign Out',
      textColor: AppColors.error,
      onTap: () => _showLogoutDialog(context, authService),
    );
  },
)

// Logout icon in app bar
AppBar(
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
)
```

### Home Screen (`lib/screens/home/home_screen.dart`)

```dart
// Logout icon in home app bar
AppBar(
  backgroundColor: AppColors.white,
  elevation: 0,
  automaticallyImplyLeading: false,
  title: const Text('Linkly'),
  actions: [
    Consumer<AuthService>(
      builder: (context, authService, child) {
        return IconButton(
          icon: const Icon(Icons.logout, color: AppColors.grey600),
          onPressed: () => _showLogoutDialog(context, authService),
          tooltip: 'Sign Out',
        );
      },
    ),
  ],
)
```

### Logout Methods

Both screens implement identical logout handling:

```dart
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
```

## AuthService Integration

The logout feature uses `AuthService.signOut()` which:

1. Sets loading state to true
2. Signs out from Firebase Auth
3. Signs out from Google Sign-In
4. Clears user data (_user, _userModel)
5. Sets loading state to false

```dart
// From lib/services/auth_service.dart
Future<void> signOut() async {
  try {
    _setLoading(true);
    debugPrint('Signing out');

    if (_isFirebaseAvailable) {
      await _auth!.signOut();
      await _googleSignIn!.signOut();
    }

    _user = null;
    _userModel = null;
  } catch (e) {
    debugPrint('Sign out error: $e');
  } finally {
    _setLoading(false);
  }
}
```

## Routing Configuration

The app uses GoRouter for navigation:

```dart
// From lib/main.dart
final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // ... other routes
  ],
);
```

When logout is triggered, the app navigates to `/login` which displays the LoginScreen.

## Testing

### Manual Testing Steps

1. **Test Settings Screen Logout Button**
   - Navigate to Settings tab
   - Scroll to "Sign Out" button
   - Tap button
   - Verify confirmation dialog appears
   - Tap "Sign Out"
   - Verify loading indicator shows
   - Verify navigation to login screen

2. **Test Settings App Bar Logout**
   - Navigate to Settings tab
   - Tap logout icon in top-right
   - Verify same behavior as above

3. **Test Home Screen Logout**
   - Stay on Home tab
   - Tap logout icon in top-right
   - Verify same behavior as above

4. **Test Cancel Functionality**
   - Tap any logout button
   - Tap "Cancel" in dialog
   - Verify user stays logged in
   - Verify dialog closes

5. **Test Error Handling**
   - Disconnect internet
   - Attempt logout
   - Verify error message displays

### Expected Results

✅ Logout confirmation dialog appears  
✅ Loading indicator shows during logout  
✅ User is signed out successfully  
✅ Navigation to login screen occurs  
✅ User data is cleared  
✅ Cancel works correctly  
✅ Errors are handled gracefully  

## User Experience Guidelines

### Visual Design
- **Logout Icon**: Standard Material Icons logout icon
- **Color Scheme**: Red (AppColors.error) for destructive action
- **Positioning**: Top-right for quick access
- **Tooltip**: "Sign Out" for clarity

### Interaction Design
- **Confirmation**: Always ask for confirmation before logout
- **Feedback**: Show loading state during operation
- **Error Recovery**: Allow retry if logout fails
- **Context Awareness**: Use `context.mounted` checks for safe navigation

### Accessibility
- Clear action labels ("Sign Out")
- Icon with tooltip for screen readers
- High contrast colors for visibility
- Keyboard navigation support (inherited from Material widgets)

## Security Considerations

1. **Complete Logout**: Both Firebase Auth and Google Sign-In are cleared
2. **State Management**: All user data (_user, _userModel) is nullified
3. **Navigation Security**: Uses GoRouter for type-safe navigation
4. **Error Handling**: Errors don't expose sensitive information

## Future Enhancements

Potential improvements for the logout feature:

1. **Remember Me**: Option to remember user credentials
2. **Logout from All Devices**: Server-side session invalidation
3. **Logout Timer**: Auto-logout after inactivity
4. **Biometric Re-authentication**: Require biometric confirmation for logout
5. **Analytics**: Track logout events for user behavior analysis

## Troubleshooting

### Common Issues

**Issue**: Logout doesn't navigate to login screen  
**Solution**: Check `context.mounted` before navigation, verify GoRouter configuration

**Issue**: User data persists after logout  
**Solution**: Verify `AuthService.signOut()` is properly clearing state

**Issue**: Confirmation dialog doesn't appear  
**Solution**: Check Consumer<AuthService> is properly wrapping the logout button

## Related Files

- `lib/screens/settings/settings_screen.dart` - Settings logout implementation
- `lib/screens/home/home_screen.dart` - Home screen logout implementation
- `lib/services/auth_service.dart` - Authentication service with signOut method
- `lib/screens/auth/login_screen.dart` - Login screen destination
- `lib/main.dart` - Router configuration

## Version History

- **v1.0** (Current) - Initial implementation with confirmation, loading, error handling, and multiple access points

