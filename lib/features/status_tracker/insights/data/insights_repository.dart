import 'package:cloud_firestore/cloud_firestore.dart';

import '../../summary/models/issue_summary.dart';

class InsightsRepository {
  InsightsRepository({
    FirebaseFirestore? firestore,
    this.collectionPath = 'issue',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String collectionPath;

  // Streams raw issue documents for system-wide insights; filtering and derived
  // analytics are handled in the ViewModel.
  Stream<List<IssueSummary>> watchSystemIssues() {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => IssueSummary.fromMap(id: doc.id, data: doc.data()))
          .toList(growable: false);
    });
  }
}
