import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_like.dart';

class CommunityComment {
  final String commentId;
  final String comment;
  final String userId;
  final String userName;
  final String userRole; // 'admin' or 'user'
  final String userLocation; // home area/state or short address
  final DateTime? timestamp;
  final List<CommunityLike> likes;

  const CommunityComment({
    required this.commentId,
    required this.comment,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.userLocation,
    required this.timestamp,
    required this.likes,
  });

  bool get isAdmin => userRole.trim().toLowerCase() == 'admin';

  int get likesCount => likes.length;

  bool isLikedBy(String uid) => likes.any((l) => l.likedBy == uid);

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    final likesRaw = map['likes'];
    final likes = (likesRaw is List)
        ? likesRaw
              .whereType<Map>()
              .map((m) => CommunityLike.fromMap(Map<String, dynamic>.from(m)))
              .toList(growable: false)
        : const <CommunityLike>[];

    return CommunityComment(
      commentId: (map['commentId'] ?? '').toString(),
      comment: (map['comment'] ?? '').toString(),
      userId: (map['userId'] ?? map['commentedBy'] ?? '').toString(),
      userName: (map['userName'] ?? 'User').toString(),
      userRole: (map['userRole'] ?? 'user').toString(),
      userLocation: (map['userLocation'] ?? '').toString(),
      timestamp: _readDate(map['timestamp']),
      likes: likes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'comment': comment,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'userLocation': userLocation,
      'timestamp': timestamp == null
          ? Timestamp.now()
          : Timestamp.fromDate(timestamp!),
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
