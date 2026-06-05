import 'dart:math';

import 'package:intl/intl.dart';

import '../../summary/models/issue_status.dart';
import '../../summary/models/issue_summary.dart';
import '../models/issue_detail_models.dart';

// for the report status detail page.
// adapts from IssueSummary into display
class IssueDetailsViewModel {
  IssueDetailsViewModel({
    required this.issue,
    this.systemIssues = const <IssueSummary>[],
    this.canEditStatus = false,
  });

  final IssueSummary issue;
  final List<IssueSummary> systemIssues;
  final bool canEditStatus;

  DateTime? get submittedAt => issue.submittedAt;

  DateTime? get inProgressAt => issue.inProgressAt;

  DateTime? get completedAt => issue.completedAt;

  // report images
  List<String> get reportImageUrls => _cleanImageUrls(issue.reportImages);

  // report image thumbnail (default first image)
  String? get reportImageUrl =>
      reportImageUrls.isEmpty ? null : reportImageUrls.first;

  // proof images
  List<String> get completionImageUrls =>
      _cleanImageUrls(issue.completionProof.proofImages);

  // proof image thumbnail (default first image)
  String? get completionImageUrl =>
      completionImageUrls.isEmpty ? null : completionImageUrls.first;

  List<String> get statusImageUrls {
    // only show completion images if the issue is completed
    if (issue.status != IssueStatus.completed) return const [];
    return completionImageUrls.isNotEmpty
        ? completionImageUrls
        : reportImageUrls;
  }

  // completion image thumbnail
  String? get statusImageUrl => issue.status == IssueStatus.completed
      ? completionImageUrl ?? reportImageUrl
      : null;

  String get lastUpdatedText => _formatDateTime(issue.latestStatusChangedAt);

  String get estimatedResolutionText =>
      _formatDate(issue.estimatedResolutionAt);

  String get averageResolutionText {
    final durations = _completedDurationsForCategory();
    if (durations.isEmpty) return 'N/A';
    return _formatDays(_average(durations));
  }

  int get similarReportCount => issue.engagement.likesCount;

  bool get isResolved => issue.status == IssueStatus.completed;

  List<IssueDetailProgressStep> get progressSteps {
    // progression derived from issue status and timeline
    final reachedIndex = _statusIndex(issue.status);
    return [
      IssueDetailProgressStep(
        status: IssueStatus.submitted,
        label: IssueStatus.submitted.label,
        isReached: reachedIndex >= 0,
        date: submittedAt,
      ),
      IssueDetailProgressStep(
        status: IssueStatus.inProgress,
        label: IssueStatus.inProgress.label,
        isReached: reachedIndex >= 1,
        date: reachedIndex >= 1 ? inProgressAt : null,
      ),
      IssueDetailProgressStep(
        status: IssueStatus.completed,
        label: IssueStatus.completed.label,
        isReached: reachedIndex >= 2,
        date: reachedIndex >= 2 ? completedAt : null,
      ),
    ];
  }

  List<IssueDetailUpdate> get updates {
    final entries = <IssueDetailUpdate>[
      IssueDetailUpdate(
        title: 'Report Submitted',
        description: 'Your issue report was submitted successfully.',
        timestamp: submittedAt,
      ),
    ];

    if (_statusIndex(issue.status) >= 1) {
      entries.add(
        IssueDetailUpdate(
          title: 'In Progress',
          description:
              'The responsible department has started to work on this issue.',
          timestamp: inProgressAt,
        ),
      );
    }

    if (_statusIndex(issue.status) >= 2) {
      entries.add(
        IssueDetailUpdate(
          title: 'Completed',
          description: issue.completionProof.description.isEmpty
              ? 'This issue has been marked as completed.'
              : issue.completionProof.description,
          timestamp: completedAt,
        ),
      );
    }

    return entries;
  }

  String formatShortDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d').format(date);
  }

  String formatFullDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String formatUpdateTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  int _statusIndex(IssueStatus status) {
    // index order
    // 0 submitted, 1 in progress, 2 completed.
    return switch (status) {
      IssueStatus.completed => 2,
      IssueStatus.inProgress => 1,
      IssueStatus.submitted || IssueStatus.all || IssueStatus.unknown => 0,
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  List<double> _completedDurationsForCategory() {
    final targetCategory = _normalizeCategory(issue.category);
    if (targetCategory.isEmpty) return const [];

    return systemIssues
        .where((systemIssue) => !systemIssue.isDeleted)
        .where(
          (systemIssue) =>
              _normalizeCategory(systemIssue.category) == targetCategory,
        )
        .map(_completionDurationDays)
        .whereType<double>()
        .toList(growable: false);
  }

  double? _completionDurationDays(IssueSummary issue) {
    final submittedAt = issue.submittedAt;
    final completedAt = issue.completedAt;
    if (submittedAt == null || completedAt == null) return null;
    if (completedAt.isBefore(submittedAt)) return null;
    final hours = max(1, completedAt.difference(submittedAt).inHours);
    return hours / 24;
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  String _formatDays(double days) {
    if (days <= 0) return 'N/A';
    if (days < 1) return '${(days * 24).round()}H';
    return '${days.toStringAsFixed(1)}D';
  }

  String _normalizeCategory(String category) {
    return category.trim().toLowerCase();
  }

  List<String> _cleanImageUrls(List<String> urls) {
    return urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }
}
