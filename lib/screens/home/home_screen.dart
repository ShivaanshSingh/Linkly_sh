import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../services/notification_service.dart';
import '../../models/post_model.dart';
import '../connections/connections_screen.dart';
import '../groups/groups_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/digital_card_widget.dart';
import '../connections/qr_scanner_screen.dart';
import '../../widgets/create_post_modal.dart';
import '../../widgets/status_stories_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeDashboard(),
    const ConnectionsScreen(),
    const GroupsScreen(),
    const ProfileEditScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      
      if (authService.isAuthenticated && authService.user != null) {
        // Initialize notifications
        await notificationService.initialize();
        
        // Save FCM token to user's document
        await notificationService.saveTokenToFirestore(authService.user!.uid);
        
        debugPrint('🔔 Notifications initialized for user: ${authService.user!.uid}');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey500,
        items: [
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
    );
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with TickerProviderStateMixin {
  int _selectedTab = 0; // 0 for Feeds, 1 for Digital Card
  late AnimationController _tabAnimationController;
  late AnimationController _slideAnimationController;
  double _pageOffset = 0.0; // Track page scroll position for smooth indicator animation (0.0 = Feeds, 1.0 = Digital Card)
  late ScrollController _scrollController;
  double _scrollOffset = 0.0; // Track scroll position for fade effect

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    // Load posts when the widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final postService = Provider.of<PostService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      postService.getPosts(currentUserId: authService.user?.uid);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0E1624), // Beautiful Light Blue Background
      appBar: AppBar(
        backgroundColor: Color(0xFF101B2D), // Clean White App Bar
        elevation: 0,
        surfaceTintColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Linkly',
          style: TextStyle(
            color: AppColors.primaryDark, // Dark Blue Text
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          // Debug button to refresh user data
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary), // Medium Blue
            onPressed: () {
              final authService = Provider.of<AuthService>(context, listen: false);
              authService.refreshUserData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User data refreshed'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Refresh User Data',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Content area that slides horizontally - takes full screen
            GestureDetector(
                onHorizontalDragUpdate: (details) {
                  // Only handle horizontal drag if not actively scrolling vertically
                  if (_scrollController.hasClients && _scrollController.offset > 10) {
                    return;
                  }
                  final screenWidth = MediaQuery.of(context).size.width;
                  final delta = details.delta.dx / screenWidth;
                  setState(() {
                    _pageOffset = (_pageOffset - delta).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (details) {
                  // Only handle horizontal drag end if not actively scrolling vertically
                  if (_scrollController.hasClients && _scrollController.offset > 10) {
                    return;
                  }
                  final velocity = details.primaryVelocity ?? 0;
                  final threshold = 0.5;
                  
                  int targetTab;
                  double targetOffset;
                  
                  if (velocity < -500 || _pageOffset > threshold) {
                    // Swipe left or past threshold -> Digital Card
                    targetTab = 1;
                    targetOffset = 1.0;
                  } else if (velocity > 500 || _pageOffset < (1 - threshold)) {
                    // Swipe right or past threshold -> Feeds
                    targetTab = 0;
                    targetOffset = 0.0;
                  } else {
                    // Snap to nearest
                    targetTab = _pageOffset >= threshold ? 1 : 0;
                    targetOffset = targetTab.toDouble();
                  }
                  
                  setState(() {
                    _selectedTab = targetTab;
                  });
                  
                  // Animate smoothly to target offset
                  final startOffset = _pageOffset;
                  _slideAnimationController.reset();
                  final animation = Tween<double>(begin: startOffset, end: targetOffset).animate(
                    CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOutCubic),
                  );
                  animation.addListener(() {
                    setState(() {
                      _pageOffset = animation.value;
                    });
                  });
                  _slideAnimationController.forward();
                  _tabAnimationController.forward().then((_) { 
                    _tabAnimationController.reset(); 
                  });
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    // Calculate horizontal offset: 0 = Feeds visible, -screenWidth = Digital Card visible
                    final horizontalOffset = -_pageOffset * screenWidth;
                    
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Feeds content - slides left when swiping right
                        Transform.translate(
                          offset: Offset(horizontalOffset, 0),
                          child: SizedBox(
                            width: screenWidth,
                            height: constraints.maxHeight,
                            child: _buildFeedsContentWrapper(),
                          ),
                        ),
                        // Digital Card content - slides in from right when swiping left
                        Transform.translate(
                          offset: Offset(horizontalOffset + screenWidth, 0),
                          child: SizedBox(
                            width: screenWidth,
                            height: constraints.maxHeight,
                            child: _buildDigitalCardContentWrapper(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            // Header, status, and tabs overlay on top (fade on scroll in Feeds mode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: _selectedTab == 0 
                    ? (1.0 - (_scrollOffset / 100).clamp(0.0, 1.0))
                    : 1.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const StatusStoriesWidget(),
                    const SizedBox(height: 6),
                    _buildTabBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              heroTag: 'fab_create_post',
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const CreatePostModal(),
                );
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Get the first name from the user's full name
        String firstName = 'User';
        if (authService.userModel != null && authService.userModel!.fullName.isNotEmpty) {
          firstName = authService.userModel!.fullName.split(' ').first;
          debugPrint('✅ Using userModel fullName: ${authService.userModel!.fullName}');
        } else if (authService.user != null && authService.user!.displayName != null && authService.user!.displayName!.isNotEmpty) {
          firstName = authService.user!.displayName!.split(' ').first;
          debugPrint('✅ Using Firebase user displayName: ${authService.user!.displayName}');
        } else {
          debugPrint('❌ No user name found - userModel: ${authService.userModel?.fullName}, Firebase user: ${authService.user?.displayName}');
        }
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $firstName!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark, // Dark Blue
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ready to connect today?',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.primary, // Medium Blue
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Notification bell
              Consumer<NotificationService>(
                builder: (context, notificationService, child) {
                  return Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight, // Light Blue
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.white, size: 20), // White Icon
                          onPressed: () => context.go('/notifications'),
                        ),
                      ),
                      if (notificationService.hasUnreadNotifications)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              // Profile picture
              GestureDetector(
                onTap: () => _navigateToProfileEdit(),
                child: Consumer<AuthService>(
                  builder: (context, authService, child) {
                    final profileImageUrl = authService.userModel?.profileImageUrl ?? 
                                         authService.user?.photoURL;
                    
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary, // Medium Blue
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2), // White Border
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: profileImageUrl != null 
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
      },
    );
  }


  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white, // Clean White Background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight, width: 1), // Light Blue Border
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;
          final indicatorPosition = _pageOffset.clamp(0.0, 1.0) * tabWidth;
          
          return Stack(
            children: [
              // Sliding indicator background that follows swipe
              Positioned(
                left: indicatorPosition,
                top: 4,
                bottom: 4,
                child: Container(
                  width: tabWidth,
                  decoration: BoxDecoration(
                    color: AppColors.secondary, // Orange
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Tab buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _switchToTab(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 100),
                          style: TextStyle(
                            color: _pageOffset < 0.5 ? AppColors.white : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          child: const Text(
                            'Feeds',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _switchToTab(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 100),
                          style: TextStyle(
                            color: _pageOffset >= 0.5 ? AppColors.white : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          child: const Text(
                            'Digital Card',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _switchToTab(int index) {
    setState(() {
      _selectedTab = index;
    });
    // Animate _pageOffset smoothly
    final targetOffset = index.toDouble();
    final startOffset = _pageOffset;
    _slideAnimationController.reset();
    final animation = Tween<double>(begin: startOffset, end: targetOffset).animate(
      CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOutCubic),
    );
    animation.addListener(() {
      setState(() {
        _pageOffset = animation.value;
      });
    });
    _slideAnimationController.forward();
    _tabAnimationController.forward().then((_) {
      _tabAnimationController.reset();
    });
  }


  // Wrapper around feeds content (only posts list, no headers)
  Widget _buildFeedsContentWrapper() {
    return Consumer<PostService>(
      builder: (context, postService, child) {
        if (postService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (postService.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.grey400),
                const SizedBox(height: 16),
                Text('Error loading posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.grey900)),
                const SizedBox(height: 8),
                Text(postService.error!, style: TextStyle(fontSize: 14, color: AppColors.grey600), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    postService.getPosts(currentUserId: authService.user?.uid);
                  },
                  child: const Text('Retry'),
                )
              ],
            ),
          );
        }
        
        return ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: [
            // Spacer for header height - allows posts to scroll to top
            SizedBox(
              height: 280, // Header + status + tabs height with extra clearance
            ),
            // Posts section or empty state
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: postService.posts.isEmpty
                  ? _buildEmptyPostsState()
                  : Column(
                      children: postService.posts
                          .map((post) => _buildFeedPost(post, postService.posts.indexOf(post)))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  // Wrapper around digital card content (only card content, no headers)
  Widget _buildDigitalCardContentWrapper() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 280), // Match header height for consistency
      child: _buildDigitalCardContent(),
    );
  }

  

  Widget _buildEmptyPostsState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Posts Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something with your network!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.grey400,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CreatePostModal(),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPost(PostModel post, int index) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.user?.uid;
    final isLiked = currentUserId != null ? post.isLikedBy(currentUserId) : false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    post.userAvatar.isNotEmpty ? post.userAvatar[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        post.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: AppColors.grey600),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
          // Post content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:               Text(
                post.content,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.grey600,
                  height: 1.4,
                ),
              ),
          ),
          
          // Post image (if available)
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: AppColors.grey100,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: AppColors.grey100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 50,
                              color: AppColors.grey400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: AppColors.grey600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Engagement metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(index),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? AppColors.error : AppColors.grey400,
                          size: 16,
                          key: ValueKey(isLiked),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          '${post.likes.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLiked ? AppColors.error : AppColors.grey400,
                            fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                          ),
                          key: ValueKey('${post.likes.length}_$isLiked'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showCommentsModal(post),
                  child: Row(
                    children: [
                      Icon(Icons.comment_outlined, color: AppColors.grey400, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentsCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _sharePost(post),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: AppColors.grey400, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${post.shares.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDigitalCardContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Digital Business Card',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark, // Dark Blue
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share your professional identity in style',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary, // Medium Blue
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Digital Card Widget
          const DigitalCardWidget(),
          
          const SizedBox(height: 20),
          
          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scan QR Button - Floating style above Share and vCard
                Container(
                  width: 120,
                  height: 52,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary, // Orange background
                    borderRadius: BorderRadius.circular(26), // Pill shape
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () {
                        _showQRCode();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner,
                            color: AppColors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Scan QR',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Action buttons - only Share and vCard
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Share button (white background with blue text)
                    Expanded(
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white, // Clean White Background
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryLight, width: 1), // Light Blue Border
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryLight.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _shareDigitalCard();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.share,
                                  color: AppColors.primary, // Medium Blue
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Share',
                                  style: TextStyle(
                                    color: AppColors.primary, // Medium Blue
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // vCard button (white background with orange text)
                    Expanded(
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white, // Clean White Background
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondaryLight, width: 1), // Golden Yellow Border
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondaryLight.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _generateVCard();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.contact_page,
                                  color: AppColors.secondary, // Orange
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'vCard',
                                  style: TextStyle(
                                    color: AppColors.secondary, // Orange
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey100, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey100.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.grey700,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Like functionality
  void _toggleLike(int index) {
    final postService = Provider.of<PostService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.user?.uid;
    
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts')),
      );
      return;
    }
    
    final post = postService.posts[index];
    postService.toggleLike(post.id, currentUserId);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          post.isLikedBy(currentUserId) 
            ? 'Unliked ${post.userName}\'s post' 
            : 'Liked ${post.userName}\'s post'
        ),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Comment functionality
  void _showCommentsModal(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(post: post),
    );
  }

  // Share functionality
  void _sharePost(PostModel post) {
    final postService = Provider.of<PostService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.user?.uid;
    
    if (currentUserId != null) {
      postService.sharePost(post.id, currentUserId);
    }
    
    // Show share options
    showModalBottomSheet(
      context: context,
      builder: (context) => ShareModal(post: post),
    );
  }

  // Navigate to profile edit
  void _navigateToProfileEdit() {
    context.push('/profile-edit');
  }

  // Share digital card functionality
  void _shareDigitalCard() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userModel = authService.userModel;
    final user = authService.user;
    
    if (userModel == null && user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User information not available')),
      );
      return;
    }
    
    final userName = userModel?.fullName ?? user?.displayName ?? 'User';
    final userEmail = userModel?.email ?? user?.email ?? '';
    final userId = user?.uid ?? '';
    
    // Create shareable content
    final shareText = '''
🌟 Check out my digital business card!

👤 Name: $userName
📧 Email: $userEmail
🔗 Profile: linkly://user/$userId

Download Linkly to connect with me digitally!
''';
    
    Share.share(
      shareText,
      subject: 'My Digital Business Card - $userName',
    );
  }

  // Generate vCard functionality
  void _generateVCard() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userModel = authService.userModel;
    final user = authService.user;
    
    if (userModel == null && user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User information not available')),
      );
      return;
    }
    
    final userName = userModel?.fullName ?? user?.displayName ?? 'User';
    final userEmail = userModel?.email ?? user?.email ?? '';
    final userPhone = userModel?.phoneNumber ?? '';
    final userCompany = userModel?.company ?? '';
    final userPosition = userModel?.position ?? '';
    
    // Generate vCard content
    final vCardContent = '''BEGIN:VCARD
VERSION:3.0
FN:$userName
N:${userName.split(' ').last};${userName.split(' ').first};;;
EMAIL:$userEmail
${userPhone.isNotEmpty ? 'TEL:$userPhone' : ''}
${userCompany.isNotEmpty ? 'ORG:$userCompany' : ''}
${userPosition.isNotEmpty ? 'TITLE:$userPosition' : ''}
URL:linkly://user/${user?.uid ?? ''}
END:VCARD''';
    
    // Share the vCard
    Share.share(
      vCardContent,
      subject: 'Contact Card - $userName',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('vCard for $userName generated successfully!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showQRCode() {
    // Show QR code in a dialog or navigate to QR screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(),
      ),
    );
  }


}

// Comments Modal
class CommentsModal extends StatefulWidget {
  final PostModel post;

  const CommentsModal({super.key, required this.post});

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.grey900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.grey600),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Comments list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          comment['avatar'],
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment['name'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.grey900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  comment['time'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grey600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment['content'],
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              border: Border(top: BorderSide(color: AppColors.grey200)),
            ),
            child: Row(
              children: [
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    final currentUser = authService.userModel;
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        currentUser?.fullName?.isNotEmpty == true ? currentUser!.fullName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(color: AppColors.grey500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addComment,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: AppColors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addComment() {
    if (_commentController.text.trim().isNotEmpty) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.userModel;
      
      setState(() {
        _comments.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': currentUser?.fullName ?? 'User',
          'avatar': currentUser?.fullName?.isNotEmpty == true ? currentUser!.fullName[0].toUpperCase() : 'U',
          'content': _commentController.text.trim(),
          'time': 'now',
        });
      });
      _commentController.clear();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

// Share Modal
class ShareModal extends StatelessWidget {
  final PostModel post;

  const ShareModal({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Text(
            'Share Post',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.grey900,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Share options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.copy,
                label: 'Copy Link',
                onTap: () {
                  Navigator.pop(context);
                  // Copy post content to clipboard
                  final shareText = 'Check out this post by ${post.userName}: "${post.content}"';
                  Share.share(shareText);
                },
              ),
              _ShareOption(
                icon: Icons.message,
                label: 'Message',
                onTap: () {
                  Navigator.pop(context);
                  final shareText = 'Check out this post by ${post.userName}: "${post.content}"';
                  Share.share(shareText, subject: 'Shared from Linkly');
                },
              ),
              _ShareOption(
                icon: Icons.email,
                label: 'Email',
                onTap: () {
                  Navigator.pop(context);
                  final shareText = 'Check out this post by ${post.userName}: "${post.content}"';
                  Share.share(shareText, subject: 'Shared from Linkly');
                },
              ),
              _ShareOption(
                icon: Icons.more_horiz,
                label: 'More',
                onTap: () {
                  Navigator.pop(context);
                  final shareText = 'Check out this post by ${post.userName}: "${post.content}"';
                  Share.share(shareText, subject: 'Shared from Linkly');
                },
              ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}