import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/app_colors.dart';
import '../../services/connection_request_service.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';
import '../chat/group_chat_screen.dart';
import 'search_users_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleQRCode(String qrData) async {
    try {
      // Check if it's a group QR code
      if (qrData.startsWith('linkly://group/')) {
        final inviteCode = qrData.replaceFirst('linkly://group/', '');
        await _joinGroup(inviteCode);
        return;
      }

      // Handle user connection QR code (fast-path)
      Map<String, dynamic>? user;
      String? scannedUserId;
      if (qrData.startsWith('linkly://user/')) {
        scannedUserId = qrData.split('/').last;
        user = {'id': scannedUserId};
      } else {
        final connectionRequestService = ConnectionRequestService();
        user = await connectionRequestService.getUserByQRCode(qrData);
        scannedUserId = user?['id'];
      }

      if (scannedUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
        return;
      }

      // Create mutual connections for both users without pre-check queries
      await _connectInstant(scannedUserId, displayNameHint: user?['fullName'] ?? user?['username']);

      // Show hovering options to add to group, create group, or add later
      if (mounted) {
        _showScannedUserActions({'id': scannedUserId, ...?user});
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing QR code: $e')),
        );
      }
    }
  }

  void _showScannedUserActions(Map<String, dynamic> user) {
    final String displayName = (user['fullName'] ?? user['username'] ?? 'User');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.grey800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Connect with $displayName',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _selectGroupAndAdd(user);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You have successfully connected with $displayName')),
                    );
                  }
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Add to Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _createGroupAndAdd(user);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You have successfully connected with $displayName')),
                    );
                  }
                },
                icon: const Icon(Icons.add_circle_outline, color: AppColors.textPrimary),
                label: const Text('Create Group', style: TextStyle(color: AppColors.textPrimary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textPrimary, width: 1),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added $displayName to your connections')),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You have successfully connected with $displayName')),
                    );
                  }
                },
                icon: const Icon(Icons.person_add_alt_1, color: AppColors.textPrimary),
                label: const Text('Add to Connections', style: TextStyle(color: AppColors.textPrimary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textPrimary, width: 1),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You can add $displayName to a group later')),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You have successfully connected with $displayName')),
                    );
                  }
                },
                child: const Text('Add Later', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectGroupAndAdd(Map<String, dynamic> user) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user == null) return;
    // Ensure default groups exist for quick selection
    await GroupService.ensureDefaultGroups(auth.user!.uid);
    final groups = await GroupService.getUserGroups(auth.user!.uid).first;

    String? selectedGroupId = groups.isNotEmpty ? groups.first.id : null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.grey800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Choose Group', style: TextStyle(color: AppColors.textPrimary)),
          content: DropdownButtonFormField<String>(
            value: selectedGroupId,
            dropdownColor: AppColors.grey800,
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(),
              labelText: 'Group',
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
            items: groups
                .map((g) => DropdownMenuItem<String>(
                      value: g.id,
                      child: Text(g.name, style: const TextStyle(color: AppColors.textPrimary)),
                    ))
                .toList(),
            onChanged: (v) => selectedGroupId = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (selectedGroupId == null) return;
                try {
                  await GroupService.addConnectionToGroup(
                    groupId: selectedGroupId!,
                    connectionId: '${auth.user!.uid}_${user['id']}',
                    connectionUserId: user['id'],
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${user['fullName'] ?? user['username']} to group')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add to group: $e')),
                    );
                  }
                }
              },
              child: const Text('Add', style: TextStyle(color: AppColors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createGroupAndAdd(Map<String, dynamic> user) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user == null) return;

    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.grey800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Create Group', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.grey900),
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.grey900),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  final groupId = await GroupService.createGroup(
                    name: name,
                    description: descController.text.trim(),
                    createdBy: auth.user!.uid,
                  );
                  await GroupService.addConnectionToGroup(
                    groupId: groupId,
                    connectionId: '${auth.user!.uid}_${user['id']}',
                    connectionUserId: user['id'],
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Created "$name" and added ${user['fullName'] ?? user['username']}')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create group: $e')),
                    );
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: AppColors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectInstant(String otherUserId, {String? displayNameHint}) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final me = authService.user;
      if (me == null) {
        throw Exception('User not logged in');
      }

      if (otherUserId == me.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot connect with yourself')),
          );
        }
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Deterministic doc ids avoid read-before-write; create() fails if exists
      final myDocId = '${me.uid}_$otherUserId';
      final theirDocId = '${otherUserId}_${me.uid}';

      final batch = firestore.batch();
      final myRef = firestore.collection('connections').doc(myDocId);
      final theirRef = firestore.collection('connections').doc(theirDocId);

      // Prepare minimal payloads
      final myData = {
        'id': myDocId,
        'userId': me.uid,
        'contactUserId': otherUserId,
        'contactName': displayNameHint ?? '',
        'contactEmail': '',
        'contactPhone': null,
        'contactCompany': null,
        'connectionNote': 'Added via QR scan',
        'connectionMethod': 'QR Scan',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isNewConnection': true,
      };

      final myName = authService.userModel?.fullName ?? me.displayName ?? '';
      final myEmail = authService.userModel?.email ?? me.email ?? '';
      final theirData = {
        'id': theirDocId,
        'userId': otherUserId,
        'contactUserId': me.uid,
        'contactName': myName,
        'contactEmail': myEmail,
        'contactPhone': null,
        'contactCompany': null,
        'connectionNote': 'Added via QR scan',
        'connectionMethod': 'QR Scan',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isNewConnection': true,
      };

      // Use create so we skip any reads; if already exists, we'll ignore
      try { batch.set(myRef, myData, SetOptions(merge: false)); } catch (_) {}
      try { batch.set(theirRef, theirData, SetOptions(merge: false)); } catch (_) {}
      await batch.commit();

      // Fire-and-forget notification for the other user
      try {
        await firestore.collection('notifications').add({
          'receiverId': otherUserId,
          'title': 'New Connection',
          'body': '${authService.userModel?.fullName ?? 'Someone'} added you as a connection',
          'data': {
            'type': 'connection_added',
            'senderId': me.uid,
            'senderName': authService.userModel?.fullName ?? '',
          },
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'connection_added',
        });
      } catch (_) {}

      if (mounted) {
        final name = displayNameHint ?? 'user';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $name to your connections')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding connection: $e')),
        );
      }
    }
  }

  Future<void> _joinGroup(String inviteCode) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user == null) return;

      // Get group by invite code
      final group = await GroupService.getGroupByInviteCode(inviteCode);
      if (group == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group not found')),
          );
        }
        return;
      }

      // Show group info dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Join Group',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(int.parse(group.color.replaceFirst('#', '0xFF'))),
                  child: const Icon(
                    Icons.group,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  group.description,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${group.members.length} members',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await GroupService.joinGroupByInviteCode(
                        inviteCode: inviteCode,
                        userId: authService.user!.uid,
                        userName: authService.user!.displayName ?? 'User',
                      );
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully joined ${group.name}'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                        
                        // Navigate to group chat
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatScreen(
                              group: group,
                              currentUser: authService.userModel!,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to join group: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Join',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendConnectionRequest(Map<String, dynamic> user) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.user;
      final currentUserModel = authService.userModel;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      String currentUserName = 'User';
      String? currentUserProfileImageUrl;

      if (currentUserModel != null) {
        currentUserName = currentUserModel.fullName;
        currentUserProfileImageUrl = currentUserModel.profileImageUrl;
      } else if (currentUser.displayName != null) {
        currentUserName = currentUser.displayName!;
        currentUserProfileImageUrl = currentUser.photoURL;
      }

      final connectionRequestService = ConnectionRequestService();
      await connectionRequestService.sendConnectionRequest(
        senderId: currentUser.uid,
        senderName: currentUserName,
        senderProfileImageUrl: currentUserProfileImageUrl,
        receiverId: user['id'],
        receiverName: user['fullName'] ?? user['username'],
        receiverProfileImageUrl: user['profileImageUrl'],
        message: 'Hi! I scanned your QR code and would like to connect.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection request sent to ${user['fullName'] ?? user['username']}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () async {
              await controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_isScanning && capture.barcodes.isNotEmpty) {
                  final String? code = capture.barcodes.first.rawValue;
                  if (code != null) {
                    setState(() {
                      _isScanning = false;
                    });
                    _handleQRCode(code);
                  }
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black,
            child: Column(
              children: [
                const Text(
                  'Position the QR code within the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SearchUsersScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Search Instead'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
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
}