import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/community_issue.dart';
import '../models/community_user_profile.dart';
import '../services/community_repository.dart';

enum CommunitySort { all, newest, mostSupported, complete }

extension CommunitySortLabel on CommunitySort {
  String get label => switch (this) {
    CommunitySort.all => 'All',
    CommunitySort.newest => 'Newest',
    CommunitySort.mostSupported => 'Most Supported',
    CommunitySort.complete => 'Complete',
  };

  static CommunitySort fromLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'newest') return CommunitySort.newest;
    if (normalized == 'most supported' || normalized == 'most_supported') {
      return CommunitySort.mostSupported;
    }
    if (normalized == 'complete') return CommunitySort.complete;
    return CommunitySort.all;
  }
}

class CommunityViewModel extends ChangeNotifier {
  CommunityViewModel({required CommunityRepository repository})
    : _repository = repository;

  final CommunityRepository _repository;

  StreamSubscription<List<CommunityIssue>>? _issuesSub;
  StreamSubscription<bool>? _roleSub;

  List<CommunityIssue> _issues = const [];
  bool _isAdmin = false;
  bool _isLoading = true;
  Object? _error;

  String _searchQuery = '';
  CommunitySort _sort = CommunitySort.all;

  // Cache user profile fetches (for summary cards).
  final Map<String, Future<CommunityUserProfile?>> _profileFutures = {};

  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get hasError => _error != null;

  void start() {
    _issuesSub?.cancel();
    _roleSub?.cancel();

    _isLoading = true;
    _error = null;
    notifyListeners();

    _issuesSub = _repository.watchIssues().listen(
      (issues) {
        _issues = issues;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _error = e;
        notifyListeners();
      },
    );

    _roleSub = _repository.watchCurrentUserIsAdmin().listen((isAdmin) {
      if (_isAdmin == isAdmin) return;
      _isAdmin = isAdmin;
      notifyListeners();
    });
  }

  void updateSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void updateSortLabel(String label) {
    final next = CommunitySortLabel.fromLabel(label);
    if (_sort == next) return;
    _sort = next;
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

  List<CommunityIssue> get _activeIssues =>
      _issues.where((i) => !i.isDeleted).toList(growable: false);

  /// Global Top 3 by total likes — unresolved issues only.
  List<CommunityIssue> get top3Issues {
    final list = _activeIssues.where((i) => i.isUnresolved).toList(growable: true)
      ..sort((a, b) {
        final cmp = b.likesCount.compareTo(a.likesCount);
        if (cmp != 0) return cmp;
        final ad = a.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return list.take(3).toList(growable: false);
  }

  int? topRankForIssue(String issueId) {
    final top = top3Issues;
    for (var i = 0; i < top.length; i++) {
      if (top[i].id == issueId) return i + 1;
    }
    return null;
  }

  List<CommunityIssue> get visibleIssues {
    final query = _searchQuery.trim().toLowerCase();

    // 'Complete' filter only shows resolved; all other filters only show unresolved
    final pool = _sort == CommunitySort.complete
        ? _activeIssues.where((i) => !i.isUnresolved)
        : _activeIssues.where((i) => i.isUnresolved);

    final filtered = pool
        .where((issue) {
          if (query.isEmpty) return true;
          return issue.searchableText.contains(query);
        })
        .toList(growable: true);

    int sortByNewest(CommunityIssue a, CommunityIssue b) {
      final ad = a.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    }

    int sortByCompletionDate(CommunityIssue a, CommunityIssue b) {
      // Sort by completion date (most recently completed first)
      final ad = a.completionProof?.completedAt ?? 
                 a.lastUpdatedAt ?? 
                 a.createdAt ?? 
                 DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.completionProof?.completedAt ?? 
                 b.lastUpdatedAt ?? 
                 b.createdAt ?? 
                 DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    }

    int sortByMostSupported(CommunityIssue a, CommunityIssue b) {
      final cmp = b.likesCount.compareTo(a.likesCount);
      if (cmp != 0) return cmp;
      return sortByNewest(a, b);
    }

    switch (_sort) {
      case CommunitySort.newest:
        filtered.sort(sortByNewest);
        return filtered;

      case CommunitySort.mostSupported:
        filtered.sort(sortByMostSupported);
        return filtered;

      case CommunitySort.complete:
        // Completed issues sorted by completion date (most recent first)
        filtered.sort(sortByCompletionDate);
        return filtered;

      case CommunitySort.all:
        final topIds = top3Issues.map((e) => e.id).toSet();
        final top =
            filtered.where((i) => topIds.contains(i.id)).toList(growable: true)
              ..sort(sortByMostSupported);
        final rest =
            filtered.where((i) => !topIds.contains(i.id)).toList(growable: true)
              ..sort(sortByNewest);
        return [...top, ...rest];
    }
  }

  Future<Object?> toggleLike(String issueId) async {
    try {
      await _repository.toggleIssueLike(issueId);
      return null;
    } catch (e) {
      return e;
    }
  }

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _issuesSub?.cancel();
    _roleSub?.cancel();
    super.dispose();
  }
}
