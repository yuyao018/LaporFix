import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../summary/models/issue_status.dart';
import '../models/proof_attachment.dart';

// data layer for admin/user status updates
class UpdateIssueRepository {
  UpdateIssueRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.collectionPath = 'issue',
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String collectionPath;

  Future<void> updateStatus({
    required String issueId,
    required IssueStatus status,
  }) {
    final changedAt = Timestamp.now();

    return _firestore.runTransaction((transaction) async {
      final issueRef = _issueDocument(issueId);
      final snapshot = await transaction.get(issueRef);
      final timeline = _readStatusChangedAt(snapshot.data());
      // only update slot for chosen status
      timeline[_statusTimelineIndex(status)] = changedAt;

      transaction.update(issueRef, {
        'status': status.label,
        'statusChangedAt': timeline,
      });
    });
  }

  Future<void> completeIssue({
    required String issueId,
    required String description,
    required List<ProofAttachment> proofAttachments,
  }) async {
    // proof files must be uploaded first to get URLs
    // then only can write completion details
    final completedBy = await _completedByText();
    final proofUrls = await _uploadProofAttachments(
      issueId: issueId,
      attachments: proofAttachments,
    );

    final completedAt = Timestamp.now();

    return _firestore.runTransaction((transaction) async {
      final issueRef = _issueDocument(issueId);
      final snapshot = await transaction.get(issueRef);
      final timeline = _readStatusChangedAt(snapshot.data());
      timeline[_statusTimelineIndex(IssueStatus.completed)] = completedAt;

      transaction.update(issueRef, {
        'status': IssueStatus.completed.label,
        'statusChangedAt': timeline,
        'proofOfCompletion': {
          'completedBy': completedBy,
          'description': description.trim(),
          'proofImg': proofUrls,
          'completedAt': completedAt,
        },
      });
    });
  }

  DocumentReference<Map<String, dynamic>> _issueDocument(String issueId) {
    return _firestore.collection(collectionPath).doc(issueId);
  }

  List<Timestamp?> _readStatusChangedAt(Map<String, dynamic>? data) {
    final timeline = List<Timestamp?>.filled(3, null);
    final value = data?['statusChangedAt'];

    if (value is Iterable) {
      final items = value.toList(growable: false);
      for (
        var index = 0;
        index < timeline.length && index < items.length;
        index++
      ) {
        timeline[index] = _readTimestamp(items[index]);
      }
    }

    timeline[0] ??= _readTimestamp(data?['createdAt']);
    final proofOfCompletion = data?['proofOfCompletion'];
    timeline[2] ??= _readTimestamp(
      proofOfCompletion is Map ? proofOfCompletion['completedAt'] : null,
    );

    return timeline;
  }

  Timestamp? _readTimestamp(Object? value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is int) {
      return Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(value));
    }
    if (value is String) {
      final date = DateTime.tryParse(value);
      return date == null ? null : Timestamp.fromDate(date);
    }
    return null;
  }

  int _statusTimelineIndex(IssueStatus status) {
    return switch (status) {
      IssueStatus.submitted || IssueStatus.all || IssueStatus.unknown => 0,
      IssueStatus.inProgress => 1,
      IssueStatus.completed => 2,
    };
  }

  Future<List<String>> _uploadProofAttachments({
    required String issueId,
    required List<ProofAttachment> attachments,
  }) async {
    final uploadedUrls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // include timestamp and index in storage path
    // avoid collisions if two proof share same original file
    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final ref = FirebaseStorage.instance
          .ref()
          .child('issue_completion_proofs')
          .child(issueId)
          .child('${timestamp}_${index}_${attachment.name}');

      await ref.putFile(
        attachment.file,
        SettableMetadata(contentType: attachment.contentType),
      );
      uploadedUrls.add(await ref.getDownloadURL());
    }

    return uploadedUrls;
  }

  Future<String> _completedByText() async {
    final user = _auth.currentUser;
    if (user == null) return 'Unknown (unknown)';

    // store both display name and uid because usernames can change
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final username =
        (data?['username'] ?? user.displayName ?? user.email ?? 'User')
            .toString()
            .trim();

    return '${username.isEmpty ? 'User' : username} (${user.uid})';
  }
}
