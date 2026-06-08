import 'package:cloud_firestore/cloud_firestore.dart';

import 'issue_completion_proof.dart';
import 'issue_engagement.dart';
import 'issue_location.dart';
import 'issue_status.dart';

// complete model for one issue document.
class IssueSummary {
  const IssueSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.reporterId,
    required this.status,
    required this.location,
    required this.engagement,
    required this.reportImages,
    required this.isDeleted,
    required this.completionProof,
    required this.statusChangedAt,
    this.createdAt,
    this.estimatedResolutionAt,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String reporterId;
  final IssueStatus status;
  final IssueLocation location;
  final IssueEngagement engagement;
  final List<String> reportImages;
  final bool isDeleted;
  final IssueCompletionProof completionProof;
  final List<DateTime?> statusChangedAt;
  final DateTime? createdAt;
  final DateTime? estimatedResolutionAt;

  DateTime? get submittedAt => _timelineDate(0) ?? createdAt;
  DateTime? get inProgressAt => _timelineDate(1);
  DateTime? get completedAt => _timelineDate(2) ?? completionProof.completedAt;

  // get last updated date for UI
  DateTime? get latestStatusChangedAt {
    final dates = [...statusChangedAt.whereType<DateTime>(), ?completionProof.completedAt, ?createdAt];
    if (dates.isEmpty) return null;
    // compare
    dates.sort((left, right) => right.compareTo(left));
    return dates.first;
  }

  factory IssueSummary.fromMap({required String id, required Map<String, dynamic> data}) {
    // maps the Firebase document structure
    final status = IssueStatus.fromText(data['status']?.toString());
    final proofOfCompletion = _readMap(data['proofOfCompletion']);
    final createdAt = _readDate(data['createdAt']);

    return IssueSummary(
      id: id,
      title: _readString(data['title'], fallback: 'Untitled issue'),
      category: _readString(data['category'], fallback: 'Uncategorized'),
      description: _readString(data['description']),
      reporterId: _readString(data['reporterID']),
      status: status,
      location: IssueLocation.fromMap(_readMap(data['location'])),
      engagement: IssueEngagement.fromMap(_readMap(data['community'])),
      reportImages: _readStringList(data['reportImg']),
      isDeleted: data['isDeleted'] == true,
      completionProof: IssueCompletionProof.fromMap(proofOfCompletion),
      statusChangedAt: _readStatusChangedAt(
        data['statusChangedAt'],
        fallbackSubmittedAt: createdAt,
        fallbackCompletedAt: _readDate(proofOfCompletion?['completedAt']),
      ),
      createdAt: createdAt,
      estimatedResolutionAt: _readDate(data['estimatedResolutionAt']),
    );
  }

  // sed by the ViewModel for simple search
  String get searchableText =>
      [title, category, description, reporterId, status.label, location.postcodeName, location.postcode, id].join(' ').toLowerCase();

  DateTime? _timelineDate(int index) {
    if (index < 0 || index >= statusChangedAt.length) return null;
    return statusChangedAt[index];
  }

  static Map<String, dynamic>? _readMap(Object? value) {
    // normalization nested maps to Map<String, dynamic> for easier reading
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<DateTime?> _readStatusChangedAt(Object? value, {DateTime? fallbackSubmittedAt, DateTime? fallbackCompletedAt}) {
    // always return exactly three slots so view models can safely read by index
    final dates = List<DateTime?>.filled(3, null);

    if (value is Iterable) {
      final items = value.toList(growable: false);
      for (var index = 0; index < dates.length && index < items.length; index++) {
        dates[index] = _readDate(items[index]);
      }
    }

    dates[0] ??= fallbackSubmittedAt;
    dates[2] ??= fallbackCompletedAt;

    return dates;
  }

  static String _readString(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList(growable: false);
    }

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? const [] : [text];
  }
}
