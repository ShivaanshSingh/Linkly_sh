import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';

class DigitalCardWidget extends StatefulWidget {
  const DigitalCardWidget({super.key});

  @override
  State<DigitalCardWidget> createState() => _DigitalCardWidgetState();
}

class _DigitalCardWidgetState extends State<DigitalCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFlipped) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final userName = authService.userModel?.fullName ?? 
                        authService.user?.displayName ?? 
                        'User';
        
        return GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final isShowingFront = _animation.value < 0.5;
              final rotation = _animation.value * 3.14159; // 180 degrees in radians
              
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(rotation),
                child: isShowingFront ? _buildFrontCard(userName) : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159), // Flip the back card to correct orientation
                  child: _buildBackCard(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFrontCard(String userName) {
    return Container(
      width: double.infinity,
      height: 270, // Reverted back to original height
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(
        maxWidth: 400,
      ),
      decoration: BoxDecoration(
        color: AppColors.white, // Clean White Background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content - Centered text
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Username
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark, // Dark Blue
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Email
                  Consumer<AuthService>(
                    builder: (context, authService, child) {
                      final email = authService.userModel?.email ?? authService.user?.email ?? '';
                      
                      return Text(
                        'Email $email',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary, // Medium Blue
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tap instruction
                  Text(
                    'TAP FOR QR CODE',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary, // Orange
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // User Profile Picture - Top left corner
          Positioned(
            top: 16,
            left: 16,
            child: Consumer<AuthService>(
              builder: (context, authService, child) {
                final profileImageUrl = authService.userModel?.profileImageUrl ?? 
                                     authService.user?.photoURL;
                
                return CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary, // Medium Blue
                  backgroundImage: profileImageUrl != null 
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl == null
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white, // White Text
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
          
          // Green dot (top left) - moved down to avoid overlap
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Container(
      width: double.infinity,
      height: 270, // Reverted back to original height
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(
        maxWidth: 400,
      ),
      decoration: BoxDecoration(
        color: AppColors.white, // Clean White Background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code - bigger size
            Container(
              width: 160,
              height: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryLight, width: 1), // Light Blue Border
              ),
              child: Center(
                child: Consumer<AuthService>(
                  builder: (context, authService, child) {
                    final userId = authService.user?.uid ?? '';
                    final qrData = userId.isNotEmpty ? 'linkly://user/$userId' : 'linkly://user/unknown';
                    
                    return QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 140,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Tap to flip back instruction - smaller padding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight, // Light Blue Background
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Tap to flip back',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.white, // White Text
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
