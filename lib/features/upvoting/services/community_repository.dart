import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_issue.dart';

class CommunityRepository {
  CommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.collectionPath = 'issue',
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String collectionPath;

  Stream<List<CommunityIssue>> watchIssues() {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs.map(CommunityIssue.fromDoc).toList(growable: false);
    });
  }

  Stream<CommunityIssue> watchIssue(String issueId) {
    return _firestore.collection(collectionPath).doc(issueId).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) {
        throw StateError('Issue $issueId no longer exists.');
      }
      return CommunityIssue.fromDoc(doc);
    });
  }

  Stream<bool> watchCurrentUserIsAdmin() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(false);
      return _firestore.collection('users').doc(user.uid).snapshots().map((
        doc,
      ) {
        final role = (doc.data()?['role'] ?? 'user')
            .toString()
            .trim()
            .toLowerCase();
        return role == 'admin';
      });
    });
  }

  Future<void> toggleIssueLike(String issueId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in to like posts.');

    final issueRef = _firestore.collection(collectionPath).doc(issueId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(issueRef);
      final data = snap.data() ?? <String, dynamic>{};

      final community = (data['community'] is Map)
          ? Map<String, dynamic>.from(data['community'] as Map)
          : <String, dynamic>{};

      final likes = _readListOfMaps(community['likes']);
      final existingIndex = likes.indexWhere(
        (m) => (m['likedBy'] ?? '').toString() == user.uid,
      );

      if (existingIndex >= 0) {
        likes.removeAt(existingIndex);
      } else {
        likes.add({'likedBy': user.uid, 'timestamp': Timestamp.now()});
      }

      community['likes'] = likes;

      txn.set(issueRef, {
        'community': community,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> addComment(String issueId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in to comment.');

    final trimmed = text.trim();
    if (trimmed.isEmpty) throw StateError('Comment cannot be empty.');

    final issueRef = _firestore.collection(collectionPath).doc(issueId);
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((txn) async {
      final issueSnap = await txn.get(issueRef);
      final issueData = issueSnap.data() ?? <String, dynamic>{};

      final userSnap = await txn.get(userRef);
      final userData = userSnap.data() ?? <String, dynamic>{};

      final role = (userData['role'] ?? 'user').toString().trim().toLowerCase();
      final username =
          (userData['username'] ?? user.displayName ?? user.email ?? 'User')
              .toString()
              .trim();
      final homeAddress = (userData['homeAddress'] ?? '').toString().trim();
      final area = (userData['area'] ?? '').toString().trim();
      final state = (userData['state'] ?? '').toString().trim();

      final userLocation = _shortLocation(
        homeAddress,
        area: area,
        state: state,
      );

      final community = (issueData['community'] is Map)
          ? Map<String, dynamic>.from(issueData['community'] as Map)
          : <String, dynamic>{};

      final comments = _readListOfMaps(community['comments']);

      final commentId = '${user.uid}_${DateTime.now().microsecondsSinceEpoch}';

      comments.add({
        'commentId': commentId,
        'comment': trimmed,
        'timestamp': Timestamp.now(),
        'userId': user.uid,
        'userName': username.isEmpty ? 'User' : username,
        'userRole': role,
        'userLocation': userLocation,
        'likes': <Map<String, dynamic>>[],
      });

      community['comments'] = comments;

      txn.set(issueRef, {
        'community': community,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> toggleCommentLike({
    required String issueId,
    required String commentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in to like comments.');

    final issueRef = _firestore.collection(collectionPath).doc(issueId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(issueRef);
      final data = snap.data() ?? <String, dynamic>{};

      final community = (data['community'] is Map)
          ? Map<String, dynamic>.from(data['community'] as Map)
          : <String, dynamic>{};

      final comments = _readListOfMaps(community['comments']);

      final idx = comments.indexWhere(
        (m) => (m['commentId'] ?? '').toString() == commentId,
      );
      if (idx < 0) {
        throw StateError('Comment not found.');
      }

      final comment = Map<String, dynamic>.from(comments[idx]);
      final likes = _readListOfMaps(comment['likes']);

      final existingIndex = likes.indexWhere(
        (m) => (m['likedBy'] ?? '').toString() == user.uid,
      );

      if (existingIndex >= 0) {
        likes.removeAt(existingIndex);
      } else {
        likes.add({'likedBy': user.uid, 'timestamp': Timestamp.now()});
      }

      comment['likes'] = likes;
      comments[idx] = comment;

      community['comments'] = comments;

      txn.set(issueRef, {
        'community': community,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  List<Map<String, dynamic>> _readListOfMaps(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  String _shortLocation(
    String homeAddress, {
    required String area,
    required String state,
  }) {
    if (area.isNotEmpty && state.isNotEmpty) return '$area, $state';
    if (homeAddress.isEmpty) return '';
    final parts = homeAddress
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) return parts.sublist(parts.length - 2).join(', ');
    return parts.isNotEmpty ? parts.last : homeAddress;
  }
}
