import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityUserProfile {
  final String uid;
  final String username;
  final String photoURL;
  final String area;
  final String role;

  const CommunityUserProfile({
    required this.uid,
    required this.username,
    required this.photoURL,
    required this.area,
    required this.role,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  String get displayName =>
      username.trim().isNotEmpty ? username.trim() : 'Resident';

  factory CommunityUserProfile.fromMap(Map<String, dynamic> map) {
    return CommunityUserProfile(
      uid: (map['uid'] ?? '').toString(),
      username: (map['username'] ?? map['displayName'] ?? '').toString(),
      photoURL: (map['photoURL'] ?? '').toString(),
      area: (map['area'] ?? '').toString(),
      role: (map['role'] ?? 'user').toString(),
    );
  }

  static CommunityUserProfile? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;
    return CommunityUserProfile.fromMap(data);
  }
}
