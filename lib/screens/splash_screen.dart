import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  // Background sweep animation
  late AnimationController _bgController;
  late Animation<Alignment> _bgAlignment;

  // Subtle glow pulse for the logo tile
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    debugPrint('SplashScreen: initState called');
    _setupAnimations();
    _checkAuthStatus();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // Scale animation with overshoot for "pop" effect
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    ));

    // Rotation animation - spins 360 degrees as it appears
    _rotationAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));

    _glowPulse = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Background controller runs independently and loops
    _bgController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _bgAlignment = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(
      parent: _bgController,
      curve: Curves.easeInOut,
    ));

    _bgController.repeat(reverse: true);
  }

  Future<void> _checkAuthStatus() async {
    debugPrint('SplashScreen: Starting auth check');
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      try {
        debugPrint('SplashScreen: Checking auth service');
        final authService = Provider.of<AuthService>(context, listen: false);
        
        if (authService.isAuthenticated) {
          debugPrint('SplashScreen: User is authenticated, going to home');
          context.go('/home');
        } else {
          debugPrint('SplashScreen: User not authenticated, going to onboarding');
          // Always go to onboarding first, then user can choose login/register
          context.go('/onboarding');
        }
      } catch (e) {
        debugPrint('Auth check error: $e');
        // If there's an error, go to onboarding anyway
        debugPrint('SplashScreen: Error occurred, going to onboarding');
        context.go('/onboarding');
      }
    } else {
      debugPrint('SplashScreen: Widget not mounted, skipping navigation');
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final Alignment begin = _bgAlignment.value;
          final Alignment end = Alignment(-begin.x, -begin.y);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [Color(0xFF0D47A1), Color(0xFF002171)],
                begin: begin,
                end: end,
              ),
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  // Clamp scale to prevent overshooting too much
                  final double scaleValue = _scaleAnimation.value > 1.0 
                      ? 1.0 + (_scaleAnimation.value - 1.0) * 0.3 
                      : _scaleAnimation.value;
                  
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: scaleValue,
                      child: RotationTransition(
                        turns: AlwaysStoppedAnimation(_rotationAnimation.value),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12 + 0.12 * _glowPulse.value),
                                blurRadius: 20 + 10 * _glowPulse.value,
                                spreadRadius: 1 + 2 * _glowPulse.value,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.link,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                      )),
                      child: const Text(
                        'Linkly',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                      )),
                      child: const Text(
                        'Digital Business Cards',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
