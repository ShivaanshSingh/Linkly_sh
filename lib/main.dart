import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/post_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/profile/profile_edit_screen.dart';
import 'screens/people/people_search_screen.dart';
import 'screens/network/network_screen.dart';
import 'screens/connections/connections_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'widgets/main_navigation_wrapper.dart';
import 'screens/people_around_screen.dart';
import 'screens/posts/posts_screen.dart';
import 'screens/status/status_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'constants/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      // Initialize Firebase only if not already initialized
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Firebase Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      
      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      
      firebaseInitialized = true;
      debugPrint('✅ Firebase initialized successfully');
    } else {
      // Firebase is already initialized
      firebaseInitialized = true;
      debugPrint('✅ Firebase already initialized');
    }
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('❌ Continuing without Firebase authentication...');
    firebaseInitialized = false;
  }
  
  runApp(LinklyApp(firebaseInitialized: firebaseInitialized));
}

class LinklyApp extends StatelessWidget {
  final bool firebaseInitialized;
  
  const LinklyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(firebaseInitialized: firebaseInitialized)),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => PostService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp.router(
            title: 'Linkly',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: _createRouter(authService),
          );
        },
      ),
    );
  }
}

GoRouter _createRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final bool isAuthenticated = authService.isAuthenticated;
      final bool isLoading = authService.isLoading;
      final String currentPath = state.uri.toString();

      debugPrint('🔄 Router redirect: $currentPath');
      debugPrint('🔄 Auth state: isAuthenticated=$isAuthenticated, isLoading=$isLoading');

      // Don't redirect if we're on splash screen or if loading
      if (currentPath == '/splash' || isLoading) {
        return null;
      }

      // List of routes accessible to unauthenticated users
      final bool isAuthRoute = currentPath == '/login' || currentPath == '/register' || currentPath == '/onboarding';

      // If not authenticated
      if (!isAuthenticated) {
        // If trying to access a protected route, redirect to onboarding
        if (!isAuthRoute) {
          debugPrint('🔄 Not authenticated, redirecting to onboarding');
          return '/onboarding';
        }
        // If already on an auth route, allow it
        return null;
      }
      // If authenticated
      else {
        // If authenticated and on an auth route, redirect to home
        if (isAuthRoute) {
          debugPrint('🔄 Authenticated, redirecting to home');
          return '/home';
        }
        // If authenticated and on a protected route, allow it
        return null;
      }
    },
    routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/profile-edit',
      builder: (context, state) => const ProfileEditWrapper(),
    ),
    GoRoute(
      path: '/people-search',
      builder: (context, state) => const PeopleSearchScreen(),
    ),
    GoRoute(
      path: '/network',
      builder: (context, state) => const NetworkScreen(),
    ),
    GoRoute(
      path: '/connections',
      builder: (context, state) => const ConnectionsScreen(),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const MessagesScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsWrapper(),
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QRScannerScreen(),
    ),
    GoRoute(
      path: '/people-around',
      builder: (context, state) => const PeopleAroundScreen(),
    ),
    GoRoute(
      path: '/posts',
      builder: (context, state) => const PostsScreen(),
    ),
    GoRoute(
      path: '/status',
      builder: (context, state) => const StatusScreen(),
    ),
    GoRoute(
      path: '/groups',
      builder: (context, state) => const GroupsScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
  );
}