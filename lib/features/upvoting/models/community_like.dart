import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityLike {
  final String likedBy;
  final DateTime? timestamp;

  const CommunityLike({required this.likedBy, this.timestamp});

  factory CommunityLike.fromMap(Map<String, dynamic> map) {
    return CommunityLike(
      likedBy: (map['likedBy'] ?? '').toString(),
      timestamp: _readDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'likedBy': likedBy,
      'timestamp': timestamp == null
          ? Timestamp.now()
          : Timestamp.fromDate(timestamp!),
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
