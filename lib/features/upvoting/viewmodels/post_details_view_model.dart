import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/community_comment.dart';
import '../services/community_repository.dart';

enum CommentSort { newest, mostSupported }

extension CommentSortLabel on CommentSort {
  String get label => switch (this) {
    CommentSort.newest => 'Newest',
    CommentSort.mostSupported => 'Most Supported',
  };

  static CommentSort fromLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'most supported' || normalized == 'most_supported') {
      return CommentSort.mostSupported;
    }
    return CommentSort.newest;
  }
}

class PostDetailsViewModel extends ChangeNotifier {
  PostDetailsViewModel({required CommunityRepository repository})
    : _repository = repository;

  final CommunityRepository _repository;

  CommentSort _commentSort = CommentSort.newest;

  CommentSort get commentSort => _commentSort;

  void updateCommentSort(String label) {
    final next = CommentSortLabel.fromLabel(label);
    if (_commentSort == next) return;
    _commentSort = next;
    notifyListeners();
  }

  List<CommunityComment> sortComments(List<CommunityComment> comments) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Always pin admin comments at top.
    final admin = comments.where((c) => c.isAdmin).toList(growable: true);
    final others = comments.where((c) => !c.isAdmin).toList(growable: true);

    int newest(CommunityComment a, CommunityComment b) {
      final ad = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    }

    int supported(CommunityComment a, CommunityComment b) {
      final cmp = b.likesCount.compareTo(a.likesCount);
      if (cmp != 0) return cmp;
      return newest(a, b);
    }

    switch (_commentSort) {
      case CommentSort.newest:
        admin.sort(newest);
        others.sort(newest);
        break;
      case CommentSort.mostSupported:
        admin.sort(supported);
        others.sort(supported);
        break;
    }

    // (Optional) Keep the current user’s own comment slightly earlier within “others”
    // if tie. Not required, but harmless.
    // ignore: unused_local_variable
    final _ = uid;

    return [...admin, ...others];
  }

  Future<Object?> toggleIssueLike(String issueId) async {
    try {
      await _repository.toggleIssueLike(issueId);
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<Object?> sendComment(String issueId, String text) async {
    try {
      await _repository.addComment(issueId, text);
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<Object?> toggleCommentLike({
    required String issueId,
    required String commentId,
  }) async {
    try {
      await _repository.toggleCommentLike(
        issueId: issueId,
        commentId: commentId,
      );
      return null;
    } catch (e) {
      return e;
    }
  }
}
