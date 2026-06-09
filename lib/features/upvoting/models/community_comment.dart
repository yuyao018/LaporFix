import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_like.dart';

class CommunityComment {
  final String comment; // required by your schema
  final DateTime? timestamp;

  /// Used to match comments reliably inside the Firestore array.
  final int? timestampMillis;

  // extra fields (new comments will include these; old comments may be missing them)
  final String userId;
  final String userName;
  final String userRole; // 'admin' or 'user'
  final String userLocation; // we store users.area for new comments

  final List<CommunityLike> likes;

  const CommunityComment({
    required this.comment,
    required this.timestamp,
    required this.timestampMillis,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.userLocation,
    required this.likes,
  });

  bool get isAdmin => userRole.trim().toLowerCase() == 'admin';
  int get likesCount => likes.length;

  bool isLikedBy(String uid) => likes.any((l) => l.likedBy == uid);

  /// Stable identifier for matching a comment inside Firestore array.
  /// Format: userId|timestampMillis|commentText
  String get matchKey {
    final ts = timestampMillis?.toString() ?? '';
    return '${userId.trim()}|$ts|${comment.trim()}';
  }

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    final dt = _readDate(map['timestamp']);
    final millis = dt?.millisecondsSinceEpoch;

    final likesRaw = map['likes'];
    final likes = (likesRaw is List)
        ? likesRaw
              .whereType<Map>()
              .map((m) => CommunityLike.fromMap(Map<String, dynamic>.from(m)))
              .toList(growable: false)
        : const <CommunityLike>[];

    return CommunityComment(
      comment: (map['comment'] ?? '').toString(),
      timestamp: dt,
      timestampMillis: millis,
      userId: (map['userId'] ?? map['commentedBy'] ?? '').toString(),
      userName: (map['userName'] ?? 'User').toString(),
      userRole: (map['userRole'] ?? 'user').toString(),
      userLocation: (map['userLocation'] ?? '').toString(),
      likes: likes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'comment': comment,
      'timestamp': Timestamp.now(),
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'userLocation': userLocation,
      'likes': likes.map((l) => l.toMap()).toList(growable: false),
    };
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
