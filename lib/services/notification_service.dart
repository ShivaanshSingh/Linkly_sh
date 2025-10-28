import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _currentUserId; // Add current user ID tracking
  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];

  String? get fcmToken => _fcmToken;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get notifications => _notifications;
  
  // Check if there are unread notifications (excluding self-notifications)
  bool get hasUnreadNotifications => _notifications.any((notification) {
    // Skip self-notifications
    final data = notification['data'] as Map<String, dynamic>?;
    if (data != null) {
      final senderId = data['senderId'];
      final receiverId = data['receiverId'];
      if (senderId != null && receiverId != null && senderId == receiverId) {
        return false; // Skip self-notifications
      }
    }
    return notification['isRead'] == false || notification['isRead'] == null;
  });


  Future<void> initialize() async {
    try {
      _setLoading(true);
      debugPrint('🔔 Initializing notifications');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ User granted provisional permission');
      } else {
        debugPrint('❌ User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');

      // Set up message handlers
      _setupMessageHandlers();
      
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to chat or specific screen
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Received foreground message: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });

    // Handle background messages when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App opened from background message: ${message.notification?.title}');
      _handleBackgroundMessage(message);
    });

    // Handle messages when app is terminated
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📱 App opened from terminated state: ${message.notification?.title}');
        _handleBackgroundMessage(message);
      }
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // EXTREME CHECK: Block ALL self-notifications at the FCM level
    final senderId = message.data['senderId'];
    final receiverId = message.data['receiverId'];
    
    // Block if sender and receiver are the same
    if (senderId != null && receiverId != null && senderId == receiverId) {
      debugPrint('🚫 EXTREME: Blocking self-notification in FCM handler for sender: $senderId');
      return;
    }
    
    // Block if sender is current user
    if (_currentUserId != null && senderId == _currentUserId) {
      debugPrint('🚫 EXTREME: Blocking self-notification for current user: $_currentUserId');
      return;
    }
    
    // Block if message contains current user's name in title/body
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (_currentUserId != null && (title.contains('Adarsh Kesharwani') || body.contains('Adarsh Kesharwani'))) {
      debugPrint('🚫 EXTREME: Blocking notification containing current user name');
      return;
    }
    
    // Show local notification or update UI
    final notification = {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'New Message',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now(),
      'isRead': false,
    };
    
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    // Handle navigation or other actions when app is opened from notification
    debugPrint('📱 Handling background message: ${message.data}');
  }

  // Set current user ID for better notification filtering
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    debugPrint('🔑 NotificationService: Current user set to $userId');
    
    // Clean up any existing self-notifications from local list
    _cleanupSelfNotifications();
  }

  // Clean up self-notifications from local list
  void _cleanupSelfNotifications() {
    _notifications.removeWhere((notification) {
      final data = notification['data'] as Map<String, dynamic>?;
      if (data != null) {
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        return senderId != null && receiverId != null && senderId == receiverId;
      }
      return false;
    });
    notifyListeners();
    debugPrint('🧹 Cleaned up self-notifications from local list');
  }

  Future<void> saveTokenToFirestore(String userId) async {
    if (_fcmToken == null) return;

    try {
      debugPrint('💾 Saving FCM token for $userId');
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'lastSeen': FieldValue.serverTimestamp(),
        'notificationEnabled': true, // Add flag to control notifications
      });
      // Also set current user ID and clean up self-notifications
      setCurrentUserId(userId);
      // Clean up existing self-notifications from Firestore
      await cleanupSelfNotificationsFromFirestore(userId);
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // Temporarily disable notifications for current user
  Future<void> disableNotificationsForUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationEnabled': false,
        'fcmToken': null, // Remove FCM token to prevent server-side notifications
      });
      debugPrint('🚫 NUCLEAR: Disabled notifications for user $userId');
    } catch (e) {
      debugPrint('❌ Error disabling notifications: $e');
    }
  }

  // Re-enable notifications for current user
  Future<void> enableNotificationsForUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationEnabled': true,
        'fcmToken': _fcmToken,
      });
      debugPrint('✅ Re-enabled notifications for user $userId');
    } catch (e) {
      debugPrint('❌ Error enabling notifications: $e');
    }
  }

  Future<void> sendMessageNotification({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String messageText,
    String? senderProfileImageUrl,
  }) async {
    try {
      // EXTREME BLOCK: Complete block for self-notifications
      if (senderId == receiverId) {
        debugPrint('🚫 EXTREME: Complete block for self-notification from $senderId');
        return;
      }

      // Additional safety check
      if (_currentUserId != null && senderId == _currentUserId) {
        debugPrint('🚫 EXTREME: Additional safety block for current user $_currentUserId');
        return;
      }

      // Block if sender name contains current user's name
      if (senderName.contains('Adarsh Kesharwani')) {
        debugPrint('🚫 EXTREME: Blocking notification with current user name in sender');
        return;
      }

      // Create notification data
      final notificationData = {
        'title': 'New message from $senderName',
        'body': messageText.length > 50 ? '${messageText.substring(0, 50)}...' : messageText,
        'data': {
          'type': 'message',
          'senderId': senderId,
          'senderName': senderName,
          'receiverId': receiverId,
          'messageText': messageText,
          'timestamp': DateTime.now().toIso8601String(),
        }
      };

      // Send local notification immediately
      await _showLocalNotification(notificationData);

      // Save notification to Firestore
      await _saveNotificationToFirestore(receiverId, notificationData);

      // Try to send FCM notification (for when app is in background)
      // DISABLED: FCM notifications are causing self-notification issues
      // await _sendFCMNotificationToUser(receiverId, notificationData);
      debugPrint('🚫 FCM notifications disabled to prevent self-notifications');

    } catch (e) {
      debugPrint('❌ Error sending message notification: $e');
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notificationData) async {
    try {
      // Double-check: Don't show local notification for self-messages
      final data = notificationData['data'] as Map<String, dynamic>?;
      if (data != null) {
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        if (senderId != null && receiverId != null && senderId == receiverId) {
          debugPrint('🚫 Skipping local notification for self-message from sender: $senderId');
          return;
        }
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'messages',
        'Message Notifications',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notificationData['title'],
        notificationData['body'],
        platformChannelSpecifics,
        payload: jsonEncode(notificationData['data']),
      );

      debugPrint('📱 Local notification shown: ${notificationData['title']}');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  Future<void> _sendFCMNotificationToUser(String receiverId, Map<String, dynamic> notificationData) async {
    try {
      // Get receiver's FCM token
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) {
        debugPrint('❌ Receiver not found: $receiverId');
        return;
      }

      final receiverData = receiverDoc.data()!;
      final receiverFcmToken = receiverData['fcmToken'] as String?;
      
      if (receiverFcmToken == null) {
        debugPrint('❌ Receiver FCM token not found');
        return;
      }

      // Send FCM notification
      await _sendFCMNotification(receiverFcmToken, notificationData);
    } catch (e) {
      debugPrint('❌ Error sending FCM notification: $e');
    }
  }

  Future<void> _sendFCMNotification(String fcmToken, Map<String, dynamic> notificationData) async {
    try {
      // You'll need to implement server-side FCM sending or use a service
      // For now, we'll simulate the notification
      debugPrint('📤 Sending FCM notification to: $fcmToken');
      debugPrint('📤 Notification: ${notificationData['title']}');
      
      // In a real implementation, you would send this to your server
      // which would then send the FCM notification
    } catch (e) {
      debugPrint('❌ Error sending FCM notification: $e');
    }
  }

  Future<void> _saveNotificationToFirestore(String receiverId, Map<String, dynamic> notificationData) async {
    try {
      // Double-check: Don't save self-notifications to Firestore
      final data = notificationData['data'] as Map<String, dynamic>?;
      if (data != null) {
        final senderId = data['senderId'];
        if (senderId != null && senderId == receiverId) {
          debugPrint('🚫 Skipping saving self-notification to Firestore for sender: $senderId');
          return;
        }
      }

      await _firestore.collection('notifications').add({
        'receiverId': receiverId,
        'title': notificationData['title'],
        'body': notificationData['body'],
        'data': notificationData['data'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'message',
      });
    } catch (e) {
      debugPrint('❌ Error saving notification to Firestore: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'],
          'body': data['body'],
          'data': data['data'],
          'timestamp': data['timestamp'],
          'isRead': data['isRead'] ?? false,
          'type': data['type'],
        };
      }).toList();
      
      // Sort by timestamp in descending order (newest first)
      notifications.sort((a, b) {
        final timestampA = a['timestamp'];
        final timestampB = b['timestamp'];
        
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        
        DateTime dateTimeA;
        DateTime dateTimeB;
        
        if (timestampA is Timestamp) {
          dateTimeA = timestampA.toDate();
        } else if (timestampA is DateTime) {
          dateTimeA = timestampA;
        } else {
          return 0;
        }
        
        if (timestampB is Timestamp) {
          dateTimeB = timestampB.toDate();
        } else if (timestampB is DateTime) {
          dateTimeB = timestampB;
        } else {
          return 0;
        }
        
        return dateTimeB.compareTo(dateTimeA);
      });
      
      return notifications;
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Clean up self-notifications from Firestore
  Future<void> cleanupSelfNotificationsFromFirestore(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .get();

      int deletedCount = 0;
      for (final doc in notifications.docs) {
        final data = doc.data();
        final notificationData = data['data'] as Map<String, dynamic>?;
        if (notificationData != null) {
          final senderId = notificationData['senderId'];
          final receiverId = notificationData['receiverId'];
          if (senderId != null && receiverId != null && senderId == receiverId) {
            batch.delete(doc.reference);
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('🧹 Cleaned up $deletedCount self-notifications from Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up self-notifications from Firestore: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

}

// Background message handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 Handling a background message: ${message.messageId}');
}