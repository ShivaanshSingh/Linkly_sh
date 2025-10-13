import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RecentConnections extends StatelessWidget {
  const RecentConnections({super.key});

  @override
  Widget build(BuildContext context) {
    final connections = [
      {
        'name': 'Sarah Johnson',
        'company': 'Design Co.',
        'imageUrl': 'https://via.placeholder.com/40',
        'time': '2 hours ago',
      },
      {
        'name': 'Mike Chen',
        'company': 'Tech Startup',
        'imageUrl': 'https://via.placeholder.com/40',
        'time': '1 day ago',
      },
      {
        'name': 'Emily Davis',
        'company': 'Marketing Pro',
        'imageUrl': 'https://via.placeholder.com/40',
        'time': '2 days ago',
      },
    ];

    return Column(
      children: connections.map((connection) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    connection['imageUrl']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.grey200,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.grey500,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    connection['name']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connection['company']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.grey600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connection['time']!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey500,
                    ),
                  ),
                ],
              ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      // TODO: Open chat
                    },
                    icon: const Icon(
                      Icons.message,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Call
                    },
                    icon: const Icon(
                      Icons.phone,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
