import 'package:flutter/foundation.dart';

import '../models/community_comment.dart';
import '../models/community_user_profile.dart';
import '../services/community_repository.dart';

enum CommentSort { newest, mostSupported }

extension CommentSortLabel on CommentSort {
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

  // simple in-memory cache for user lookups (avatars/area/usernames)
  final Map<String, Future<CommunityUserProfile?>> _profileFutures = {};

  CommentSort get commentSort => _commentSort;

  void updateCommentSort(String label) {
    final next = CommentSortLabel.fromLabel(label);
    if (_commentSort == next) return;
    _commentSort = next;
    notifyListeners();
  }

  Future<CommunityUserProfile?> profileFor(String uid) {
    final key = uid.trim();
    if (key.isEmpty) return Future.value(null);
    return _profileFutures.putIfAbsent(
      key,
      () => _repository.fetchUserProfile(key),
    );
  }

  List<CommunityComment> sortComments(List<CommunityComment> comments) {
    // Always pin admin comments at top (based on stored comment.userRole).
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
    required CommunityComment comment,
  }) async {
    try {
      await _repository.toggleCommentLike(issueId: issueId, comment: comment);
      return null;
    } catch (e) {
      return e;
    }
  }
}
