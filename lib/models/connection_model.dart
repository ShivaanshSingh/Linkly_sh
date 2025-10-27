import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectionModel {
  final String id;
  final String userId;
  final String contactUserId;
  final String contactName;
  final String contactEmail;
  final String? contactPhone;
  final String? contactCompany;
  final String? connectionNote;
  final String? groupId;
  final String connectionMethod;
  final DateTime createdAt;
  final bool isNewConnection;

  ConnectionModel({
    required this.id,
    required this.userId,
    required this.contactUserId,
    required this.contactName,
    required this.contactEmail,
    this.contactPhone,
    this.contactCompany,
    this.connectionNote,
    this.groupId,
    required this.connectionMethod,
    required this.createdAt,
    this.isNewConnection = true,
  });

  factory ConnectionModel.fromMap(Map<String, dynamic> map) {
    return ConnectionModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      contactUserId: map['contactUserId'] ?? '',
      contactName: map['contactName'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'],
      contactCompany: map['contactCompany'],
      connectionNote: map['connectionNote'],
      groupId: map['groupId'],
      connectionMethod: map['connectionMethod'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isNewConnection: map['isNewConnection'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'contactUserId': contactUserId,
      'contactName': contactName,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'contactCompany': contactCompany,
      'connectionNote': connectionNote,
      'groupId': groupId,
      'connectionMethod': connectionMethod,
      'createdAt': Timestamp.fromDate(createdAt),
      'isNewConnection': isNewConnection,
    };
  }

  ConnectionModel copyWith({
    String? id,
    String? userId,
    String? contactUserId,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? contactCompany,
    String? connectionNote,
    String? groupId,
    String? connectionMethod,
    DateTime? createdAt,
    bool? isNewConnection,
  }) {
    return ConnectionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactUserId: contactUserId ?? this.contactUserId,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      contactCompany: contactCompany ?? this.contactCompany,
      connectionNote: connectionNote ?? this.connectionNote,
      groupId: groupId ?? this.groupId,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      createdAt: createdAt ?? this.createdAt,
      isNewConnection: isNewConnection ?? this.isNewConnection,
    );
  }
}
