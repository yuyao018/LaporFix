import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_comment.dart';
import 'community_like.dart';
import 'package:group2_urbanfix/features/status_tracker/summary/models/issue_completion_proof.dart';

class CommunityIssueLocation {
  final String heading;
  final String postcode;
  final GeoPoint? preciseLocation; // real schema: precise_location

  const CommunityIssueLocation({
    required this.heading,
    required this.postcode,
    this.preciseLocation,
  });

  factory CommunityIssueLocation.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    final geo = data['precise_location']; // <-- exact field name
    return CommunityIssueLocation(
      heading: (data['heading'] ?? '').toString(),
      postcode: (data['postcode'] ?? '').toString(),
      preciseLocation: geo is GeoPoint ? geo : null,
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
              .where((c) => c.comment.trim().isNotEmpty)
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

  final String publicReporterName;
  final String reporterVisibility;

  final bool isDeleted;

  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;

  final List<String> reportImages;
  final CommunityIssueLocation location;
  final CommunityData community;
  final IssueCompletionProof? completionProof;

  const CommunityIssue({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.reporterId,
    required this.publicReporterName,
    required this.reporterVisibility,
    required this.isDeleted,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.reportImages,
    required this.location,
    required this.community,
    this.completionProof,
  });

  int get likesCount => community.likes.length;
  int get commentsCount => community.comments.length;

  bool isLikedBy(String uid) => community.likes.any((l) => l.likedBy == uid);

  bool get isUnresolved {
    final s = status.trim().toLowerCase().replaceAll('_', ' ');
    return s == 'submitted' || s == 'in progress' || s == 'inprogress';
  }

  DateTime? get sortDate => createdAt ?? lastUpdatedAt;

  String get reporterDisplayText {
    final vis = reporterVisibility.trim().toLowerCase();
    if (vis == 'anonymous') return 'Anonymous';
    if (publicReporterName.trim().isNotEmpty) return publicReporterName.trim();
    return 'Resident';
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

    final communityMap = data['community'] is Map
        ? Map<String, dynamic>.from(data['community'] as Map)
        : null;

    final locationMap = data['location'] is Map
        ? Map<String, dynamic>.from(data['location'] as Map)
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
      publicReporterName: (data['publicReporterName'] ?? '').toString(),
      reporterVisibility: (data['reporterVisibility'] ?? '').toString(),
      isDeleted: data['isDeleted'] == true,
      createdAt: _readDate(data['createdAt']),
      lastUpdatedAt: _readDate(data['lastUpdatedAt']),
      reportImages: reportImgs,
      location: CommunityIssueLocation.fromMap(locationMap),
      community: CommunityData.fromMap(communityMap),
      completionProof: data['proofOfCompletion'] is Map
          ? IssueCompletionProof.fromMap(
              Map<String, dynamic>.from(data['proofOfCompletion'] as Map))
          : null,
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
