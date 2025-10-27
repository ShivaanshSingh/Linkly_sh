import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/connection_request_service.dart';
import '../../services/notification_service.dart';
import '../../models/connection_request_model.dart';
import '../../widgets/connection_request_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.grey900),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: AppColors.grey900),
            onSelected: (String value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'All',
                child: Text('All Notifications'),
              ),
              const PopupMenuItem<String>(
                value: 'Connection Requests',
                child: Text('Connection Requests'),
              ),
              const PopupMenuItem<String>(
                value: 'Messages',
                child: Text('Messages'),
              ),
              const PopupMenuItem<String>(
                value: 'Posts',
                child: Text('Posts'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer2<AuthService, NotificationService>(
        builder: (context, authService, notificationService, child) {
          if (authService.user?.uid == null) {
            return const Center(
              child: Text(
                'Please log in to view notifications',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.grey600,
                ),
              ),
            );
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getNotificationsStream(authService.user!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.grey400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.grey600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final allNotifications = snapshot.data ?? [];
              final filteredNotifications = _filterNotifications(allNotifications, _selectedFilter);

              if (filteredNotifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: AppColors.grey400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFilter == 'All' ? 'No new notifications' : 'No $_selectedFilter notifications',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFilter == 'All' ? 'You\'re all caught up!' : 'Try selecting a different filter',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Filter chips
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Connection Requests'),
                        _buildFilterChip('Messages'),
                        _buildFilterChip('Posts'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Notifications list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredNotifications.length,
                      itemBuilder: (context, index) {
                        final notification = filteredNotifications[index];
                        return _buildNotificationCard(notification, notificationService, context);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getNotificationsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  List<Map<String, dynamic>> _filterNotifications(List<Map<String, dynamic>> notifications, String filter) {
    if (filter == 'All') return notifications;
    
    return notifications.where((notification) {
      final type = notification['type'] ?? '';
      switch (filter) {
        case 'Connection Requests':
          return type == 'connection_request';
        case 'Messages':
          return type == 'message';
        case 'Posts':
          return type == 'post_like' || type == 'post_comment' || type == 'post_share';
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(filter),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = filter;
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.grey600,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, NotificationService notificationService, BuildContext context) {
    final type = notification['type'] ?? '';
    final isRead = notification['isRead'] ?? false;
    final timestamp = notification['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null ? _getTimeAgo(timestamp.toDate()) : '';
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? notification['message'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? AppColors.white : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? AppColors.grey200 : AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _handleNotificationTap(notification, context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Notification icon
              _buildNotificationIcon(type),
              const SizedBox(width: 12),
              
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        color: AppColors.grey900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grey600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.grey500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grey500,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.grey500),
                onSelected: (String value) {
                  _handleNotificationAction(value, notification, notificationService);
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Mark as Read'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'connection_request':
        icon = Icons.person_add;
        color = AppColors.primary;
        break;
      case 'message':
        icon = Icons.message;
        color = Colors.blue;
        break;
      case 'post_like':
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case 'post_comment':
        icon = Icons.comment;
        color = Colors.orange;
        break;
      case 'post_share':
        icon = Icons.share;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.grey500;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationAction(String action, Map<String, dynamic> notification, NotificationService notificationService) {
    switch (action) {
      case 'mark_read':
        _markAsRead(notification['id']);
        break;
      case 'delete':
        _deleteNotification(notification['id']);
        break;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification, BuildContext context) {
    final type = notification['type'] ?? '';
    
    // Mark as read
    _markAsRead(notification['id']);

    // Navigate based on notification type
    switch (type) {
      case 'connection_request':
        // Navigate to connections screen
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Go to Connections tab to view the request'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        break;
      case 'message':
        // Navigate to home screen
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Go to Messages tab to view the chat'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        break;
      case 'post_like':
      case 'post_comment':
      case 'post_share':
        // Navigate to home screen
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Go to Home tab to view the post'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        break;
    }
  }

  void _markAsRead(String notificationId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  void _deleteNotification(String notificationId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}