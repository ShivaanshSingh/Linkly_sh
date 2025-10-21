import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String? profileImageUrl;
  final String? company;
  final String? position;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.profileImageUrl,
    this.company,
    this.position,
    this.bio,
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      company: map['company'],
      position: map['position'],
      bio: map['bio'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastSeen: (map['lastSeen'] as Timestamp).toDate(),
      isOnline: map['isOnline'] ?? false,
      fcmToken: map['fcmToken'],
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      company: data['company'],
      position: data['position'],
      bio: data['bio'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
      isOnline: data['isOnline'] ?? false,
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'profileImageUrl': profileImageUrl,
      'company': company,
      'position': position,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? profileImageUrl,
    String? company,
    String? position,
    String? bio,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      company: company ?? this.company,
      position: position ?? this.position,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
