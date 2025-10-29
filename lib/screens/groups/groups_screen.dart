import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey900, // Overall Background - matching homepage
      appBar: AppBar(
        backgroundColor: AppColors.grey800, // Sidebar/AppBar Background - matching homepage
        elevation: 0,
        surfaceTintColor: AppColors.grey800,
        title: const Text(
          'Groups',
          style: TextStyle(
            color: AppColors.textPrimary, // Bright White Text - matching homepage
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        actions: [],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (authService.user?.uid == null) {
            return const Center(
              child: Text(
                'Please log in to view groups',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.grey600,
                ),
              ),
            );
          }

          return Column(
            children: [
              // Search and Filter Section
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.grey900, // Match background
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grey100, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.grey100.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: const TextStyle(
                          color: AppColors.grey900, // Dark text for white background
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search groups by name or description...',
                          hintStyle: const TextStyle(
                            color: AppColors.grey400,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                          filled: true,
                          fillColor: AppColors.white, // Ensure white background
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.grey400,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grey100, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.grey100.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: 'Create New Group',
                          isExpanded: true,
                          items: ['Create New Group']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  const Icon(Icons.add, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    value,
                                    style: const TextStyle(
                                      color: AppColors.grey700,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue == 'Create New Group') {
                              _showCreateGroupDialog();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Groups List
              Expanded(
                child: StreamBuilder<List<GroupModel>>(
                  stream: GroupService.getUserGroups(authService.user!.uid),
                  builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                );
              }

              if (snapshot.hasError) {
                // Handle Firestore index error gracefully - show create group option
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        size: 80,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No groups yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Create a new group to get started!',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateGroupDialog(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Create New Group',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

                    final groups = snapshot.data ?? [];
                    
                    // Apply search and filter
                    List<GroupModel> filteredGroups = groups.where((group) {
                      // Apply search filter
                      if (_searchQuery.isNotEmpty) {
                        if (!group.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
                            !group.description.toLowerCase().contains(_searchQuery.toLowerCase())) {
                          return false;
                        }
                      }
                      
                      return true;
                    }).toList();

                    if (filteredGroups.isEmpty && groups.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppColors.grey400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No groups found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.grey900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try adjusting your search or filter',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (filteredGroups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: AppColors.grey400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No groups yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a group to get started',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.grey500,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => _showCreateGroupDialog(),
                          child: const Text(
                            'Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        return _buildGroupCard(group, authService.userModel!);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupCard(GroupModel group, UserModel currentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Group avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Color(int.parse(group.color.replaceFirst('#', '0xFF'))),
              child: const Icon(
                Icons.group,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: AppColors.grey900,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.description,
                    style: const TextStyle(
                      color: AppColors.grey600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.members.length} members',
                    style: const TextStyle(
                      color: AppColors.grey500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Three dots menu
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.grey500,
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteGroup(group);
                } else if (value == 'rename') {
                  _renameGroup(group);
                } else if (value == 'recolor') {
                  _recolorGroup(group);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'recolor',
                  child: Row(
                    children: [
                      Icon(Icons.color_lens, color: AppColors.grey700, size: 20),
                      SizedBox(width: 12),
                      Text('Recolor', style: TextStyle(color: AppColors.grey700)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.grey700, size: 20),
                      SizedBox(width: 12),
                      Text('Rename', style: TextStyle(color: AppColors.grey700)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGroup(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete Group',
          style: TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.grey700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.grey600),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await GroupService.deleteGroup(group.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Group "${group.name}" deleted successfully'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete group: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _renameGroup(GroupModel group) {
    final nameController = TextEditingController(text: group.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Rename Group',
          style: TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: AppColors.grey900), // Dark text for white dialog background
          decoration: InputDecoration(
            labelText: 'Group Name',
            labelStyle: const TextStyle(color: AppColors.grey600), // Muted gray for label
            filled: true,
            fillColor: AppColors.white, // White background for dialog text field
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.grey600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a group name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await GroupService.updateGroup(
                    groupId: group.id,
                    name: nameController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Group renamed to "${nameController.text.trim()}"'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to rename group: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _recolorGroup(GroupModel group) {
    final colors = [
      '#3B82F6', // Blue
      '#10B981', // Green
      '#F59E0B', // Amber
      '#EF4444', // Red
      '#8B5CF6', // Purple
      '#EC4899', // Pink
      '#06B6D4', // Cyan
      '#84CC16', // Lime
      '#F97316', // Orange
      '#6366F1', // Indigo
      '#14B8A6', // Teal
      '#A855F7', // Violet
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Choose Color',
          style: TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: colors.map((colorHex) {
              final isSelected = group.color == colorHex;
              return GestureDetector(
                onTap: () async {
                  try {
                    await GroupService.updateGroup(
                      groupId: group.id,
                      color: colorHex,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Group color updated successfully'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update color: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(int.parse(colorHex.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.grey600),
            ),
          ),
        ],
      ),
    );
  }


  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Create New Group',
          style: TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.grey900),
              decoration: const InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(color: AppColors.grey600),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.grey300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: AppColors.grey900),
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: AppColors.grey600),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.grey300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.grey600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a group name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await GroupService.createGroup(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    createdBy: authService.user!.uid,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Group "${nameController.text.trim()}" created successfully'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create group: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}