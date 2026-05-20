import 'package:cloud_firestore/cloud_firestore.dart';

/// Optional proof data shown only when an issue has completion details.
class IssueCompletionProof {
  const IssueCompletionProof({
    required this.completedBy,
    required this.description,
    required this.proofImages,
    this.completedAt,
  });

  final String completedBy;
  final String description;
  final List<String> proofImages;
  final DateTime? completedAt;

  factory IssueCompletionProof.fromMap(Map<String, dynamic>? map) {
    // default every field to an empty value instead of forcing null checks
    return IssueCompletionProof(
      completedBy: _readString(map?['completedBy']),
      description: _readString(map?['description']),
      proofImages: _readStringList(map?['proofImg']),
      completedAt: _readDate(map?['completedAt']),
    );
  }

  bool get hasContent =>
      // avoid showing an empty proof block
      completedBy.isNotEmpty ||
      description.isNotEmpty ||
      proofImages.isNotEmpty ||
      completedAt != null;

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';

  static List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? const [] : [text];
  }
}
