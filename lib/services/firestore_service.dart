import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile_model.dart';
import '../models/connection_model.dart';
import '../models/message_model.dart';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Profile Management
  Future<void> createProfile(ProfileModel profile) async {
    try {
      await _firestore.collection('profiles').doc(profile.userId).set(profile.toMap());
    } catch (e) {
      debugPrint('Error creating profile: $e');
      rethrow;
    }
  }

  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (doc.exists) {
        return ProfileModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  Future<void> updateProfile(ProfileModel profile) async {
    try {
      await _firestore.collection('profiles').doc(profile.userId).update(profile.toMap());
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // Connections Management
  Future<void> addConnection(ConnectionModel connection) async {
    try {
      await _firestore.collection('connections').add(connection.toMap());
    } catch (e) {
      debugPrint('Error adding connection: $e');
      rethrow;
    }
  }

  Stream<List<ConnectionModel>> getConnections(String userId) {
    return _firestore
        .collection('connections')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConnectionModel.fromMap(doc.data()))
            .toList());
  }

  Future<void> deleteConnection(String connectionId) async {
    try {
      await _firestore.collection('connections').doc(connectionId).delete();
    } catch (e) {
      debugPrint('Error deleting connection: $e');
      rethrow;
    }
  }

  // Messages Management
  Future<void> sendMessage(MessageModel message) async {
    try {
      await _firestore.collection('messages').add(message.toMap());
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Stream<List<MessageModel>> getMessages(String userId, String contactUserId) {
    return _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .where('receiverId', isEqualTo: contactUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  Stream<List<MessageModel>> getConversations(String userId) {
    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // Search Users
  Future<List<ProfileModel>> searchUsers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('profiles')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + 'z')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => ProfileModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Analytics
  Future<Map<String, int>> getProfileAnalytics(String userId) async {
    try {
      final connectionsSnapshot = await _firestore
          .collection('connections')
          .where('userId', isEqualTo: userId)
          .get();

      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .get();

      return {
        'totalConnections': connectionsSnapshot.docs.length,
        'totalMessages': messagesSnapshot.docs.length,
        'unreadMessages': messagesSnapshot.docs
            .where((doc) => !doc.data()['isRead'])
            .length,
      };
    } catch (e) {
      debugPrint('Error getting analytics: $e');
      return {};
    }
  }
}
