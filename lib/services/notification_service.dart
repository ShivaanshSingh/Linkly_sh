import 'package:flutter/material.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService extends ChangeNotifier {
  // Temporarily disable Firebase dependencies
  // final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  bool _isLoading = false;

  String? get fcmToken => _fcmToken;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    try {
      _setLoading(true);
      debugPrint('Mock: Initializing notifications');
      
      // Simulate initialization delay
      await Future.delayed(const Duration(seconds: 1));
      
      _fcmToken = 'mock_fcm_token';
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveTokenToFirestore(String userId) async {
    if (_fcmToken == null) return;

    try {
      debugPrint('Mock: Saving FCM token for $userId');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    required String receiverId,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('Mock: Sending notification: $title to $receiverId');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getNotifications(String userId) {
    debugPrint('Mock: Getting notifications for $userId');
    // Return empty stream for now
    return Stream.value([]);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      debugPrint('Mock: Marking notification $notificationId as read');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(dynamic message) async {
  debugPrint('Mock: Handling a background message: ${message.toString()}');
}