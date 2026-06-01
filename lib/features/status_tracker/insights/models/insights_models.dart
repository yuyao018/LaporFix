import 'package:flutter/material.dart';

// mini card data shown at the top of insights
class InsightsMetric {
  const InsightsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trendPercent,
    this.trendPeriodLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int? trendPercent;
  final String? trendPeriodLabel;

  bool get hasTrend => trendPercent != null && trendPeriodLabel != null;
}

// 1 row of a categorical count chart
class InsightsBreakdownItem {
  const InsightsBreakdownItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

// complaints-over-time line chart.
class InsightsTimeBucket {
  const InsightsTimeBucket({required this.label, required this.value});

  final String label;
  final int value;
}

// average completion duration for one category.
class InsightsResolutionItem {
  const InsightsResolutionItem({
    required this.category,
    required this.averageDays,
    required this.color,
  });

  final String category;
  final double averageDays;
  final Color color;
}

// complaint count for one location/area
class InsightsAreaItem {
  const InsightsAreaItem({
    required this.area,
    required this.count,
    required this.color,
  });

  final String area;
  final int count;
  final Color color;
}

// one issue row for the Top Engagements card
class InsightsEngagementItem {
  const InsightsEngagementItem({
    required this.issueId,
    required this.category,
    required this.location,
    required this.likesCount,
    required this.commentsCount,
  });

  final String issueId;
  final String category;
  final String location;
  final int likesCount;
  final int commentsCount;

  // total engagement is only used for sorting/ranking the rows
  int get totalEngagement => likesCount + commentsCount;
}

// small summary card that highlights most important insight
class InsightsKeyFinding {
  const InsightsKeyFinding({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;
}

// top location for the selected period & category
class InsightsActiveArea {
  const InsightsActiveArea({
    required this.area,
    required this.count,
    required this.period,
  });

  final String area;
  final int count;
  final InsightsPeriod period;
}

// insights data snapshot
class InsightsDataset {
  const InsightsDataset({
    required this.categories,
    required this.period,
    required this.selectedCategory,
    required this.overview,
    required this.categoryDetail,
  });

  final List<String> categories;
  final InsightsPeriod period;
  final String? selectedCategory;
  final OverviewInsights overview;
  final CategoryInsights? categoryDetail;
}

// system-wide analytics shown (overview)
class OverviewInsights {
  const OverviewInsights({
    required this.metrics,
    required this.categoryBreakdown,
    required this.complaintsOverTime,
    required this.averageResolutionByCategory,
    required this.keyFinding,
    required this.mostActiveArea,
    required this.topEngagements,
  });

  final List<InsightsMetric> metrics;
  final List<InsightsBreakdownItem> categoryBreakdown;
  final List<InsightsTimeBucket> complaintsOverTime;
  final List<InsightsResolutionItem> averageResolutionByCategory;
  final InsightsKeyFinding keyFinding;
  final InsightsActiveArea mostActiveArea;
  final List<InsightsEngagementItem> topEngagements;
}

// for one selected category
class CategoryInsights {
  const CategoryInsights({
    required this.category,
    required this.metrics,
    required this.areaBreakdown,
    required this.complaintsOverTime,
    required this.mostActiveArea,
    required this.topEngagements,
  });

  final String category;
  final List<InsightsMetric> metrics;
  final List<InsightsAreaItem> areaBreakdown;
  final List<InsightsTimeBucket> complaintsOverTime;
  final InsightsActiveArea mostActiveArea;
  final List<InsightsEngagementItem> topEngagements;
}

// insight period predefined buckets
enum InsightsPeriod {
  // from 12am today to 12am tomorrow
  // split into 4 ->  6-hour buckets
  hours24('24H', Duration(hours: 24), 4),

  days7('7D', Duration(days: 7), 7),
  days30('30D', Duration(days: 30), 5),
  days90('90D', Duration(days: 90), 6);

  const InsightsPeriod(this.label, this.duration, this.bucketCount);

  final String label;
  final Duration duration;
  final int bucketCount;
}
