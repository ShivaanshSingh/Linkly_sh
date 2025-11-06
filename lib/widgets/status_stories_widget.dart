import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../models/status_model.dart';
import '../services/auth_service.dart';
import '../services/status_service.dart';

class StatusStoriesWidget extends StatefulWidget {
  const StatusStoriesWidget({super.key});

  @override
  State<StatusStoriesWidget> createState() => _StatusStoriesWidgetState();
}

class _StatusStoriesWidgetState extends State<StatusStoriesWidget> {
  final StatusService _statusService = StatusService();

  @override
  void initState() {
    super.initState();
    // Opportunistic cleanup to ensure only <24h stories are retained
    _statusService.cleanupExpiredStatuses();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.user?.uid == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<StatusModel>>(
          stream: _statusService.getStatuses(authService.user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 100,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 100,
                child: Center(
                  child: Text(
                    'Error loading statuses',
                    style: TextStyle(
                      color: AppColors.textSecondary, // Muted Gray for Secondary Text
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            final statuses = snapshot.data ?? [];

            return Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: statuses.length + 1, // +1 for "Add Status" button
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAddStatusStory();
                  }
                  
                  final status = statuses[index - 1];
                  return _buildStatusStory(status);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddStatusStory() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final String displayName = authService.userModel?.fullName ?? 'User';
    final String? photoUrl = authService.userModel?.profileImageUrl;

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => context.go('/status'),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.grey300,
                  width: 2,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 100,
                            memCacheHeight: 100,
                            placeholder: (context, url) => _buildDefaultAvatar(displayName),
                            errorWidget: (context, url, error) => _buildDefaultAvatar(displayName),
                          )
                        : _buildDefaultAvatar(displayName),
                  ),
                  Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary, // Muted Gray for Secondary Text
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStory(StatusModel status) {
    final hasNewStatus = _hasNewStatus(status);
    
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showStatusDetail(context, status),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasNewStatus ? AppColors.primary : AppColors.grey300,
                  width: hasNewStatus ? 3 : 2,
                ),
              ),
              child: ClipOval(
                child: status.userProfileImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: status.userProfileImageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 100,
                        memCacheHeight: 100,
                        placeholder: (context, url) => _buildDefaultAvatar(status.userName),
                        errorWidget: (context, url, error) => _buildDefaultAvatar(status.userName),
                      )
                    : _buildDefaultAvatar(status.userName),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getDisplayName(status.userName),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary, // Muted Gray for Secondary Text
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String userName) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  bool _hasNewStatus(StatusModel status) {
    // Consider status as "new" if it was created within the last 2 hours
    final now = DateTime.now();
    final twoHoursAgo = now.subtract(const Duration(hours: 2));
    return status.createdAt.isAfter(twoHoursAgo);
  }

  String _getDisplayName(String userName) {
    if (userName.length <= 8) return userName;
    return '${userName.substring(0, 8)}...';
  }

  void _showStatusDetail(BuildContext context, StatusModel status) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.grey200),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      backgroundImage: status.userProfileImageUrl != null
                          ? NetworkImage(status.userProfileImageUrl!)
                          : null,
                      child: status.userProfileImageUrl == null
                          ? Text(
                              status.userName.isNotEmpty 
                                  ? status.userName[0].toUpperCase() 
                                  : 'U',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.grey900,
                            ),
                          ),
                          Text(
                            _getTimeAgo(status.createdAt),
                            style: const TextStyle(
                              color: AppColors.grey600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status.text != null) ...[
                        Text(
                          status.text!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (status.imageUrl != null)
                        Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.grey100,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: status.imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              memCacheHeight: 600,
                              placeholder: (context, url) => Container(
                                color: AppColors.grey100,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.grey100,
                                child: const Icon(
                                  Icons.image,
                                  color: AppColors.grey400,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
