import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityUserProfile {
  final String uid;
  final String username;
  final String photoURL;
  final String area;
  final String role;
  final bool profileVisibleToCommunity;

  const CommunityUserProfile({
    required this.uid,
    required this.username,
    required this.photoURL,
    required this.area,
    required this.role,
    required this.profileVisibleToCommunity,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  String get displayName =>
      username.trim().isNotEmpty ? username.trim() : 'Resident';

  factory CommunityUserProfile.fromMap(Map<String, dynamic> map) {
    final appSettings = map['appSettings'] is Map
        ? Map<String, dynamic>.from(map['appSettings'] as Map)
        : const <String, dynamic>{};

    return CommunityUserProfile(
      uid: (map['uid'] ?? '').toString(),
      username: (map['username'] ?? map['displayName'] ?? '').toString(),
      photoURL: (map['photoURL'] ?? '').toString(),
      area: (map['area'] ?? '').toString(),
      role: (map['role'] ?? 'user').toString(),
      profileVisibleToCommunity: _readBool(
        appSettings['profileVisibleToCommunity'] ??
            map['profileVisibleToCommunity'],
        defaultValue: false,
      ),
    );
  }

  static CommunityUserProfile? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;
    return CommunityUserProfile.fromMap(data);
  }

  static bool _readBool(Object? value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return defaultValue;
  }
}
