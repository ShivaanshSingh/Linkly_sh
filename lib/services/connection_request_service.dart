import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/connection_request_model.dart';
import '../models/connection_model.dart';

class ConnectionRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a connection request
  Future<String> sendConnectionRequest({
    required String senderId,
    required String senderName,
    String? senderProfileImageUrl,
    required String receiverId,
    required String receiverName,
    String? receiverProfileImageUrl,
    String? message,
  }) async {
    try {
      // Check if users are already connected
      final existingConnection = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: senderId)
          .where('contactUserId', isEqualTo: receiverId)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        throw Exception('Users are already connected');
      }

      // Check if there's already a pending request
      final existingRequest = await _firestore
          .collection('connection_requests')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Connection request already sent');
      }

      // Create connection request
      final requestId = _firestore.collection('connection_requests').doc().id;
      final now = DateTime.now();

      final request = ConnectionRequestModel(
        id: requestId,
        senderId: senderId,
        senderName: senderName,
        senderProfileImageUrl: senderProfileImageUrl,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverProfileImageUrl: receiverProfileImageUrl,
        message: message,
        createdAt: now,
        status: ConnectionRequestStatus.pending,
      );

      await _firestore.collection('connection_requests').doc(requestId).set(request.toMap());
      
      // Create notification for the receiver
      await _createConnectionRequestNotification(
        receiverId: receiverId,
        senderName: senderName,
        senderId: senderId,
        requestId: requestId,
        message: message,
      );
      
      return requestId;
    } catch (e) {
      throw Exception('Failed to send connection request: ${e.toString()}');
    }
  }

  // Get pending connection requests for a user
  Stream<List<ConnectionRequestModel>> getPendingRequests(String userId) {
    return _firestore
        .collection('connection_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConnectionRequestModel.fromMap(doc.data()))
            .toList());
  }

  // Get sent connection requests for a user
  Stream<List<ConnectionRequestModel>> getSentRequests(String userId) {
    return _firestore
        .collection('connection_requests')
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConnectionRequestModel.fromMap(doc.data()))
            .toList());
  }

  // Accept a connection request
  Future<void> acceptConnectionRequest(String requestId) async {
    try {
      final requestDoc = await _firestore.collection('connection_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Connection request not found');
      }

      final request = ConnectionRequestModel.fromMap(requestDoc.data()!);
      final now = DateTime.now();

      // Update request status
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'accepted',
        'respondedAt': Timestamp.fromDate(now),
      });

      // Get user data for email
      final senderUser = await _firestore.collection('users').doc(request.senderId).get();
      final receiverUser = await _firestore.collection('users').doc(request.receiverId).get();
      
      final senderEmail = senderUser.exists ? senderUser.data()!['email'] ?? '' : '';
      final receiverEmail = receiverUser.exists ? receiverUser.data()!['email'] ?? '' : '';

      // Create connection for both users
      final connection1 = ConnectionModel(
        id: _firestore.collection('connections').doc().id,
        userId: request.senderId,
        contactUserId: request.receiverId,
        contactName: request.receiverName,
        contactEmail: receiverEmail,
        contactPhone: null,
        contactCompany: null,
        connectionNote: request.message,
        connectionMethod: 'Connection Request',
        createdAt: now,
        isNewConnection: true,
      );

      final connection2 = ConnectionModel(
        id: _firestore.collection('connections').doc().id,
        userId: request.receiverId,
        contactUserId: request.senderId,
        contactName: request.senderName,
        contactEmail: senderEmail,
        contactPhone: null,
        contactCompany: null,
        connectionNote: request.message,
        connectionMethod: 'Connection Request',
        createdAt: now,
        isNewConnection: true,
      );

      // Add connections to both users
      await _firestore.collection('connections').doc(connection1.id).set(connection1.toMap());
      await _firestore.collection('connections').doc(connection2.id).set(connection2.toMap());

    } catch (e) {
      throw Exception('Failed to accept connection request: $e');
    }
  }

  // Decline a connection request
  Future<void> declineConnectionRequest(String requestId, {String? responseMessage}) async {
    try {
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'declined',
        'respondedAt': Timestamp.now(),
        'responseMessage': responseMessage,
      });
    } catch (e) {
      throw Exception('Failed to decline connection request: $e');
    }
  }

  // Cancel a connection request (by sender)
  Future<void> cancelConnectionRequest(String requestId) async {
    try {
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'cancelled',
        'respondedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to cancel connection request: $e');
    }
  }


  // Get user by username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final users = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (users.docs.isEmpty) {
        return null;
      }

      final user = users.docs.first;
      return {
        'id': user.id,
        'username': user.data()['username'],
        'fullName': user.data()['fullName'],
        'profileImageUrl': user.data()['profileImageUrl'],
        'email': user.data()['email'],
      };
    } catch (e) {
      throw Exception('Failed to get user by username: ${e.toString()}');
    }
  }

  // Search users by username (partial match)
  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // Search for users whose username or fullName contains the query
      final users = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.trim())
          .where('username', isLessThan: '${query.trim()}\uf8ff')
          .limit(10)
          .get();

      return users.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'username': data['username'] ?? '',
          'fullName': data['fullName'] ?? '',
          'profileImageUrl': data['profileImageUrl'],
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to search users: ${e.toString()}');
    }
  }

  // Get user by QR code data
  Future<Map<String, dynamic>?> getUserByQRCode(String qrData) async {
    try {
      // QR code data format: "linkly://user/{userId}" or "{username}"
      if (qrData.startsWith('linkly://user/')) {
        final userId = qrData.split('/').last;
        final user = await _firestore.collection('users').doc(userId).get();
        
        if (!user.exists) {
          return null;
        }

        return {
          'id': user.id,
          'username': user.data()!['username'],
          'fullName': user.data()!['fullName'],
          'profileImageUrl': user.data()!['profileImageUrl'],
          'email': user.data()!['email'],
        };
      } else {
        // Assume it's a username
        return await getUserByUsername(qrData);
      }
    } catch (e) {
      throw Exception('Failed to get user by QR code: ${e.toString()}');
    }
  }

  // Remove a connection (for both users)
  Future<void> removeConnection(String connectionId) async {
    try {
      // Get the connection document to find both users
      final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();
      if (!connectionDoc.exists) {
        throw Exception('Connection not found');
      }

      final connectionData = connectionDoc.data()!;
      final userId = connectionData['userId'];
      final contactUserId = connectionData['contactUserId'];

      // Find and delete both connection records (bidirectional)
      final connections = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: userId)
          .where('contactUserId', isEqualTo: contactUserId)
          .get();

      final reverseConnections = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: contactUserId)
          .where('contactUserId', isEqualTo: userId)
          .get();

      // Delete all related connections
      final batch = _firestore.batch();
      
      for (final doc in connections.docs) {
        batch.delete(doc.reference);
      }
      
      for (final doc in reverseConnections.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove connection: ${e.toString()}');
    }
  }

  // Remove connection by user IDs
  Future<void> removeConnectionByUserIds(String userId, String contactUserId) async {
    try {
      // Find connections between these two users
      final connections = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: userId)
          .where('contactUserId', isEqualTo: contactUserId)
          .get();

      final reverseConnections = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: contactUserId)
          .where('contactUserId', isEqualTo: userId)
          .get();

      // Delete all related connections
      final batch = _firestore.batch();
      
      for (final doc in connections.docs) {
        batch.delete(doc.reference);
      }
      
      for (final doc in reverseConnections.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove connection: ${e.toString()}');
    }
  }

  // Create notification for connection request
  Future<void> _createConnectionRequestNotification({
    required String receiverId,
    required String senderName,
    required String senderId,
    required String requestId,
    String? message,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'receiverId': receiverId,
        'title': 'New Connection Request',
        'body': message != null && message.isNotEmpty 
            ? '$senderName wants to connect with you: "$message"'
            : '$senderName wants to connect with you',
        'data': {
          'type': 'connection_request',
          'senderId': senderId,
          'senderName': senderName,
          'requestId': requestId,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'connection_request',
      });
    } catch (e) {
      // Don't throw error for notification creation failure
      // Connection request should still succeed even if notification fails
      print('Failed to create connection request notification: $e');
    }
  }
}
