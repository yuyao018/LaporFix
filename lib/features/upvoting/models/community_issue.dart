import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_comment.dart';
import 'community_like.dart';
import 'package:group2_urbanfix/features/status_tracker/summary/models/issue_completion_proof.dart';

class CommunityIssueLocation {
  final String heading;
  final String postcode;
  final String area;
  final String state;
  final String displayName;

  const CommunityIssueLocation({
    required this.heading,
    required this.postcode,
    this.area = '',
    this.state = '',
    this.displayName = '',
  });

  factory CommunityIssueLocation.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return CommunityIssueLocation(
      heading: (data['heading'] ?? '').toString(),
      postcode: (data['postcode'] ?? '').toString(),
      area: (data['area'] ?? '').toString(),
      state: (data['state'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
    );
  }

  /// Get formatted location with area and state for display
  String get formattedLocation {
    final parts = <String>[];
    
    // If we have area and state explicitly stored, use them
    if (area.isNotEmpty && state.isNotEmpty) {
      if (heading.isNotEmpty) parts.add(heading);
      parts.add(area);
      parts.add(state);
      return parts.join(', ');
    } 
    
    // Otherwise try to parse from displayName if available
    if (displayName.isNotEmpty) {
      final segments = displayName
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      
      // For Malaysian addresses, typically:
      // Street, Area/City, Postcode Area, State, Country
      // Or: Street, Area, State
      if (segments.length >= 3) {
        // Take first segment (street/heading)
        parts.add(segments[0]);
        
        // Try to find state (usually contains state names like Kuala Lumpur, Selangor, etc.)
        // Look backwards for the state (typically near the end, before country if present)
        for (int i = segments.length - 1; i >= 1; i--) {
          final seg = segments[i].toLowerCase();
          // Skip if it looks like a country or postcode
          if (seg.contains('malaysia') || 
              RegExp(r'^\d{5}$').hasMatch(seg)) {
            continue;
          }
          // Common Malaysian states
          if (_isMalaysianState(seg)) {
            // Add the segment before state as area (if exists and not postcode)
            if (i > 1 && !RegExp(r'^\d').hasMatch(segments[i - 1])) {
              parts.add(segments[i - 1]);
            }
            parts.add(segments[i]);
            break;
          }
        }
        
        // If we only got the street, add at least one more segment
        if (parts.length == 1 && segments.length > 1) {
          parts.add(segments[1]);
          if (segments.length > 2) {
            parts.add(segments[segments.length - 1]);
          }
        }
        
        return parts.join(', ');
      } else if (segments.length == 2) {
        // Simple format: just return both parts
        return displayName;
      }
    }
    
    // Fall back to heading only
    if (heading.isNotEmpty) {
      return heading;
    }
    
    return 'Location unavailable';
  }
  
  /// Check if a segment is a Malaysian state name
  bool _isMalaysianState(String segment) {
    final states = [
      'johor', 'kedah', 'kelantan', 'melaka', 'malacca',
      'negeri sembilan', 'pahang', 'penang', 'pulau pinang',
      'perak', 'perlis', 'sabah', 'sarawak', 'selangor',
      'terengganu', 'kuala lumpur', 'labuan', 'putrajaya',
    ];
    return states.any((state) => segment.contains(state));
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

  String get reporterDisplayText => 'Resident';

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
      isDeleted: data['isDeleted'] == true,
      createdAt: _readDate(data['createdAt']),
      lastUpdatedAt: _readDate(data['lastUpdatedAt']),
      reportImages: reportImgs,
      location: CommunityIssueLocation.fromMap(locationMap),
      community: CommunityData.fromMap(communityMap),
      completionProof: data['proofOfCompletion'] is Map
          ? IssueCompletionProof.fromMap(
              Map<String, dynamic>.from(data['proofOfCompletion'] as Map),
            )
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
