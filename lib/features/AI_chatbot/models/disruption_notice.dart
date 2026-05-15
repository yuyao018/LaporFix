import 'package:cloud_firestore/cloud_firestore.dart';

enum DisruptionType { water, power, road }

enum MaintenanceStatus { repairing, restoring }

class DisruptionNotice {
  final DisruptionType type;
  final String title;
  final MaintenanceStatus status;
  final DateTime estimatedRestoration;
  final String reason;

  const DisruptionNotice({
    required this.type,
    required this.title,
    required this.status,
    required this.estimatedRestoration,
    required this.reason,
  });

  static DisruptionType classifyType(Map<String, dynamic> data) {
    final combined =
        '${data['title'] ?? ''} ${data['caption'] ?? ''}'.toLowerCase();

    if (_roadKeywords.any((kw) => combined.contains(kw))) {
      return DisruptionType.road;
    }
    if (_powerKeywords.any((kw) => combined.contains(kw))) {
      return DisruptionType.power;
    }
    if (_waterKeywords.any((kw) => combined.contains(kw))) {
      return DisruptionType.water;
    }
    if (combined.contains('maintenance') ||
        combined.contains('penyelenggaraan')) {
      return DisruptionType.road;
    }
    return DisruptionType.water;
  }

  static bool isDisruptionAnnouncement(Map<String, dynamic> data) {
    final combined =
        '${data['title'] ?? ''} ${data['caption'] ?? ''}'.toLowerCase();
    const keywords = [
      ..._waterKeywords,
      ..._powerKeywords,
      ..._roadKeywords,
      'outage',
      'disruption',
      'gangguan',
      'cut',
      'putus',
      'maintenance',
      'penyelenggaraan',
    ];
    return keywords.any((kw) => combined.contains(kw));
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'status': status.name,
        'estimated_restoration': estimatedRestoration.toIso8601String(),
        'reason': reason,
      };

  factory DisruptionNotice.fromJson(Map<String, dynamic> json) {
    return DisruptionNotice(
      type: DisruptionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => DisruptionType.water,
      ),
      title: json['title'] as String? ?? '',
      status: MaintenanceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MaintenanceStatus.repairing,
      ),
      estimatedRestoration: DateTime.tryParse(
            json['estimated_restoration'] as String? ?? '') ??
          DateTime.now(),
      reason: json['reason'] as String? ?? '',
    );
  }

  factory DisruptionNotice.fromAnnouncement(Map<String, dynamic> data) {
    final type = classifyType(data);
    final title = (data['title'] ?? _defaultTitle(type)).toString();
    final caption = (data['caption'] ?? '').toString();
    final combined = '$title $caption'.toLowerCase();

    MaintenanceStatus status = MaintenanceStatus.repairing;
    if (combined.contains('restor') ||
        combined.contains('resume') ||
        combined.contains('pulih')) {
      status = MaintenanceStatus.restoring;
    }

    DateTime estimated = DateTime.now().add(const Duration(hours: 24));
    final rawEstimate = data['estimatedRestoration'] ?? data['restorationAt'];
    if (rawEstimate is Timestamp) {
      estimated = rawEstimate.toDate();
    } else if (rawEstimate is String) {
      estimated = DateTime.tryParse(rawEstimate) ?? estimated;
    } else {
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        estimated = createdAt.toDate().add(const Duration(hours: 24));
      }
    }

    final reason = caption.isNotEmpty ? caption : _defaultReason(type);

    return DisruptionNotice(
      type: type,
      title: title,
      status: status,
      estimatedRestoration: estimated,
      reason: reason,
    );
  }

  static String _defaultTitle(DisruptionType type) => switch (type) {
        DisruptionType.water => 'Water supply disruption',
        DisruptionType.power => 'Power supply disruption',
        DisruptionType.road => 'Road maintenance',
      };

  static String _defaultReason(DisruptionType type) => switch (type) {
        DisruptionType.water =>
          'Scheduled maintenance affecting water supply in your area.',
        DisruptionType.power =>
          'Scheduled maintenance affecting electricity supply in your area.',
        DisruptionType.road =>
          'Road works and maintenance affecting traffic in your area.',
      };

  static const _waterKeywords = [
    'water',
    'air',
    'bekalan air',
    'paip',
    'pipe',
    'syabas',
    'air selangor',
  ];

  static const _powerKeywords = [
    'power',
    'electric',
    'elektrik',
    'tenaga',
    'tnb',
    'bekalan elektrik',
    'blackout',
  ];

  static const _roadKeywords = [
    'road',
    'jalan',
    'highway',
    'lebuhraya',
    'traffic',
    'lalu lintas',
    'construction',
    'kerja',
    'pothole',
    'resurfacing',
    'lubang',
    'mbpj',
    'dbkl',
  ];
}
