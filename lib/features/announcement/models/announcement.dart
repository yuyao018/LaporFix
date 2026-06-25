import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing an announcement from Firestore.
class Announcement {
  final String id;
  final String title;
  final String caption;
  final String colour;
  final String announcerId;
  final DateTime? createdAt;
  final bool isDeleted;
  final bool fcmSent;
  final List<AnnouncementAttachment> attachments;
  final AnnouncementTarget target;

  const Announcement({
    required this.id,
    required this.title,
    required this.caption,
    required this.colour,
    required this.announcerId,
    this.createdAt,
    required this.isDeleted,
    required this.fcmSent,
    required this.attachments,
    required this.target,
  });

  /// Check if this announcement is upcoming (today or future)
  bool get isUpcoming {
    if (createdAt == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !createdAt!.isBefore(today);
  }

  /// Check if this announcement is past
  bool get isPast => !isUpcoming;

  /// Create from Firestore document
  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final attachmentsRaw = data['attachments'] as List?;
    final attachments = (attachmentsRaw ?? [])
        .whereType<Map>()
        .map((m) => AnnouncementAttachment.fromMap(
              Map<String, dynamic>.from(m),
            ))
        .toList();

    final targetRaw = data['target'] as Map<String, dynamic>?;
    final target = AnnouncementTarget.fromMap(targetRaw ?? {});

    return Announcement(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      colour: (data['colour'] ?? 'green').toString(),
      announcerId: (data['announcerID'] ?? '').toString(),
      createdAt: _readDate(data['createdAt']),
      isDeleted: data['isDeleted'] == true,
      fcmSent: data['fcmSent'] == true,
      attachments: attachments,
      target: target,
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

/// Attachment for an announcement
class AnnouncementAttachment {
  final String url;
  final String name;
  final String type; // 'image', 'document', 'video'

  const AnnouncementAttachment({
    required this.url,
    required this.name,
    required this.type,
  });

  factory AnnouncementAttachment.fromMap(Map<String, dynamic> map) {
    return AnnouncementAttachment(
      url: (map['url'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      type: (map['type'] ?? 'document').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'name': name,
      'type': type,
    };
  }
}

/// Target audience and location for an announcement
class AnnouncementTarget {
  final String audience; // 'all', 'admin', 'residents'
  final AnnouncementLocation location;

  const AnnouncementTarget({
    required this.audience,
    required this.location,
  });

  factory AnnouncementTarget.fromMap(Map<String, dynamic> map) {
    final locationRaw = map['location'] as Map<String, dynamic>?;
    return AnnouncementTarget(
      audience: (map['audience'] ?? 'all').toString(),
      location: AnnouncementLocation.fromMap(locationRaw ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audience': audience,
      'location': location.toMap(),
    };
  }
}

/// Location for an announcement
class AnnouncementLocation {
  final String area;
  final String city;
  final String state;
  final String full;

  const AnnouncementLocation({
    required this.area,
    required this.city,
    required this.state,
    required this.full,
  });

  /// Get short formatted location "Area, State" or "City, State"
  String get shortDisplay {
    if (area.isNotEmpty && state.isNotEmpty) return '$area, $state';
    if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
    if (area.isNotEmpty) return area;
    if (full.isNotEmpty) return _standardizeAddress(full);
    return 'Unknown';
  }

  /// Extract suburb/city + state from full address
  String _standardizeAddress(String address) {
    final parts = address
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return parts.sublist(parts.length - 2).join(', ');
    }
    return parts.isNotEmpty ? parts.last : address;
  }

  factory AnnouncementLocation.fromMap(Map<String, dynamic> map) {
    return AnnouncementLocation(
      area: (map['area'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      full: (map['full'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'area': area,
      'city': city,
      'state': state,
      'full': full,
    };
  }
}

/// User profile data needed for announcements
class UserProfile {
  final String uid;
  final String role;
  final String homeAddress;
  final String area;
  final String state;

  const UserProfile({
    required this.uid,
    required this.role,
    required this.homeAddress,
    required this.area,
    required this.state,
  });

  bool get isAdmin => role == 'admin';

  /// Get standardized location display
  String get locationDisplay {
    if (area.isNotEmpty && state.isNotEmpty) return '$area, $state';
    if (homeAddress.isNotEmpty) {
      final parts = homeAddress
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        return parts.sublist(parts.length - 2).join(', ');
      }
      return parts.isNotEmpty ? parts.last : homeAddress;
    }
    return 'All Locations';
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      role: (data['role'] ?? 'user').toString(),
      homeAddress: (data['homeAddress'] ?? '').toString(),
      area: (data['area'] ?? '').toString(),
      state: (data['state'] ?? '').toString(),
    );
  }
}
