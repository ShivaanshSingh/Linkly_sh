import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../models/connection_request_model.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/auth_service.dart';
import '../../services/connection_request_service.dart';
import '../../services/group_service.dart';
import '../../utils/privacy_utils.dart';
import '../../utils/responsive_utils.dart';
import '../chat/chat_screen.dart';
import 'search_users_screen.dart';
import 'qr_scanner_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  final String? groupName;
  const ConnectionsScreen({super.key, this.groupName});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGroup = 'All Groups';
  String _sortBy = 'Sort by Name';
  List<ConnectionModel> _connections = [];
  List<ConnectionModel> _filteredConnections = [];
  List<GroupModel> _groups = [];
  List<ConnectionRequestModel> _pendingRequests = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectionRequestService _connectionRequestService = ConnectionRequestService();
  bool _selectionMode = false;
  final Set<String> _selectedConnectionIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Set the selected group if provided via route parameter
    if (widget.groupName != null && widget.groupName!.isNotEmpty) {
      _selectedGroup = widget.groupName!;
    }
    _loadConnections();
    _loadGroups();
    _loadPendingRequests();
  }

  void _loadConnections() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) return;

    // Listen to connections in real-time
    _firestore
        .collection('connections')
        .where('userId', isEqualTo: authService.user!.uid)
        .snapshots()
        .listen((snapshot) {
      debugPrint('🔍 Connections loaded for user: ${authService.user!.uid}');
      debugPrint('   - Found ${snapshot.docs.length} connections');
      if (mounted) {
        setState(() {
          _connections = snapshot.docs
              .map((doc) {
                final data = doc.data();
                return ConnectionModel.fromMap({
                  ...data,
                  'id': data['id'] ?? doc.id,
                });
              })
              .toList();
          // Sort by createdAt descending manually
          _connections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        // Respect current filters/search when live data changes
        _filterConnections();
      }
    }, onError: (error) {
      debugPrint('❌ Error loading connections: $error');
    });
  }

  void _loadGroups() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) {
      _groups = [];
      return;
    }

    // Fetch groups from Firestore
    GroupService.getUserGroups(authService.user!.uid).listen((groups) {
      if (mounted) {
        setState(() {
          _groups = groups;
          // Ensure selected group is valid
          if (_selectedGroup != 'All Groups' && !groups.any((group) => group.name == _selectedGroup)) {
            _selectedGroup = 'All Groups';
          }
        });
        // Apply filter after groups are loaded
        _filterConnections();
      }
    });
  }

  Future<void> _refreshData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.user;
      if (user == null) return;

      // Fetch current connections once (keeps the live listener intact)
      final connSnap = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: user.uid)
          .get();

      final freshConnections = connSnap.docs.map((doc) {
        final data = doc.data();
        return ConnectionModel.fromMap({
          ...data,
          'id': data['id'] ?? doc.id,
        });
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Fetch groups and pending requests once
      final freshGroups = await GroupService.getUserGroups(user.uid).first;
      final freshPending = await _connectionRequestService.getPendingRequests(user.uid).first;

      if (!mounted) return;
      setState(() {
        _connections = freshConnections;
        _filteredConnections = _connections;
        _groups = freshGroups;
        _pendingRequests = freshPending;
      });
      _filterConnections();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connections refreshed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedConnectionIds.clear();
      }
    });
  }

  void _toggleSelectConnection(ConnectionModel c) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedConnectionIds.contains(c.id)) {
        _selectedConnectionIds.remove(c.id);
      } else {
        _selectedConnectionIds.add(c.id);
      }
    });
  }

  Future<void> _showAddSelectedToGroupDialog() async {
    if (_selectedConnectionIds.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    String? selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.grey800,
          title: const Text('Add to Group', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose a group or create a new one:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedGroupId,
                dropdownColor: AppColors.grey800,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.grey50,
                  border: OutlineInputBorder(),
                  labelText: 'Group',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                items: [
                  ..._groups.map((g) => DropdownMenuItem<String>(
                        value: g.id,
                        child: Text(g.name, style: const TextStyle(color: AppColors.textPrimary)),
                      )),
                  const DropdownMenuItem<String>(
                    value: '__create__',
                    child: Text('Create New Group', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
                onChanged: (val) async {
                  if (val == '__create__') {
                    Navigator.of(context).pop();
                    _showCreateGroupDialogGeneric();
                  } else {
                    selectedGroupId = val;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (selectedGroupId == null) return;
                final sel = _connections.where((c) => _selectedConnectionIds.contains(c.id)).toList();
                for (final c in sel) {
                  await GroupService.addConnectionToGroup(
                    groupId: selectedGroupId!,
                    connectionId: c.id,
                    connectionUserId: c.contactUserId,
                  );
                }
                if (mounted) Navigator.of(context).pop();
                setState(() {
                  _selectionMode = false;
                  _selectedConnectionIds.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added ${sel.length} connection(s) to group')),
                );
              },
              child: const Text('Add', style: TextStyle(color: AppColors.white)),
            ),
          ],
        );
      },
    );
  }

  void _loadPendingRequests() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) return;

    _connectionRequestService.getPendingRequests(authService.user!.uid).listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    });
  }

  void _filterConnections() {
    setState(() {
      _filteredConnections = _connections.where((connection) {
        final searchTerm = _searchController.text.toLowerCase();
        
        // Check search term match
        final matchesSearch = connection.contactName.toLowerCase().contains(searchTerm) ||
               connection.contactEmail.toLowerCase().contains(searchTerm) ||
               (connection.contactCompany?.toLowerCase().contains(searchTerm) ?? false);
        
        // Check group filter
        bool matchesGroup = true;
        if (_selectedGroup != 'All Groups') {
          // Find the selected group
          final selectedGroup = _groups.firstWhere(
            (group) => group.name == _selectedGroup,
            orElse: () => GroupModel(
              id: '',
              name: '',
              description: '',
              color: '',
              createdBy: '',
              members: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          
          if (selectedGroup.id.isNotEmpty) {
            // Check if connection belongs to this group
            matchesGroup = connection.groupId == selectedGroup.id;
          }
        }
        
        return matchesSearch && matchesGroup;
      }).toList();
      
      debugPrint('🔄 Filtered connections: ${_connections.length} total, ${_filteredConnections.length} after filter');
    });
  }

  Future<void> _acceptConnectionRequest(ConnectionRequestModel request) async {
    try {
      await _connectionRequestService.acceptConnectionRequest(request.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request from ${request.senderName} accepted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _declineConnectionRequest(ConnectionRequestModel request) async {
    try {
      await _connectionRequestService.declineConnectionRequest(request.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request from ${request.senderName} declined'),
          backgroundColor: AppColors.grey500,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showConnectionRequestsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connection Requests',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: _pendingRequests.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: AppColors.grey400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Pending Requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You don\'t have any pending connection requests at the moment.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _pendingRequests.length,
                          itemBuilder: (context, index) {
                            final request = _pendingRequests[index];
                            return Container(
                              margin: const EdgeInsets.all(16),
                              child: _buildConnectionRequestCard(request),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToGroupDialog(ConnectionModel connection) async {
    // Reload groups
    final authService = Provider.of<AuthService>(context, listen: false);
    _loadGroups();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 500),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1F295B).withOpacity(0.9),
                          const Color(0xFF283B89).withOpacity(0.85),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF6B8FAE).withOpacity(0.4),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.group_add,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add ${connection.contactName} to Group',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white24),
                    
                        // Content
                        Flexible(
                          child: _groups.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.group_outlined,
                                        size: 64,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Groups Available',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Create a group first to add connections.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          // Open create group dialog
                                          _showCreateGroupDialog(connection);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Create Group',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        itemCount: _groups.length,
                                        itemBuilder: (context, index) {
                                          final group = _groups[index];
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(0xFF1F295B).withOpacity(0.85),
                                                  const Color(0xFF283B89).withOpacity(0.8),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: const Color(0xFF6B8FAE).withOpacity(0.4),
                                                width: 1.5,
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                                child: ListTile(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  leading: CircleAvatar(
                                                    backgroundColor: AppColors.primary,
                                                    child: Text(
                                                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    group.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    '${group.members.length} members',
                                                    style: TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          _addConnectionToGroup(connection, group);
                                                          Navigator.of(context).pop();
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.primary,
                                                          foregroundColor: Colors.white,
                                                          minimumSize: const Size(50, 32),
                                                        ),
                                                        child: const Text(
                                                          'Add',
                                                          style: TextStyle(fontSize: 12),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      PopupMenuButton<String>(
                                                        icon: Icon(
                                                          Icons.more_vert,
                                                          color: Colors.white.withOpacity(0.7),
                                                          size: 20,
                                                        ),
                                                        onSelected: (String value) {
                                                          if (value == 'delete_group') {
                                                            _showDeleteGroupDialog(group);
                                                          }
                                                        },
                                                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                                          const PopupMenuItem<String>(
                                                            value: 'delete_group',
                                                            child: Row(
                                                              children: [
                                                                Icon(Icons.delete_outline, color: Colors.red),
                                                                SizedBox(width: 8),
                                                                Text('Delete Group'),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    
                                    // Add "Create Group" button at the bottom
                                    Container(
                                      margin: const EdgeInsets.all(16),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _showCreateGroupDialog(connection);
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Create Group'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(double.infinity, 48),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGroup(GroupModel group) async {
    try {
      await GroupService.deleteGroup(group.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "${group.name}" deleted successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
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

  void _showDeleteGroupDialog(GroupModel group) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Group',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${group.name}"? This action cannot be undone.',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 16,
            ),
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteGroup(group);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addConnectionToGroup(ConnectionModel connection, GroupModel group) async {
    try {
      await GroupService.addConnectionToGroup(
        groupId: group.id,
        connectionId: connection.id,
        connectionUserId: connection.contactUserId,
      );
      
      // Update the connection's groupId locally
      final updatedConnection = connection.copyWith(groupId: group.id);
      setState(() {
        final index = _connections.indexWhere((c) => c.id == connection.id);
        if (index != -1) {
          _connections[index] = updatedConnection;
        }
        final filteredIndex = _filteredConnections.indexWhere((c) => c.id == connection.id);
        if (filteredIndex != -1) {
          _filteredConnections[filteredIndex] = updatedConnection;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${connection.contactName} added to ${group.name}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add ${connection.contactName} to group: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey900, // Overall Background - matching homepage
      appBar: AppBar(
        backgroundColor: AppColors.grey900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 100,
        title: Padding(
          padding: EdgeInsets.only(
            top: ResponsiveUtils.getSpacing(context, small: 8),
            left: ResponsiveUtils.getHorizontalPadding(context),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My Connections',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: ResponsiveUtils.getFontSize(context, baseSize: 24),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, small: 4)),
                Text(
                  '${_filteredConnections.length} connections found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: ResponsiveUtils.getFontSize(context, baseSize: 14),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        titleSpacing: 0,
        actions: [
          ...(_selectionMode
              ? [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${_selectedConnectionIds.length} selected',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add selected to group',
                    icon: const Icon(Icons.group_add, color: AppColors.textPrimary),
                    onPressed: _showAddSelectedToGroupDialog,
                  ),
                  IconButton(
                    tooltip: 'Cancel selection',
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: _toggleSelectionMode,
                  ),
                ]
              : [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.grey700,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_add, color: AppColors.textPrimary, size: 18),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SearchUsersScreen(),
                          ),
                        );
                      },
                      tooltip: 'Search People',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _pendingRequests.isNotEmpty ? AppColors.primary : AppColors.grey700,
                      shape: BoxShape.circle,
                      boxShadow: _pendingRequests.isNotEmpty ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.person_add_alt_1, 
                        color: _pendingRequests.isNotEmpty ? Colors.white : AppColors.textPrimary,
                        size: 18
                      ),
                      onPressed: () {
                        _showConnectionRequestsDialog();
                      },
                      tooltip: 'Connection Requests',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.grey700,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Select multiple',
                      icon: const Icon(Icons.checklist, color: AppColors.textPrimary, size: 18),
                      onPressed: _toggleSelectionMode,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4A90E2), // Medium blue
                          Color(0xFF9B59B6), // Medium purple
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      onPressed: _refreshData,
                      tooltip: 'Refresh',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ]),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
            child: Column(
              children: [
              // Connection Requests Section
          if (_pendingRequests.isNotEmpty) ...[
            Container(
              margin: EdgeInsets.fromLTRB(
                ResponsiveUtils.getHorizontalPadding(context),
                ResponsiveUtils.getSpacing(context, small: 8),
                ResponsiveUtils.getHorizontalPadding(context),
                ResponsiveUtils.getSpacing(context, small: 8),
              ),
              padding: ResponsiveUtils.getPadding(context),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: AppColors.primary,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, small: 8, medium: 12)),
                  Text(
                    '${_pendingRequests.length} connection request${_pendingRequests.length == 1 ? '' : 's'} pending',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            // Connection Requests List
            Container(
              margin: EdgeInsets.fromLTRB(
                ResponsiveUtils.getHorizontalPadding(context),
                0,
                ResponsiveUtils.getHorizontalPadding(context),
                ResponsiveUtils.getVerticalPadding(context),
              ),
              child: Column(
                children: _pendingRequests.map((request) => _buildConnectionRequestCard(request)).toList(),
              ),
            ),
          ],
          
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveUtils.getHorizontalPadding(context),
              ResponsiveUtils.getVerticalPadding(context) + ResponsiveUtils.getSpacing(context, small: 8),
              ResponsiveUtils.getHorizontalPadding(context),
              ResponsiveUtils.getSpacing(context, small: 16),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2F50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _filterConnections(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or company...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                    fontWeight: FontWeight.w400,
                  ),
                  filled: false,
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 20),
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
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    vertical: ResponsiveUtils.getVerticalPadding(context),
                  ),
                ),
              ),
            ),
          ),
          
          // Filter dropdowns
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveUtils.getHorizontalPadding(context),
              0,
              ResponsiveUtils.getHorizontalPadding(context),
              ResponsiveUtils.getSpacing(context, small: 20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2F50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGroup,
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            if (newValue == 'CREATE_GROUP') {
                              // Show create group dialog without requiring a specific connection
                              _showCreateGroupDialogGeneric();
                            } else {
                              setState(() {
                                _selectedGroup = newValue;
                              });
                              _filterConnections();
                            }
                          }
                        },
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                          fontWeight: FontWeight.w400,
                        ),
                        dropdownColor: const Color(0xFF2A2F50),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: 'All Groups',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getHorizontalPadding(context)),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.group, 
                                    color: AppColors.textPrimary, 
                                    size: ResponsiveUtils.getIconSize(context, baseSize: 18),
                                  ),
                                  SizedBox(width: ResponsiveUtils.getSpacing(context, small: 8, medium: 12)),
                                  Text(
                                    'All Groups',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ..._groups.map((group) => DropdownMenuItem<String>(
                            value: group.name,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getHorizontalPadding(context)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(group.color.replaceFirst('#', '0xFF'))),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                          const DropdownMenuItem<String>(
                            value: 'CREATE_GROUP',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create Group',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, small: 12)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2F50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isExpanded: true,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                          fontWeight: FontWeight.w400,
                        ),
                        dropdownColor: const Color(0xFF2A2F50),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                        ),
                        items: ['Sort by Name', 'Sort by Date', 'Sort by Company'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getHorizontalPadding(context)),
                              child: Text(
                                value,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _sortBy = newValue!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Connections list
          _filteredConnections.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: _filteredConnections.map((connection) => 
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getHorizontalPadding(context),
                        vertical: ResponsiveUtils.getSpacing(context, small: 4),
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          if (!_selectionMode) {
                            _toggleSelectionMode();
                            _toggleSelectConnection(connection);
                          }
                        },
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelectConnection(connection);
                          }
                        },
                        child: Stack(
                          children: [
                            _buildConnectionCard(connection),
                            if (_selectionMode)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Builder(
                                  builder: (context) {
                                    final bool isSelected = _selectedConnectionIds.contains(connection.id);
                                    return GestureDetector(
                                      onTap: () => _toggleSelectConnection(connection),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.9),
                                            width: 2,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.primary.withOpacity(0.4),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ).toList(),
                ),
            ],
          ),
        );
      },
    ),
    );
  }

  Future<String?> _getUserProfileImageUrl(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['profileImageUrl'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile image: $e');
      return null;
    }
  }

  Future<String?> _getUserPhoneNumber(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data == null) return null;
        // Try multiple common keys and return the first non-empty string
        final possibleKeys = [
          'phoneNumber',
          'phone',
          'mobile',
          'mobileNumber',
          'contactNumber',
          'phone_number',
        ];
        for (final key in possibleKeys) {
          final value = data[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user phone number: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getUserPrivacySettings(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data == null) {
          return {'phoneNumberPrivacy': 'connections_only', 'allowedPhoneViewers': []};
        }
        return {
          'phoneNumberPrivacy': data['phoneNumberPrivacy'] ?? 'connections_only',
          'allowedPhoneViewers': List<String>.from(data['allowedPhoneViewers'] ?? []),
        };
      }
      return {'phoneNumberPrivacy': 'connections_only', 'allowedPhoneViewers': []};
    } catch (e) {
      debugPrint('Error fetching user privacy settings: $e');
      return {'phoneNumberPrivacy': 'connections_only', 'allowedPhoneViewers': []};
    }
  }

  Future<bool> _isUserInConnections(String ownerUserId, String viewerUserId) async {
    try {
      // Check if viewer is in owner's connections list
      final connectionDoc = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: ownerUserId)
          .where('contactUserId', isEqualTo: viewerUserId)
          .limit(1)
          .get();
      return connectionDoc.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if user is in connections: $e');
      return false;
    }
  }

  Future<String?> _getUserLinkedInUrl(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data == null) return null;
        
        // Check socialLinks map for LinkedIn
        if (data['socialLinks'] != null && data['socialLinks'] is Map) {
          final socialLinks = data['socialLinks'] as Map;
          final linkedInUrl = socialLinks['linkedin'];
          if (linkedInUrl is String && linkedInUrl.trim().isNotEmpty) {
            return linkedInUrl.trim();
          }
        }
        
        // Fallback: check direct linkedin field
        final linkedIn = data['linkedin'];
        if (linkedIn is String && linkedIn.trim().isNotEmpty) {
          return linkedIn.trim();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user LinkedIn URL: $e');
      return null;
    }
  }

  Future<String?> _getUserFullName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      final data = userDoc.data();
      if (data == null) return null;
      final fullName = data['fullName'] ?? data['name'] ?? data['displayName'];
      if (fullName is String && fullName.trim().isNotEmpty) return fullName.trim();
      final email = data['email'];
      if (email is String && email.contains('@')) return email.split('@').first;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getUserCompany(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      final data = userDoc.data();
      if (data == null) return null;
      final company = data['company'] ?? data['organization'] ?? data['org'];
      if (company is String && company.trim().isNotEmpty) return company.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getUserPosition(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      final data = userDoc.data();
      if (data == null) return null;
      final position = data['position'] ?? data['jobTitle'] ?? data['title'];
      if (position is String && position.trim().isNotEmpty) return position.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getUserEmail(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      final data = userDoc.data();
      if (data == null) return null;
      final email = data['email'] ?? data['mail'];
      if (email is String && email.trim().isNotEmpty) return email.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      debugPrint('Could not launch email: $email');
    }
  }

  Future<void> _launchLinkedIn(String url) async {
    String linkedInUrl = url;
    // Ensure URL has a scheme
    if (!linkedInUrl.startsWith('http://') && !linkedInUrl.startsWith('https://')) {
      linkedInUrl = 'https://$linkedInUrl';
    }
    
    final Uri linkedInUri = Uri.parse(linkedInUrl);
    if (await canLaunchUrl(linkedInUri)) {
      await launchUrl(linkedInUri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch LinkedIn URL: $url');
    }
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

  Widget _buildDefaultAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    return Container(
      color: Colors.purple,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(ConnectionModel connection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        
        final cardMaxWidth = ResponsiveUtils.getCardMaxWidth(context);
        final cardPadding = ResponsiveUtils.getPadding(context);
        final avatarSize = ResponsiveUtils.getAvatarSize(context);
        final borderRadius = ResponsiveUtils.getBorderRadius(context);
        
        return Center(
          child: Container(
            margin: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, small: 8)),
            constraints: BoxConstraints(
              maxWidth: cardMaxWidth,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F295B), // Dark navy/indigo (#1F295B) - corners and edges
                  Color(0xFF283B89), // Medium-dark blue/royal blue (#283B89) - center
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 3.5 / 2.5,
              child: Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header section with avatar and name
                    Row(
                      children: [
                    // Profile image with circular design like reference
                    FutureBuilder<List<String?>>(
                      future: Future.wait([
                        _getUserProfileImageUrl(connection.contactUserId),
                        _getUserFullName(connection.contactUserId),
                      ]),
                      builder: (context, snapshot) {
                        final profileImageUrl = snapshot.data?[0];
                        final userName = snapshot.data?[1] ?? connection.contactName;
                        final displayName = userName.isNotEmpty ? userName : 'Contact';
                        return Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.purple, 
                              width: ResponsiveUtils.isMobile(context) ? 2.5 : 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: profileImageUrl != null
                                ? Image.network(
                                    profileImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultAvatar(displayName);
                                    },
                                  )
                                : _buildDefaultAvatar(displayName),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                    
                    // Name and title section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name with fallback to user profile when missing
                          if (connection.contactName.trim().isNotEmpty)
                            Text(
                              connection.contactName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveUtils.getFontSize(context, baseSize: 20),
                                letterSpacing: 0.5,
                              ),
                            )
                          else
                            FutureBuilder<String?>(
                              future: _getUserFullName(connection.contactUserId),
                              builder: (context, snapshot) {
                                final name = (snapshot.data ?? '').trim();
                                return Text(
                                  name.isNotEmpty ? name : 'Contact',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: ResponsiveUtils.getFontSize(context, baseSize: 20),
                                    letterSpacing: 0.5,
                                  ),
                                );
                              },
                            ),
                          // Position (Job Title) with fallback to user profile
                          FutureBuilder<String?>(
                            future: _getUserPosition(connection.contactUserId),
                            builder: (context, snapshot) {
                              final position = (snapshot.data ?? '').trim();
                              if (position.isNotEmpty) {
                                return Padding(
                                  padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, small: 2)),
                                  child: Text(
                                    position,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveUtils.getFontSize(context, baseSize: 14),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, small: 2)),
                            child: FutureBuilder<String?>(
                              future: connection.contactCompany != null && connection.contactCompany!.trim().isNotEmpty
                                  ? Future.value(connection.contactCompany)
                                  : _getUserCompany(connection.contactUserId),
                              builder: (context, snapshot) {
                                final company = (snapshot.data ?? '').trim();
                                return Text(
                                  company.isNotEmpty ? company : 'Professional',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getFontSize(context, baseSize: 15),
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.3,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 3-dot menu like reference
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                      ),
                      onSelected: (String value) {
                        if (value == 'delete') {
                          _showDeleteDialog(connection);
                        } else if (value == 'add_to_group') {
                          _showAddToGroupDialog(connection);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'add_to_group',
                          child: Row(
                            children: [
                              Icon(Icons.group_add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Add to Group'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                SizedBox(height: ResponsiveUtils.getSpacing(context, small: 8, medium: 12)),
                
                // Contact information section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                      // Email (clickable) with fallback from user profile
                      FutureBuilder<String?>(
                        future: connection.contactEmail.trim().isNotEmpty
                            ? Future.value(connection.contactEmail)
                            : _getUserEmail(connection.contactUserId),
                        builder: (context, snapshot) {
                          final email = (snapshot.data ?? '').trim();
                          return InkWell(
                            onTap: email.isNotEmpty ? () => _launchEmail(email) : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email_outlined, 
                                  color: Colors.white, 
                                  size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                                ),
                                SizedBox(width: ResponsiveUtils.getSpacing(context, small: 6, medium: 8)),
                                Expanded(
                                  child: Text(
                                    email.isNotEmpty ? email : 'Email',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(email.isNotEmpty ? 1 : 0.7),
                                      fontSize: ResponsiveUtils.getFontSize(context, baseSize: 14),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.2,
                                      decoration: email.isNotEmpty ? TextDecoration.underline : TextDecoration.none,
                                      decorationColor: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: ResponsiveUtils.getSpacing(context, small: 2)),
                      
                      // LinkedIn (clickable) - shows username with LinkedIn logo
                      FutureBuilder<String?>(
                        future: _getUserLinkedInUrl(connection.contactUserId),
                        builder: (context, snapshot) {
                          final linkedInUrl = snapshot.data;
                          if (linkedInUrl != null && linkedInUrl.isNotEmpty) {
                            final linkedInUsername = _extractLinkedInUsername(linkedInUrl);
                            return InkWell(
                              onTap: () => _launchLinkedIn(linkedInUrl),
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                children: [
                                  // LinkedIn logo (using "in" text badge)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'in',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Roboto',
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      linkedInUsername,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.2,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          // If no LinkedIn URL, show non-clickable placeholder
                          return const Row(
                            children: [
                              Icon(Icons.link, color: Colors.white70, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'LinkedIn Profile',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 2),
                      
                      // Phone (fetched from Firestore with privacy check)
                      FutureBuilder<Map<String, dynamic>>(
                        future: Future.wait([
                          _getUserPhoneNumber(connection.contactUserId),
                          _getUserPrivacySettings(connection.contactUserId),
                          Future.value(Provider.of<AuthService>(context, listen: false).user?.uid ?? ''),
                        ]).then((results) async {
                          final currentUserId = results[2] as String;
                          final ownerUserId = connection.contactUserId;
                          // Check if current user is in the contact's connections list
                          final isConnected = await _isUserInConnections(ownerUserId, currentUserId);
                          return {
                            'phoneNumber': results[0] as String?,
                            'privacySettings': results[1] as Map<String, dynamic>,
                            'isConnected': isConnected,
                          };
                        }),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final phoneNumber = snapshot.data!['phoneNumber'] as String?;
                          final privacySettings = snapshot.data!['privacySettings'] as Map<String, dynamic>;
                          final phoneNumberPrivacy = privacySettings['phoneNumberPrivacy'] as String? ?? 'connections_only';
                          final allowedPhoneViewers = (privacySettings['allowedPhoneViewers'] as List?)?.cast<String>() ?? [];
                          final isConnected = snapshot.data!['isConnected'] as bool? ?? false;

                          // Get current user ID
                          final authService = Provider.of<AuthService>(context, listen: false);
                          final currentUserId = authService.user?.uid ?? '';

                          // Check if phone number should be visible
                          final shouldShow = PrivacyUtils.shouldShowPhoneNumber(
                            phoneNumberPrivacy: phoneNumberPrivacy,
                            isConnected: isConnected,
                            viewerUserId: currentUserId,
                            ownerUserId: connection.contactUserId,
                            allowedPhoneViewers: allowedPhoneViewers,
                          );

                          // Determine the phone number to display
                          String? displayPhoneNumber;
                          if (phoneNumber != null && phoneNumber.isNotEmpty) {
                            displayPhoneNumber = phoneNumber;
                          } else if (connection.contactPhone != null && connection.contactPhone!.isNotEmpty) {
                            displayPhoneNumber = connection.contactPhone;
                          }

                          if (displayPhoneNumber != null && displayPhoneNumber.isNotEmpty) {
                            // Use PrivacyUtils to get display text
                            final displayText = PrivacyUtils.getPhoneNumberDisplay(
                              phoneNumber: displayPhoneNumber,
                              phoneNumberPrivacy: phoneNumberPrivacy,
                              isConnected: isConnected,
                              viewerUserId: currentUserId,
                              ownerUserId: connection.contactUserId,
                              allowedPhoneViewers: allowedPhoneViewers,
                              placeholder: 'Phone number hidden',
                            );

                            // If phone number is hidden, don't show the row
                            if (!shouldShow || displayText == 'Phone number hidden') {
                              return const SizedBox.shrink();
                            }

                            return Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined, 
                                  color: Colors.white, 
                                  size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                                ),
                                SizedBox(width: ResponsiveUtils.getSpacing(context, small: 6, medium: 8)),
                                Expanded(
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveUtils.getFontSize(context, baseSize: 14),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink(); // Return empty widget if no phone number
                        },
                      ),
                      
                      SizedBox(height: ResponsiveUtils.getSpacing(context, small: 4)),
                      
                      // Message button
                      GestureDetector(
                        onTap: () {
                          _openChat(connection);
                        },
                        child: Text(
                          'Message',
                          style: TextStyle(
                            color: const Color(0xFFFFA500), // Vibrant orange/yellow like reference
                            fontSize: ResponsiveUtils.getFontSize(context, baseSize: 16),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      
                      // Thin divider line between message button and date
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.2),
                        margin: EdgeInsets.only(
                          top: ResponsiveUtils.getSpacing(context, small: 4),
                          bottom: ResponsiveUtils.getSpacing(context, small: 4),
                        ),
                      ),
                      
                      // Date
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getFontSize(context, baseSize: 12),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      
                      // Group name (if connection is in a group)
                      if (connection.groupId != null && connection.groupId!.isNotEmpty)
                        FutureBuilder<GroupModel?>(
                          future: GroupService.getGroup(connection.groupId!),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.group, color: Colors.white70, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      snapshot.data!.name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  void _showCreateGroupDialogGeneric() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1F295B).withOpacity(0.9),
                      const Color(0xFF283B89).withOpacity(0.85),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF6B8FAE).withOpacity(0.4),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create Group',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a new group',
                      style: TextStyle(
                        color: Color(0xFFB0B8C5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryLight,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
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
                        final groupId = await GroupService.createGroup(
                          name: nameController.text.trim(),
                          description: '',
                          createdBy: authService.user!.uid,
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateGroupDialog(ConnectionModel connection) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1F295B).withOpacity(0.9),
                      const Color(0xFF283B89).withOpacity(0.85),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF6B8FAE).withOpacity(0.4),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create Group',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new group for ${connection.contactName}',
                      style: const TextStyle(
                        color: Color(0xFFB0B8C5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryLight,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
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
                        final groupId = await GroupService.createGroup(
                          name: nameController.text.trim(),
                          description: '',
                          createdBy: authService.user!.uid,
                        );

                        // Add connection to the newly created group
                        _addConnectionToGroup(connection, GroupModel(
                          id: groupId,
                          name: nameController.text.trim(),
                          description: '',
                          createdBy: authService.user!.uid,
                          members: [authService.user!.uid, connection.contactUserId],
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          color: '#0466C8',
                          qrCode: 'linkly://group/${groupId}',
                          inviteCode: groupId,
                        ));

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Group "${nameController.text.trim()}" created and ${connection.contactName} added successfully'),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create & Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  void _showDeleteDialog(ConnectionModel connection) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Remove Connection',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Are you sure you want to remove ${connection.contactName} from your connections? This action cannot be undone.',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 16,
            ),
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _removeConnection(connection);
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  void _createGroup(String name, String description, String color) {
    final newGroup = GroupModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      color: color,
      createdBy: 'current_user',
      members: ['current_user'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _groups.add(newGroup);
      _selectedGroup = name;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group "$name" created successfully!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF0466C8).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 60,
                color: const Color(0xFF0466C8),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'No Connections Yet',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            
            // Description
            Text(
              'Start building your professional network by connecting with people around you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Action buttons
            Column(
              children: [
                // QR Scanner button - smaller and floating
                Container(
                  width: 120,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
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
                          Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scan QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Search People button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SearchUsersScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Search People',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Help text
            Text(
              'Make connections to view them here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeConnection(ConnectionModel connection) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user == null) return;

      // Optimistically remove from local lists so UI updates immediately
      setState(() {
        _connections.removeWhere((c) => c.id == connection.id);
        _filteredConnections.removeWhere((c) => c.id == connection.id);
      });

      final connectionRequestService = ConnectionRequestService();
      
      // Remove connection only from current user's side (one-way removal)
      // This ensures user2 still sees user1 in their connections if user1 removes user2
      await connectionRequestService.removeConnectionById(connection.id);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${connection.contactName} removed from connections'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      // Rollback on error - add connection back to lists
      if (mounted) {
        setState(() {
          // Only add back if it doesn't already exist
          if (!_connections.any((c) => c.id == connection.id)) {
            _connections.add(connection);
            _filteredConnections.add(connection);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove connection. Please check your connection.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _openChat(ConnectionModel connection) {
    // Create a UserModel from ConnectionModel for the chat
    final user = UserModel(
      uid: connection.contactUserId,
      email: connection.contactEmail,
      fullName: connection.contactName,
      username: connection.contactName.toLowerCase().replaceAll(' ', ''), // Generate username from name
      profileImageUrl: null, // You can add profile image URL to ConnectionModel if needed
      company: connection.contactCompany,
      position: null, // You can add position to ConnectionModel if needed
      bio: null,
      createdAt: connection.createdAt,
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    // Mock messages for demonstration
    final mockMessages = [
      MessageModel(
        id: '1',
        senderId: connection.contactUserId,
        receiverId: 'current_user',
        text: 'Hello! Nice to meet you.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        messageType: 'text',
      ),
      MessageModel(
        id: '2',
        senderId: 'current_user',
        receiverId: connection.contactUserId,
        text: 'Hi! Great to connect with you.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        messageType: 'text',
      ),
      MessageModel(
        id: '3',
        senderId: connection.contactUserId,
        receiverId: 'current_user',
        text: 'Looking forward to working together!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        messageType: 'text',
      ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          user: user,
          initialMessages: mockMessages,
        ),
      ),
    );
  }

  void _showGroupOptions(ConnectionModel connection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      connection.contactName.isNotEmpty 
                          ? connection.contactName[0].toUpperCase() 
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add ${connection.contactName} to Group',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Select a group to add this connection',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 64,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create a Group',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a new group to organize your connections',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to groups screen to create group
                  Navigator.pushNamed(context, '/groups');
                },
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
      ),
    );
  }

  Widget _buildConnectionRequestCard(ConnectionRequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Profile image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    request.senderName.isNotEmpty 
                        ? request.senderName[0].toUpperCase() 
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.senderName,
                      style: const TextStyle(
                        color: AppColors.grey700,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wants to connect with you',
                      style: const TextStyle(
                        color: AppColors.grey500,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.message!,
                style: const TextStyle(
                  color: AppColors.grey600,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _declineConnectionRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.grey200,
                    foregroundColor: AppColors.grey600,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptConnectionRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

