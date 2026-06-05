import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/issue_summary.dart';

// data layer
class StatusTrackerRepository {
  StatusTrackerRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.collectionPath = defaultCollectionPath,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // collection name
  static const String defaultCollectionPath = 'issue';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String collectionPath;

  // watches every issue document, converts raw Firestore maps into model
  Stream<List<IssueSummary>> watchIssues() async* {
    // depends on the current user's role
    final query = await _issueQueryForCurrentUser();
    if (query == null) {
      yield const [];
      return;
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => IssueSummary.fromMap(id: doc.id, data: doc.data()))
          .toList(growable: false);
    });
  }

  // watches every issue in the system for cross-user category benchmarks
  Stream<List<IssueSummary>> watchSystemIssues() {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => IssueSummary.fromMap(id: doc.id, data: doc.data()))
          .toList(growable: false);
    });
  }

  // Allows the detail page can refresh immediately after an update
  Stream<IssueSummary> watchIssue(String issueId) {
    return _firestore.collection(collectionPath).doc(issueId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) {
        throw StateError('Issue $issueId no longer exists.');
      }

      return IssueSummary.fromMap(id: snapshot.id, data: data);
    });
  }

  Future<Query<Map<String, dynamic>>?> _issueQueryForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final issuesQuery = _firestore.collection(collectionPath);
    final role = await _readUserRole(user.uid);

    // admins need the operational overview
    // normal users only see reports they created
    if (role == 'admin') return issuesQuery;

    return issuesQuery.where('reporterID', isEqualTo: user.uid);
  }

  Future<String> _readUserRole(String userId) async {
    // missing role defaults to user
    // cannot fallback to admin to get full access
    final doc = await _firestore.collection('users').doc(userId).get();
    return (doc.data()?['role'] ?? 'user').toString().trim().toLowerCase();
  }
}
