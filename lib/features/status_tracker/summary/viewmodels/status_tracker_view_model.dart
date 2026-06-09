import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/status_tracker_repository.dart';
import '../models/issue_status.dart';
import '../models/issue_summary.dart';

/// ViewModel in the MVVM structure.
///
/// It owns feature state, receives typed data from the repository, and exposes
/// ready-to-render values to the view. The widgets do not need to know how
/// Firebase fields are filtered, sorted, or searched.
class StatusTrackerViewModel extends ChangeNotifier {
  StatusTrackerViewModel({required StatusTrackerRepository repository})
    : _repository = repository;

  final StatusTrackerRepository _repository;

  // Private mutable state stays in the ViewModel. Views read public getters and
  // trigger methods, which keeps widget rebuilds predictable.
  StreamSubscription<List<IssueSummary>>? _subscription;
  List<IssueSummary> _issues = const [];
  String _searchQuery = '';
  IssueStatus _selectedStatus = IssueStatus.all;
  Object? _error;
  bool _isLoading = true;

  List<IssueSummary> get issues => _issues;
  String get searchQuery => _searchQuery;
  IssueStatus get selectedStatus => _selectedStatus;
  Object? get error => _error;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;

  List<String> get filterLabels {
    // to be used in filterLists
    return IssueStatus.filters.map((status) => status.label).toList();
  }

  // final list used by the UI
  List<IssueSummary> get visibleIssues {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _issues.where((issue) {
      if (issue.isDeleted) return false;
      if (_selectedStatus != IssueStatus.all &&
          issue.status != _selectedStatus) {
        return false;
      }
      if (query.isEmpty) return true;
      return issue.searchableText.contains(query);
    }).toList();

    filtered.sort(_sortLatestFirst);
    return filtered;
  }

  void start() {
    // restarting cancels previous listener first
    // keeps pull-to-refresh from stacking multiple Firestore subscriptions
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _repository.watchIssues().listen(
      (issues) {
        _issues = issues;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _error = error;
        notifyListeners();
      },
    );
  }

  void updateSearchQuery(String value) {
    // avoid unnecessary notifyListeners calls
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void updateStatusFilter(String label) {
    // filter labels come from the shared app bar as strings
    // convert back into enum before apply the filter
    final status = IssueStatus.fromText(label);
    final nextStatus = status.isFilter ? status : IssueStatus.all;

    if (_selectedStatus == nextStatus) return;
    _selectedStatus = nextStatus;
    notifyListeners();
  }

  Future<void> deleteIssue(String issueId) async {
    await _repository.softDeleteIssue(issueId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  int _sortLatestFirst(IssueSummary left, IssueSummary right) {
    final leftDate = left.latestStatusChangedAt;
    final rightDate = right.latestStatusChangedAt;

    // issues without dates have low prior, newest first
    if (leftDate == null && rightDate == null) {
      return left.title.compareTo(right.title);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return rightDate.compareTo(leftDate);
  }
}
