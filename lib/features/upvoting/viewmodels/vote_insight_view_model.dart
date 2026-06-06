import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/community_issue.dart';
import '../services/community_repository.dart';

class VoteInsightItem {
  final CommunityIssue issue;
  final int likesLastHour;

  const VoteInsightItem({required this.issue, required this.likesLastHour});
}

class VoteInsightViewModel extends ChangeNotifier {
  VoteInsightViewModel({required CommunityRepository repository})
    : _repository = repository;

  final CommunityRepository _repository;

  StreamSubscription<List<CommunityIssue>>? _sub;
  bool _isLoading = true;
  Object? _error;
  List<CommunityIssue> _issues = const [];

  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get hasError => _error != null;

  void start() {
    _sub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _sub = _repository.watchIssues().listen(
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
  }

  List<VoteInsightItem> get top3Unresolved {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    final unresolved =
        _issues
            .where((i) => !i.isDeleted && i.isUnresolved)
            .toList(growable: true)
          ..sort((a, b) {
            final cmp = b.likesCount.compareTo(a.likesCount);
            if (cmp != 0) return cmp;
            final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });

    final top = unresolved.take(3).toList(growable: false);

    return top
        .map((issue) {
          final likesLastHour = issue.community.likes.where((like) {
            final ts = like.timestamp;
            return ts != null && !ts.isBefore(oneHourAgo);
          }).length;

          return VoteInsightItem(issue: issue, likesLastHour: likesLastHour);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
