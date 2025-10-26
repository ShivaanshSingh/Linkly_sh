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
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../groups/groups_screen.dart';
import '../connections/qr_scanner_screen.dart';
import '../../widgets/digital_card_widget.dart';
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
    const MessagesScreen(),
    const NotificationsScreen(),
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
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        heroTag: "home_fab",
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const CreatePostModal(),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(
          Icons.add,
          color: AppColors.white,
        ),
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 3) { // Profile tab (now index 3)
            context.push('/profile-edit');
          } else if (index == 4) { // Settings tab (index 4)
            context.push('/settings');
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
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
  late PageController _pageController;
  late AnimationController _tabAnimationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _pageController.dispose();
    _tabAnimationController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Linkly',
          style: TextStyle(
            color: AppColors.grey700,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          // Debug button to refresh user data
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.grey600),
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
        child: Column(
          children: [
            // Header with greeting and profile
            _buildHeader(),
            
            // Status section
            const StatusStoriesWidget(),
            const SizedBox(height: 6),
            
            // Tab Bar
            _buildTabBar(),
            
            // Content with smooth transitions
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                allowImplicitScrolling: false,
                onPageChanged: (index) {
                  setState(() {
                    _selectedTab = index;
                  });
                  _tabAnimationController.forward().then((_) {
                    _tabAnimationController.reset();
                  });
                },
                children: [
                  _buildFeedsContentWrapper(),
                  _buildDigitalCardContentWrapper(),
                ],
              ),
            ),
          ],
        ),
      ),
      // FloatingActionButton removed as requested
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                        color: AppColors.grey700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ready to connect today?',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.grey500,
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
                          color: AppColors.grey50,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.grey600, size: 20),
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
              const SizedBox(width: 12),
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
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
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
                                  color: AppColors.white,
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
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey100, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _switchToTab(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: _selectedTab == 0 ? Colors.white : AppColors.grey500,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: _selectedTab == 1 ? Colors.white : AppColors.grey500,
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
    );
  }

  void _switchToTab(int index) {
    setState(() {
      _selectedTab = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _tabAnimationController.forward().then((_) {
      _tabAnimationController.reset();
    });
  }

  Widget _buildFeedsContentWrapper() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Allow horizontal swipes to pass through to PageView
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0 && _selectedTab > 0) {
            // Swipe right - go to previous page
            _switchToTab(_selectedTab - 1);
          } else if (details.primaryVelocity! < 0 && _selectedTab < 1) {
            // Swipe left - go to next page
            _switchToTab(_selectedTab + 1);
          }
        }
      },
      child: _buildFeedsContent(),
    );
  }

  Widget _buildDigitalCardContentWrapper() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Allow horizontal swipes to pass through to PageView
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0 && _selectedTab > 0) {
            // Swipe right - go to previous page
            _switchToTab(_selectedTab - 1);
          } else if (details.primaryVelocity! < 0 && _selectedTab < 1) {
            // Swipe left - go to next page
            _switchToTab(_selectedTab + 1);
          }
        }
      },
      child: _buildDigitalCardContent(),
    );
  }

  Widget _buildFeedsContent() {
    return Consumer<PostService>(
      builder: (context, postService, child) {
        if (postService.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (postService.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.grey400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  postService.error!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.grey600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    postService.getPosts(currentUserId: authService.user?.uid);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (postService.posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.feed_outlined,
                  size: 64,
                  color: AppColors.grey400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Be the first to share something!',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.grey500,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const CreatePostModal(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    label: const Text(
                      'Create Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const ClampingScrollPhysics(),
          children: [
            // Posts section
            if (postService.posts.isEmpty)
              _buildEmptyPostsState()
            else
              ...postService.posts.map((post) => _buildFeedPost(post, postService.posts.indexOf(post))),
          ],
        );
      },
    );
  }

  Widget _buildEmptyPostsState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'No Posts Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something with your network!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF9CA3AF),
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
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        post.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
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
                  color: Colors.white,
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
                          color: isLiked ? AppColors.error : const Color(0xFF9CA3AF),
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
                            color: isLiked ? AppColors.error : const Color(0xFF9CA3AF),
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
                      Icon(Icons.comment_outlined, color: const Color(0xFF9CA3AF), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentsCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
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
                      Icon(Icons.share_outlined, color: const Color(0xFF9CA3AF), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${post.shares.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Digital Business Card',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the card to reveal your QR code for easy sharing',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grey600,
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick actions
                Column(
                  children: [
                    // Prominent Scan QR button
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFE55A2B)], // Orange gradient
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(28), // Pill shape
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const QRScannerScreen(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Scan QR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Other quick actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickAction(
                          icon: Icons.share,
                          label: 'Share',
                          onTap: () {
                            _shareDigitalCard();
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.contact_page,
                          label: 'vCard',
                          onTap: () {
                            _generateVCard();
                          },
                        ),
                      ],
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