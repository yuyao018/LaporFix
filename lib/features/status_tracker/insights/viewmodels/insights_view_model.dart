import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../summary/models/issue_status.dart';
import '../../summary/models/issue_summary.dart';
import '../data/insights_repository.dart';
import '../models/insights_models.dart';

// all insights state and calculations
// widgets only ask this ViewModel for prepared chart/card data
// included date filtering, status counting, trend comparison and grouping
class InsightsViewModel extends ChangeNotifier {
  InsightsViewModel({required InsightsRepository repository})
    : _repository = repository;

  final InsightsRepository _repository;

  // firestore subscription for live insight refresh
  StreamSubscription<List<IssueSummary>>? _subscription;

  // raw issue cache list
  List<IssueSummary> _issues = const [];

  // default period selection
  InsightsPeriod _selectedPeriod = InsightsPeriod.days30;
  String? _selectedCategory;
  Object? _error;
  bool _isLoading = true;

  // default area limit selection
  int _areaLimit = 10;

  // default engagement ranking limit selection
  int _engagementLimit = 5;

  InsightsPeriod get selectedPeriod => _selectedPeriod;
  String? get selectedCategory => _selectedCategory;
  String get selectedFilterLabel => _selectedCategory ?? 'Overview';
  Object? get error => _error;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  bool get isOverview => _selectedCategory == null;
  int get areaLimit => _areaLimit;
  List<int> get areaLimitOptions => const [5, 10, 20];
  int get engagementLimit => _engagementLimit;
  List<int> get engagementLimitOptions => const [3, 5, 10, 20];

  List<String> get filterLabels => ['Overview', ..._categoryLabels];

  // get the latest Firestore dataset
  InsightsDataset get dataset {
    final now = DateTime.now();
    final currentRange = _periodRange(now, _selectedPeriod);
    final previousRange = _previousPeriodRange(currentRange);
    final periodIssues = _issuesBetween(
      _activeIssues,
      currentRange.start,
      currentRange.end,
    );
    final previousIssues = _issuesBetween(
      _activeIssues,
      previousRange.start,
      previousRange.end,
    );
    final overview = _buildOverview(periodIssues, now);
    final category = _selectedCategory;

    return InsightsDataset(
      categories: _categoryLabels,
      period: _selectedPeriod,
      selectedCategory: category,
      overview: overview,
      categoryDetail: category == null
          ? null
          : _buildCategory(category, periodIssues, previousIssues, now),
    );
  }

  // list of complaints by area
  List<InsightsAreaItem> get visibleAreaBreakdown {
    final detail = dataset.categoryDetail;
    if (detail == null) return const [];
    return detail.areaBreakdown.take(_areaLimit).toList(growable: false);
  }

  // starts/restarts live Firestore stream
  // update immediately after an issue changes status
  void start() {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _repository.watchSystemIssues().listen(
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

  // changes period selection
  void updatePeriod(InsightsPeriod period) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    notifyListeners();
  }

  // when selects a category
  // Overview is null category
  void updateFilter(String label) {
    final nextCategory = label == 'Overview' ? null : label;
    if (_selectedCategory == nextCategory) return;
    _selectedCategory = nextCategory;
    notifyListeners();
  }

  // when user selects a different limit (5/10/20)
  void updateAreaLimit(int limit) {
    if (_areaLimit == limit) return;
    _areaLimit = limit;
    notifyListeners();
  }

  // when user selects a different Top N limit for engagement rows
  void updateEngagementLimit(int limit) {
    if (_engagementLimit == limit) return;
    _engagementLimit = limit;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // exclude deleted issues (garbage data)
  List<IssueSummary> get _activeIssues {
    return _issues.where((issue) => !issue.isDeleted).toList(growable: false);
  }

  // dropdown category labels
  List<String> get _categoryLabels {
    final categories =
        _activeIssues
            .map((issue) => issue.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return categories;
  }

  // filters by submitted time -> period
  List<IssueSummary> _issuesBetween(
    List<IssueSummary> issues,
    DateTime start,
    DateTime end,
  ) {
    return issues
        .where((issue) {
          final submittedAt = issue.submittedAt;
          if (submittedAt == null) return false;
          return !submittedAt.isBefore(start) && submittedAt.isBefore(end);
        })
        .toList(growable: false);
  }

  // for build overview cards and charts
  OverviewInsights _buildOverview(List<IssueSummary> issues, DateTime now) {
    final categoryBreakdown = _categoryBreakdown(issues);
    final topCategory = categoryBreakdown.isEmpty
        ? null
        : categoryBreakdown.first;
    final unresolvedCount = _unresolvedCount(issues);
    final solvedCount = _statusCount(issues, IssueStatus.completed);
    final inProgressCount = _statusCount(issues, IssueStatus.inProgress);

    return OverviewInsights(
      metrics: [
        // unresolved (including in progress + submitted, means not yet done)
        InsightsMetric(
          label: 'Unresolved',
          value: unresolvedCount.toString(),
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFF3B30),
        ),
        // solved
        InsightsMetric(
          label: 'Solved',
          value: solvedCount.toString(),
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF18B86B),
        ),
        // in progress
        InsightsMetric(
          label: 'In Progress',
          value: inProgressCount.toString(),
          icon: Icons.double_arrow_rounded,
          color: const Color(0xFF0084FF),
        ),
      ],
      categoryBreakdown: categoryBreakdown,
      complaintsOverTime: _timeBuckets(issues, now, _selectedPeriod),
      averageResolutionByCategory: _averageResolutionByCategory(issues),
      keyFinding: _keyFinding(topCategory, issues.length),
      mostActiveArea: _mostActiveArea(issues),
      topEngagements: _topEngagements(issues),
    );
  }

  // for build category-only cards and charts
  CategoryInsights _buildCategory(
    String category,
    List<IssueSummary> periodIssues,
    List<IssueSummary> previousPeriodIssues,
    DateTime now,
  ) {
    final issues = periodIssues
        .where((issue) => issue.category == category)
        .toList(growable: false);
    final previousIssues = previousPeriodIssues
        .where((issue) => issue.category == category)
        .toList(growable: false);
    final durations = _completedDurations(issues);
    final previousDurations = _completedDurations(previousIssues);
    final stats = _durationStats(durations);
    final previousStats = _durationStats(previousDurations);
    final unresolvedCount = _unresolvedCount(issues);
    final solvedCount = _statusCount(issues, IssueStatus.completed);
    final inProgressCount = _statusCount(issues, IssueStatus.inProgress);

    return CategoryInsights(
      category: category,
      metrics: [
        // unresolved (including in progress + submitted, means not yet done)
        InsightsMetric(
          label: 'Unresolved',
          value: unresolvedCount.toString(),
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFF3B30),
        ),
        // solved
        InsightsMetric(
          label: 'Solved',
          value: solvedCount.toString(),
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF18B86B),
        ),
        // in progress
        InsightsMetric(
          label: 'In Progress',
          value: inProgressCount.toString(),
          icon: Icons.double_arrow_rounded,
          color: const Color(0xFF0084FF),
        ),
        // longest waiting time
        InsightsMetric(
          label: 'Longest Wait',
          value: _formatDays(stats.longestDays),
          icon: Icons.keyboard_double_arrow_down_rounded,
          color: const Color(0xFFD97800),
          trendPercent: _trendPercentDouble(
            stats.longestDays,
            previousStats.longestDays,
          ),
          trendPeriodLabel: _selectedPeriod.label,
        ),
        // shortest waiting time
        InsightsMetric(
          label: 'Shortest Wait',
          value: _formatDays(stats.shortestDays),
          icon: Icons.keyboard_double_arrow_up_rounded,
          color: const Color(0xFF00AFC7),
          trendPercent: _trendPercentDouble(
            stats.shortestDays,
            previousStats.shortestDays,
          ),
          trendPeriodLabel: _selectedPeriod.label,
        ),
        // average waiting time
        InsightsMetric(
          label: 'Average Wait',
          value: _formatDays(stats.averageDays),
          icon: Icons.sentiment_satisfied_alt_rounded,
          color: const Color(0xFFD95CFF),
          trendPercent: _trendPercentDouble(
            stats.averageDays,
            previousStats.averageDays,
          ),
          trendPeriodLabel: _selectedPeriod.label,
        ),
      ],
      areaBreakdown: _areaBreakdown(issues),
      complaintsOverTime: _timeBuckets(issues, now, _selectedPeriod),
      mostActiveArea: _mostActiveArea(issues),
      topEngagements: _topEngagements(issues),
    );
  }

  // count all issue still needs action (submitted + in progress)
  int _unresolvedCount(List<IssueSummary> issues) {
    return issues
        .where(
          (issue) =>
              issue.status == IssueStatus.submitted ||
              issue.status == IssueStatus.inProgress,
        )
        .length;
  }

  int _statusCount(List<IssueSummary> issues, IssueStatus status) {
    return issues.where((issue) => issue.status == status).length;
  }

  // count complaints per category then sort result from highest to lowest
  List<InsightsBreakdownItem> _categoryBreakdown(List<IssueSummary> issues) {
    final counts = <String, int>{};
    for (final issue in issues) {
      counts.update(issue.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final entries = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return [
      for (var index = 0; index < entries.length; index++)
        InsightsBreakdownItem(
          label: entries[index].key,
          value: entries[index].value,
          color: _chartColor(index),
        ),
    ];
  }

  // count complaints per area for the selected period/category
  List<InsightsAreaItem> _areaBreakdown(List<IssueSummary> issues) {
    final counts = <String, int>{};
    for (final issue in issues) {
      final area = issue.location.displayName;
      counts.update(area, (value) => value + 1, ifAbsent: () => 1);
    }

    final entries = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    return [
      for (var index = 0; index < entries.length; index++)
        InsightsAreaItem(
          area: entries[index].key,
          count: entries[index].value,
          color: _chartColor(index),
        ),
    ];
  }

  // ranks issue rows by engagement for the selected period.
  // status is intentionally not filtered here, only deleted issues are excluded
  // before this method is called.
  List<InsightsEngagementItem> _topEngagements(List<IssueSummary> issues) {
    final entries = issues.toList(growable: false)
      ..sort((left, right) {
        final leftTotal =
            left.engagement.likesCount + left.engagement.commentCount;
        final rightTotal =
            right.engagement.likesCount + right.engagement.commentCount;
        final totalCompare = rightTotal.compareTo(leftTotal);
        if (totalCompare != 0) return totalCompare;

        final commentsCompare = right.engagement.commentCount.compareTo(
          left.engagement.commentCount,
        );
        if (commentsCompare != 0) return commentsCompare;

        final likesCompare = right.engagement.likesCount.compareTo(
          left.engagement.likesCount,
        );
        if (likesCompare != 0) return likesCompare;

        final rightDate = right.latestStatusChangedAt;
        final leftDate = left.latestStatusChangedAt;
        if (rightDate != null && leftDate != null) {
          return rightDate.compareTo(leftDate);
        }
        if (rightDate != null) return 1;
        if (leftDate != null) return -1;

        return right.id.compareTo(left.id);
      });

    return [
      for (final issue in entries)
        InsightsEngagementItem(
          issueId: issue.id,
          category: issue.category,
          location: issue.location.displayName,
          likesCount: issue.engagement.likesCount,
          commentsCount: issue.engagement.commentCount,
        ),
    ];
  }

  // splits selected period into fixed buckets for line chart
  List<InsightsTimeBucket> _timeBuckets(
    List<IssueSummary> issues,
    DateTime now,
    InsightsPeriod period,
  ) {
    final start = _periodStart(now, period);
    final end = _periodEnd(now, period);
    final bucketDuration = Duration(
      milliseconds: end.difference(start).inMilliseconds ~/ period.bucketCount,
    );
    final counts = List<int>.filled(period.bucketCount, 0);

    for (final issue in issues) {
      final submittedAt = issue.submittedAt;
      if (submittedAt == null ||
          submittedAt.isBefore(start) ||
          !submittedAt.isBefore(end)) {
        continue;
      }
      final diff = submittedAt.difference(start).inMilliseconds;
      final rawIndex = diff ~/ bucketDuration.inMilliseconds;
      final index = rawIndex.clamp(0, period.bucketCount - 1);
      counts[index]++;
    }

    return [
      for (var index = 0; index < period.bucketCount; index++)
        InsightsTimeBucket(
          label: _bucketLabel(start, bucketDuration, index, period),
          value: counts[index],
        ),
    ];
  }

  // TO GET 12am-6am, 6am-12pm, 12pm-6pm, and 6pm-12am
  // 24H is anchored to start at midnight (0000) so first label starts at 12am
  DateTime _periodStart(DateTime now, InsightsPeriod period) {
    if (period == InsightsPeriod.hours24) {
      return DateTime(now.year, now.month, now.day);
    }
    return now.subtract(period.duration);
  }

  // 24H chart ends at next midnight (0000)
  DateTime _periodEnd(DateTime now, InsightsPeriod period) {
    if (period == InsightsPeriod.hours24) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    return now;
  }

  // get latest period range
  _InsightsDateRange _periodRange(DateTime now, InsightsPeriod period) {
    return _InsightsDateRange(
      start: _periodStart(now, period),
      end: _periodEnd(now, period),
    );
  }

  // get previous period range
  _InsightsDateRange _previousPeriodRange(_InsightsDateRange currentRange) {
    final duration = currentRange.end.difference(currentRange.start);
    return _InsightsDateRange(
      start: currentRange.start.subtract(duration),
      end: currentRange.start,
    );
  }

  // get average completed issue durations by category
  List<InsightsResolutionItem> _averageResolutionByCategory(
    List<IssueSummary> issues,
  ) {
    final byCategory = <String, List<double>>{};
    for (final issue in issues) {
      final duration = _completionDurationDays(issue);
      if (duration == null) continue;
      byCategory.putIfAbsent(issue.category, () => <double>[]).add(duration);
    }

    final entries = byCategory.entries.toList()
      ..sort((left, right) {
        final leftAvg = _average(left.value);
        final rightAvg = _average(right.value);
        return rightAvg.compareTo(leftAvg);
      });

    return [
      for (var index = 0; index < entries.length; index++)
        InsightsResolutionItem(
          category: entries[index].key,
          averageDays: _average(entries[index].value),
          color: _chartColor(index),
        ),
    ];
  }

  // valid check for completion duration
  List<double> _completedDurations(List<IssueSummary> issues) {
    return issues
        .map(_completionDurationDays)
        .whereType<double>()
        .toList(growable: false);
  }

  // duration calculated from submitted time to completed time

  double? _completionDurationDays(IssueSummary issue) {
    final submittedAt = issue.submittedAt;
    final completedAt = issue.completedAt;
    // invalid or reversed dates are ignored
    if (submittedAt == null || completedAt == null) return null;
    if (completedAt.isBefore(submittedAt)) return null;
    final hours = max(1, completedAt.difference(submittedAt).inHours);
    return hours / 24;
  }

  // converts list of completed durations into shortest, longest and average
  _DurationStats _durationStats(List<double> durations) {
    if (durations.isEmpty) return const _DurationStats.empty();
    return _DurationStats(
      shortestDays: durations.reduce(min),
      longestDays: durations.reduce(max),
      averageDays: _average(durations),
    );
  }

  // formula to calculate average
  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  // converts current-vs-previous values into rounded percentage
  int _trendPercent(num current, num previous) {
    // no previous data, any new non-zero value is shown as +100%
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous * 100).round();
  }

  int _trendPercentDouble(double? current, double? previous) {
    return _trendPercent(current ?? 0, previous ?? 0);
  }

  // pick strongest category for key finding card
  InsightsKeyFinding _keyFinding(
    InsightsBreakdownItem? topCategory,
    int totalComplaints,
  ) {
    if (topCategory == null || totalComplaints == 0) {
      return const InsightsKeyFinding(
        title: 'Focus Area',
        value: 'No data',
        detail: 'No complaints in this period',
      );
    }

    final percentage = (topCategory.value / totalComplaints * 100).round();
    return InsightsKeyFinding(
      title: 'Top Category',
      value: topCategory.label,
      detail: '$percentage% of total complaints',
    );
  }

  // reuses the same area breakdown sorting logic
  InsightsActiveArea _mostActiveArea(List<IssueSummary> issues) {
    final areas = _areaBreakdown(issues);
    if (areas.isEmpty) {
      return InsightsActiveArea(
        area: 'No area data',
        count: 0,
        period: _selectedPeriod,
      );
    }

    return InsightsActiveArea(
      area: areas.first.area,
      count: areas.first.count,
      period: _selectedPeriod,
    );
  }

  // build x-axis label
  String _bucketLabel(
    DateTime start,
    Duration bucketDuration,
    int index,
    InsightsPeriod period,
  ) {
    final bucketStart = start.add(bucketDuration * index);
    final bucketEnd = start.add(bucketDuration * (index + 1));
    return switch (period) {
      InsightsPeriod.hours24 =>
        '${_formatHour(bucketStart)}-${_formatHour(bucketEnd)}',
      InsightsPeriod.days7 => _formatMonthDay(bucketStart),
      InsightsPeriod.days30 || InsightsPeriod.days90 =>
        '${_formatMonthDay(bucketStart)}-${_formatMonthDay(bucketEnd)}',
    };
  }

  // formats 24h value into 12h labels
  String _formatHour(DateTime date) {
    final hour = date.hour;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'am' : 'pm';
    return '$hour12$suffix';
  }

  // formats month and day value to mm/dd
  String _formatMonthDay(DateTime date) {
    return '${date.month}/${date.day}';
  }

  // format 1 day hours value as short as possible
  String _formatDays(double? days) {
    if (days == null || days <= 0) return '-';
    if (days < 1) return '${(days * 24).round()}H';
    return '${days.toStringAsFixed(1)}D';
  }

  // chart color palette
  Color _chartColor(int index) {
    const colors = [
      Color(0xFFFFCB59),
      Color(0xFFFF686B),
      Color(0xFF13B300),
      Color(0xFFE9F500),
      Color(0xFFD45CF5),
      Color(0xFF39A7FF),
      Color(0xFF00C7A8),
      Color(0xFFFF8A3D),
      Color(0xFF7E57FF),
      Color(0xFF6D7787),
    ];
    return colors[index % colors.length];
  }
}

// category waiting-time stats
class _DurationStats {
  const _DurationStats({
    required this.shortestDays,
    required this.longestDays,
    required this.averageDays,
  });

  const _DurationStats.empty()
    : shortestDays = null,
      longestDays = null,
      averageDays = null;

  final double? shortestDays;
  final double? longestDays;
  final double? averageDays;
}

// start and end range used for period filtering
class _InsightsDateRange {
  const _InsightsDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
