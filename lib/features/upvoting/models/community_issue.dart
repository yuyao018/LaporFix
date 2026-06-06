import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_comment.dart';
import 'community_like.dart';

class CommunityIssueLocation {
  final String heading;
  final String postcode;
  final GeoPoint? preciseLocation;
  final double? latitude;
  final double? longitude;

  const CommunityIssueLocation({
    required this.heading,
    required this.postcode,
    this.preciseLocation,
    this.latitude,
    this.longitude,
  });

  String get displayName {
    if (heading.trim().isNotEmpty) return heading.trim();
    if (postcode.trim().isNotEmpty) return postcode.trim();
    if (preciseLocation != null) {
      return '${preciseLocation!.latitude.toStringAsFixed(5)}, ${preciseLocation!.longitude.toStringAsFixed(5)}';
    }
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
    }
    return 'Location unavailable';
  }

  factory CommunityIssueLocation.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    final geo = data['preciseLocation'] ?? data['precise_location'];
    GeoPoint? gp;
    if (geo is GeoPoint) gp = geo;

    // fallback if your existing issue docs store latitude/longitude fields:
    double? lat;
    double? lng;
    final rawLat = data['latitude'];
    final rawLng = data['longitude'];
    if (rawLat is num) lat = rawLat.toDouble();
    if (rawLng is num) lng = rawLng.toDouble();

    return CommunityIssueLocation(
      heading: (data['heading'] ?? '').toString(),
      postcode: (data['postcode'] ?? '').toString(),
      preciseLocation: gp,
      latitude: lat,
      longitude: lng,
    );
  }
}

class CommunityData {
  final List<CommunityLike> likes;
  final List<CommunityComment> comments;

  const CommunityData({required this.likes, required this.comments});

  factory CommunityData.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};

    final likesRaw = data['likes'];
    final commentsRaw = data['comments'];

    final likes = (likesRaw is List)
        ? likesRaw
              .whereType<Map>()
              .map((m) => CommunityLike.fromMap(Map<String, dynamic>.from(m)))
              .toList(growable: false)
        : const <CommunityLike>[];

    final comments = (commentsRaw is List)
        ? commentsRaw
              .whereType<Map>()
              .map(
                (m) => CommunityComment.fromMap(Map<String, dynamic>.from(m)),
              )
              .where(
                (c) => c.commentId.isNotEmpty,
              ) // commentId required for likes
              .toList(growable: false)
        : const <CommunityComment>[];

    return CommunityData(likes: likes, comments: comments);
  }
}

class CommunityIssue {
  final String id;
  final String title;
  final String category;
  final String description;
  final String status;
  final String reporterId;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final List<String> reportImages;
  final CommunityIssueLocation location;
  final CommunityData community;

  const CommunityIssue({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.reporterId,
    required this.isDeleted,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.reportImages,
    required this.location,
    required this.community,
  });

  int get likesCount => community.likes.length;
  int get commentsCount => community.comments.length;

  bool isLikedBy(String uid) => community.likes.any((l) => l.likedBy == uid);

  bool get isUnresolved {
    final s = status.trim().toLowerCase().replaceAll('_', ' ');
    return s == 'submitted' || s == 'in progress' || s == 'inprogress';
  }

  String get searchableText => [
    title,
    category,
    description,
    location.heading,
    location.postcode,
    id,
  ].join(' ').toLowerCase();

  factory CommunityIssue.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final community = CommunityData.fromMap(
      data['community'] is Map
          ? Map<String, dynamic>.from(data['community'])
          : null,
    );

    final locationMap = data['location'] is Map
        ? Map<String, dynamic>.from(data['location'])
        : null;

    final reportImgRaw = data['reportImg'];
    final reportImgs = (reportImgRaw is List)
        ? reportImgRaw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return CommunityIssue(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      reporterId: (data['reporterID'] ?? '').toString(),
      isDeleted: data['isDeleted'] == true,
      createdAt: _readDate(data['createdAt']),
      lastUpdatedAt: _readDate(data['lastUpdatedAt'] ?? data['lastUpdatedAt']),
      reportImages: reportImgs,
      location: CommunityIssueLocation.fromMap(locationMap),
      community: community,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
