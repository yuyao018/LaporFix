import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_comment.dart';
import '../models/community_issue.dart';
import '../models/community_user_profile.dart';

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
      if (data == null) throw StateError('Issue $issueId no longer exists.');
      return CommunityIssue.fromDoc(doc);
    });
  }

  Stream<bool> watchCurrentUserIsAdmin() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(false);

      final docRef = _firestore.collection('users').doc(user.uid);

      // Decide the best stream once:
      return docRef.get().asStream().asyncExpand((doc) {
        if (doc.exists) {
          return docRef.snapshots().map((snap) {
            final role = (snap.data()?['role'] ?? 'user')
                .toString()
                .trim()
                .toLowerCase();
            return role == 'admin';
          });
        }

        // Fallback: users collection where uid field matches
        return _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .snapshots()
            .map((snap) {
              if (snap.docs.isEmpty) return false;
              final role = (snap.docs.first.data()['role'] ?? 'user')
                  .toString()
                  .trim()
                  .toLowerCase();
              return role == 'admin';
            });
      });
    });
  }

  /// Robust user lookup:
  /// 1) try doc(uid)
  /// 2) fallback query where('uid' == uid)
  Future<CommunityUserProfile?> fetchUserProfile(String uid) async {
    if (uid.trim().isEmpty) return null;

    final docTry = await _firestore.collection('users').doc(uid).get();
    if (docTry.exists) {
      return CommunityUserProfile.fromDoc(docTry);
    }

    final query = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return CommunityUserProfile.fromDoc(query.docs.first);
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
      final i = likes.indexWhere(
        (m) => (m['likedBy'] ?? '').toString() == user.uid,
      );

      if (i >= 0) {
        likes.removeAt(i);
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

    // Fetch profile OUTSIDE transaction (works even if users doc id != uid).
    final profile = await fetchUserProfile(user.uid);
    final username =
        profile?.displayName ?? (user.displayName ?? user.email ?? 'User');
    final role = profile?.role.trim().toLowerCase() ?? 'user';
    final area = profile?.area ?? '';

    final issueRef = _firestore.collection(collectionPath).doc(issueId);

    await _firestore.runTransaction((txn) async {
      final issueSnap = await txn.get(issueRef);
      final issueData = issueSnap.data() ?? <String, dynamic>{};

      final community = (issueData['community'] is Map)
          ? Map<String, dynamic>.from(issueData['community'] as Map)
          : <String, dynamic>{};

      final comments = _readListOfMaps(community['comments']);

      comments.add({
        'comment': trimmed,
        'timestamp': Timestamp.now(),
        'userId': user.uid,
        'userName': username.toString().trim().isEmpty
            ? 'User'
            : username.toString().trim(),
        'userRole': role,
        'userLocation': area, // requirement: use users.area
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
    required CommunityComment comment,
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
      final idx = _findCommentIndex(comments, comment);
      if (idx < 0) throw StateError('Comment not found.');

      final commentMap = Map<String, dynamic>.from(comments[idx]);
      final likes = _readListOfMaps(commentMap['likes']);

      final likeIdx = likes.indexWhere(
        (m) => (m['likedBy'] ?? '').toString() == user.uid,
      );
      if (likeIdx >= 0) {
        likes.removeAt(likeIdx);
      } else {
        likes.add({'likedBy': user.uid, 'timestamp': Timestamp.now()});
      }

      commentMap['likes'] = likes;
      comments[idx] = commentMap;
      community['comments'] = comments;

      txn.set(issueRef, {
        'community': community,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  int _findCommentIndex(
    List<Map<String, dynamic>> comments,
    CommunityComment target,
  ) {
    for (var i = 0; i < comments.length; i++) {
      final m = comments[i];
      final ts = m['timestamp'];
      final dt = ts is Timestamp ? ts.toDate() : null;
      final millis = dt?.millisecondsSinceEpoch;
      final userId = (m['userId'] ?? m['commentedBy'] ?? '').toString();
      final text = (m['comment'] ?? '').toString();

      final key = '${userId.trim()}|${millis?.toString() ?? ''}|${text.trim()}';
      if (key == target.matchKey) return i;
    }

    for (var i = 0; i < comments.length; i++) {
      final m = comments[i];
      final userId = (m['userId'] ?? m['commentedBy'] ?? '').toString().trim();
      final text = (m['comment'] ?? '').toString().trim();
      if (userId == target.userId.trim() && text == target.comment.trim()) {
        return i;
      }
    }

    return -1;
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
}
