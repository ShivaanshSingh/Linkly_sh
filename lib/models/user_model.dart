import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String username;
  final String? profileImageUrl;
  final String? company;
  final String? position;
  final String? bio;
  final String? phoneNumber;
  final String accountType;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  final String? fcmToken;
  final Map<String, String> socialLinks;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.username,
    this.profileImageUrl,
    this.company,
    this.position,
    this.bio,
    this.phoneNumber,
    this.accountType = 'Public',
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.fcmToken,
    this.socialLinks = const {},
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      company: map['company'],
      position: map['position'],
      bio: map['bio'],
      phoneNumber: map['phoneNumber'],
      accountType: map['accountType'] ?? 'Public',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastSeen: (map['lastSeen'] as Timestamp).toDate(),
      isOnline: map['isOnline'] ?? false,
      fcmToken: map['fcmToken'],
      socialLinks: _parseSocialLinks(map['socialLinks']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      company: data['company'],
      position: data['position'],
      bio: data['bio'],
      phoneNumber: data['phoneNumber'],
      accountType: data['accountType'] ?? 'Public',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
      isOnline: data['isOnline'] ?? false,
      fcmToken: data['fcmToken'],
      socialLinks: _parseSocialLinks(data['socialLinks']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'company': company,
      'position': position,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'accountType': accountType,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
      'fcmToken': fcmToken,
      'socialLinks': socialLinks,
    };
  }

  static Map<String, String> _parseSocialLinks(dynamic socialLinksData) {
    if (socialLinksData == null) {
      return {};
    }
    
    try {
      if (socialLinksData is Map<String, dynamic>) {
        return socialLinksData.map((key, value) => MapEntry(key, value?.toString() ?? ''));
      } else if (socialLinksData is Map) {
        return socialLinksData.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
      } else {
        return {};
      }
    } catch (e) {
      debugPrint('Error parsing socialLinks: $e');
      return {};
    }
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? username,
    String? profileImageUrl,
    String? company,
    String? position,
    String? bio,
    String? phoneNumber,
    String? accountType,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
    String? fcmToken,
    Map<String, String>? socialLinks,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      company: company ?? this.company,
      position: position ?? this.position,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      fcmToken: fcmToken ?? this.fcmToken,
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }
}
