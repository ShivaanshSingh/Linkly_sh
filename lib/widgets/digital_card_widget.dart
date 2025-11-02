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

  String _extractLinkedInUsername(String linkedInUrl) {
    // Extract username from various LinkedIn URL formats
    // Examples: 
    // - https://www.linkedin.com/in/username
    // - www.linkedin.com/in/username
    // - linkedin.com/in/username
    // - /in/username
    // - just username
    
    if (linkedInUrl.isEmpty) return '';
    
    // Remove trailing slash
    linkedInUrl = linkedInUrl.trim().replaceAll(RegExp(r'/$'), '');
    
    // Check if it's just a username (no URL structure)
    if (!linkedInUrl.contains('/') && !linkedInUrl.contains('linkedin')) {
      return linkedInUrl;
    }
    
    // Extract username from /in/username pattern
    final match = RegExp(r'/in/([^/?]+)').firstMatch(linkedInUrl);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? linkedInUrl;
    }
    
    // If no match, return the original (might already be a username)
    return linkedInUrl;
  }

  Widget _buildFrontCard(String userName) {
    return Center(
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(
        maxWidth: 360,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1), // Bright Royal Blue (top-left)
            Color(0xFF002171), // Deep Navy Blue (bottom-right)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B8FAE).withOpacity(0.6), // Dark blue with silverish/metallic tint
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF6B8FAE).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 3.5 / 2.2,
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
                      color: AppColors.textPrimary, // White text for dark gradient background
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Job Title (Position)
                  Consumer<AuthService>(
                    builder: (context, authService, child) {
                      final position = authService.userModel?.position;
                      
                      if (position != null && position.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            position,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox(height: 6);
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Email
                  Consumer<AuthService>(
                    builder: (context, authService, child) {
                      final email = authService.userModel?.email ?? authService.user?.email ?? '';
                      
                      return Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary, // Light gray for secondary text on dark background
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  
                  // LinkedIn Account
                  Consumer<AuthService>(
                    builder: (context, authService, child) {
                      final linkedIn = authService.userModel?.socialLinks['linkedin'];
                      
                      if (linkedIn != null && linkedIn.isNotEmpty) {
                        final linkedInUsername = _extractLinkedInUsername(linkedIn);
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // LinkedIn logo (using badge icon as LinkedIn representation)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'in',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Roboto',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  linkedInUsername,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Tap instruction
                  Text(
                    'TAP FOR QR CODE',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary, // Orange for accent
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
      ),
    ),
    );
  }

  Widget _buildBackCard() {
    return Center(
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(
        maxWidth: 360,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1), // Bright Royal Blue (top-left)
            Color(0xFF002171), // Deep Navy Blue (bottom-right)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B8FAE).withOpacity(0.6), // Dark blue with silverish/metallic tint
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF6B8FAE).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 3.5 / 2.2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR Code - adjusted size to prevent overflow on smaller screens
              Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.white, width: 1), // White border for visibility on dark gradient
                ),
                child: Center(
                  child: Consumer<AuthService>(
                    builder: (context, authService, child) {
                      final userId = authService.user?.uid ?? '';
                      final qrData = userId.isNotEmpty ? 'linkly://user/$userId' : 'linkly://user/unknown';
                      
                      return QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 130,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Tap to flip back instruction - smaller padding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      ),
    ),
    );
  }

}
