import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/app_theme.dart';
import '../../models/insights_models.dart';

const double _insightsControlHeight = 32;
const double _insightsControlInnerHeight = 26;
const int _metricGridColumnCount = 3;
const double _metricGridSpacing = 12;
const double _compactMetricCardHeight = 76;

// Error view when Firestore cannot provide insight data.
class InsightsErrorState extends StatelessWidget {
  const InsightsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.textSecondary,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to load insights',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// top control row
class InsightsToolbar extends StatelessWidget {
  const InsightsToolbar({
    super.key,
    required this.selectedLabel,
    required this.filterLabels,
    required this.selectedPeriod,
    required this.onFilterChanged,
    required this.onPeriodChanged,
  });

  final String selectedLabel;
  final List<String> filterLabels;
  final InsightsPeriod selectedPeriod;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<InsightsPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Contains Overview plus categories generated from Firebase data.
        _InsightDropdown(
          value: selectedLabel,
          values: filterLabels,
          onChanged: onFilterChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PeriodSelector(
            selectedPeriod: selectedPeriod,
            onChanged: onPeriodChanged,
          ),
        ),
      ],
    );
  }
}

// grid for the KPI cards
class InsightsMetricGrid extends StatelessWidget {
  const InsightsMetricGrid({super.key, required this.metrics});

  final List<InsightsMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth -
                (_metricGridColumnCount - 1) * _metricGridSpacing) /
            _metricGridColumnCount;
        final rows = <List<InsightsMetric>>[
          for (var index = 0; index < metrics.length; index += 3)
            metrics
                .skip(index)
                .take(_metricGridColumnCount)
                .toList(growable: false),
        ];

        return Column(
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              _MetricGridRow(
                metrics: rows[rowIndex],
                height: rows[rowIndex].any((metric) => metric.hasTrend)
                    ? cellWidth / 1.05
                    : _compactMetricCardHeight,
              ),
              if (rowIndex != rows.length - 1)
                const SizedBox(height: _metricGridSpacing),
            ],
          ],
        );
      },
    );
  }
}

class _MetricGridRow extends StatelessWidget {
  const _MetricGridRow({required this.metrics, required this.height});

  final List<InsightsMetric> metrics;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var index = 0; index < _metricGridColumnCount; index++) ...[
            if (index > 0) const SizedBox(width: _metricGridSpacing),
            Expanded(
              child: index < metrics.length
                  ? _MetricCard(metric: metrics[index])
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

// white card wrapper for each chart section
// trailing widget optional
class InsightsSectionCard extends StatelessWidget {
  const InsightsSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.black),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// bars for complaints by category
class InsightsCategoryBreakdownChart extends StatelessWidget {
  const InsightsCategoryBreakdownChart({super.key, required this.items});

  final List<InsightsBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyChart(message: 'No category data');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: InsightsHorizontalBarChart(items: items)),
        const SizedBox(width: 14),
        SizedBox(
          width: 96,
          height: 96,
          child: InsightsDistributionChart(items: items),
        ),
      ],
    );
  }
}

class InsightsHorizontalBarChart extends StatelessWidget {
  const InsightsHorizontalBarChart({super.key, required this.items});

  final List<InsightsBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyChart(message: 'No category data');

    final maxValue = items.map((item) => item.value).reduce(math.max);

    return Column(
      children: [
        for (final item in items.take(6))
          _HorizontalBarRow(
            label: item.label,
            value: item.value,
            maxValue: maxValue,
            color: item.color,
          ),
      ],
    );
  }
}

// bars for complaints by area
class InsightsAreaBarChart extends StatelessWidget {
  const InsightsAreaBarChart({super.key, required this.items});

  final List<InsightsAreaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyChart(message: 'No area data');

    final maxValue = items.map((item) => item.count).reduce(math.max);

    return Column(
      children: [
        for (final item in items)
          _HorizontalBarRow(
            label: item.area,
            value: item.count,
            maxValue: maxValue,
            color: item.color,
          ),
      ],
    );
  }
}

// pie chart for complaints by category, without a repeated legend
class InsightsDistributionChart extends StatefulWidget {
  const InsightsDistributionChart({super.key, required this.items});

  final List<InsightsBreakdownItem> items;

  @override
  State<InsightsDistributionChart> createState() =>
      _InsightsDistributionChartState();
}

class _InsightsDistributionChartState extends State<InsightsDistributionChart> {
  OverlayEntry? _magnifierOverlay;

  @override
  void didUpdateWidget(covariant InsightsDistributionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _hideMagnifier();
    }
  }

  @override
  void dispose() {
    _hideMagnifier();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const _EmptyChart(message: 'No distribution data');
    }

    return GestureDetector(
      onLongPressStart: (_) {
        if (_magnifierOverlay == null) _showMagnifier();
      },
      onLongPressEnd: (_) => _hideMagnifier(),
      child: CustomPaint(
        painter: _PieChartPainter(widget.items),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _showMagnifier() {
    if (_magnifierOverlay != null) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);
    final panelWidth = math.min(220.0, screenSize.width - 24);
    final estimatedHeight = 42.0 + widget.items.length * 23.0;
    final rawLeft = origin.dx + renderObject.size.width / 2 - panelWidth / 2;
    final rawTop = origin.dy - estimatedHeight;
    final top = rawTop < 12 ? origin.dy + renderObject.size.height : rawTop;
    final left = rawLeft
        .clamp(12.0, screenSize.width - panelWidth - 12)
        .toDouble();
    final total = widget.items.fold<int>(0, (sum, item) => sum + item.value);

    _magnifierOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: _PieChartMagnifier(
              items: widget.items,
              total: total,
              width: panelWidth,
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_magnifierOverlay!);
  }

  void _hideMagnifier() {
    _magnifierOverlay?.remove();
    _magnifierOverlay = null;
  }
}

class _PieChartMagnifier extends StatelessWidget {
  const _PieChartMagnifier({
    required this.items,
    required this.total,
    required this.width,
  });

  final List<InsightsBreakdownItem> items;
  final int total;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width - 20,
                child: Text(
                  'Complaints Breakdown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: SizedBox(
                    width: width - 20,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.value} (${_percentage(item)}%)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _percentage(InsightsBreakdownItem item) {
    if (total == 0) return 0;
    return (item.value / total * 100).round();
  }
}

// line chart for issue volume across selected period
class InsightsLineChart extends StatelessWidget {
  const InsightsLineChart({super.key, required this.buckets});

  final List<InsightsTimeBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const _EmptyChart(message: 'No time data');

    return SizedBox(
      height: 170,
      child: CustomPaint(
        painter: _LineChartPainter(
          buckets: buckets,
          textStyle: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: Colors.black, fontSize: 10),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// bars for average resolution time by category
class InsightsResolutionBarChart extends StatelessWidget {
  const InsightsResolutionBarChart({super.key, required this.items});

  final List<InsightsResolutionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyChart(message: 'No completed issues');

    return SizedBox(
      height: 168,
      child: CustomPaint(
        painter: _VerticalBarChartPainter(
          items: items,
          textStyle: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: Colors.black, fontSize: 9),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// strongest overview signal
class InsightsKeyFindingCard extends StatelessWidget {
  const InsightsKeyFindingCard(this.finding, {super.key});

  final InsightsKeyFinding finding;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      child: SizedBox(
        height: 168,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_rounded, size: 18),
                const SizedBox(width: 7),
                Text(
                  'Key Finding',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentBlue, width: 2),
                ),
                child: const Icon(
                  Icons.star_border_rounded,
                  color: AppTheme.accentBlue,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                finding.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
            Center(
              child: Text(
                finding.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                finding.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// bottom summary card showing area with most complaints
class InsightsActiveAreaCard extends StatelessWidget {
  const InsightsActiveAreaCard({super.key, required this.activeArea});

  final InsightsActiveArea activeArea;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 26, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Active Area: ${activeArea.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Total Complaints over ${activeArea.period.label}: ${activeArea.count}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// selector (5, 10, 20) for the category area's ranking chart
class InsightsAreaLimitDropdown extends StatelessWidget {
  const InsightsAreaLimitDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _TopLimitDropdown(
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }
}

// selector (3, 5, 10, 20) for the Top Engagements card
class InsightsEngagementLimitDropdown extends StatelessWidget {
  const InsightsEngagementLimitDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _TopLimitDropdown(
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }
}

// list for the highest-engagement issues in the selected period
class InsightsTopEngagementList extends StatelessWidget {
  const InsightsTopEngagementList({
    super.key,
    required this.items,
    required this.showCategory,
    required this.onItemTap,
  });

  final List<InsightsEngagementItem> items;
  final bool showCategory;
  final ValueChanged<InsightsEngagementItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyChart(message: 'No engagement data');
    }

    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          _TopEngagementRow(
            item: items[index],
            showCategory: showCategory,
            onTap: onItemTap,
            isLast: index == items.length - 1,
          ),
      ],
    );
  }
}

class _TopLimitDropdown extends StatelessWidget {
  const _TopLimitDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE4F0FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              iconSize: 18,
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text('Top $option')),
              ],
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopEngagementRow extends StatelessWidget {
  const _TopEngagementRow({
    required this.item,
    required this.showCategory,
    required this.onTap,
    required this.isLast,
  });

  final InsightsEngagementItem item;
  final bool showCategory;
  final ValueChanged<InsightsEngagementItem> onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final title = showCategory
        ? '${item.category} • ${item.location}'
        : item.location;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFDDE3EA),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 9, top: isLast ? 0 : 1),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.thumb_up_alt_rounded,
                        color: AppTheme.accentBlue,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.likesCount.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.comment_rounded,
                        color: Color(0xFF18B86B),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.commentsCount.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => onTap(item),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// KPI card
class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final InsightsMetric metric;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: metric.color, size: 28),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (metric.hasTrend) ...[
            const SizedBox(height: 3),
            _MetricTrendText(percent: metric.trendPercent!),
            const SizedBox(height: 1),
            _MetricTrendPeriodText(periodLabel: metric.trendPeriodLabel!),
          ],
        ],
      ),
    );
  }
}

// percentage row for period trend change
class _MetricTrendText extends StatelessWidget {
  const _MetricTrendText({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    // percentage itself changes color
    final trendColor = percent > 0
        ? const Color(0xFF0B8F45)
        : percent < 0
        ? const Color(0xFFD92D20)
        : AppTheme.textSecondary;
    final sign = percent > 0 ? '+' : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$sign$percent%',
            style: TextStyle(color: trendColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5),
    );
  }
}

// text row that names the comparison period
class _MetricTrendPeriodText extends StatelessWidget {
  const _MetricTrendPeriodText({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      'vs previous $periodLabel',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.black, fontSize: 8.5),
    );
  }
}

// dropdown used by category filter
class _InsightDropdown extends StatelessWidget {
  const _InsightDropdown({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _insightsControlHeight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            color: Color(0xFFA9D5FF),
            shape: StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            child: Center(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: values.contains(value) ? value : 'Overview',
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  items: [
                    for (final item in values)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (next) {
                    if (next != null) onChanged(next);
                  },
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// tab bar for 24H, 7D, 30D and 90D period
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final InsightsPeriod selectedPeriod;
  final ValueChanged<InsightsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _insightsControlHeight,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              for (final period in InsightsPeriod.values)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onChanged(period),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      height: _insightsControlInnerHeight,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: selectedPeriod == period
                            ? const Color(0xFF9ACBFF)
                            : Colors.transparent,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        period.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selectedPeriod == period
                              ? AppTheme.accentBlue
                              : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// row used by category and area horizontal bar charts
class _HorizontalBarRow extends StatelessWidget {
  const _HorizontalBarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final factor = maxValue == 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: FractionallySizedBox(
              // A tiny minimum width keeps non-zero values visible even when
              // another category has a much larger count.
              widthFactor: factor.clamp(0.04, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(height: 10, color: color),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 24,
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// shared white card style
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// empty state for every chart
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// painter for category distribution pie chart
class _PieChartPainter extends CustomPainter {
  const _PieChartPainter(this.items);

  final List<InsightsBreakdownItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<int>(0, (sum, item) => sum + item.value);
    if (total == 0) return;

    final diameter = math.min(size.width, size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: diameter,
      height: diameter,
    );
    final radius = diameter / 2;
    var startAngle = -math.pi / 2;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    // Each category gets a proportional slice using the colors prepared in the
    // ViewModel, so the legend and pie remain visually connected.
    for (final item in items) {
      final sweep = item.value / total * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = item.color;
      canvas.drawArc(rect, startAngle, sweep, true, paint);

      final percentage = item.value / total * 100;
      if (percentage >= 8) {
        final midAngle = startAngle + sweep / 2;
        final labelCenter = rect.center.translate(
          math.cos(midAngle) * radius * 0.58,
          math.sin(midAngle) * radius * 0.58,
        );
        labelPainter.text = TextSpan(
          text: '${percentage.round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            labelCenter.dx - labelPainter.width / 2,
            labelCenter.dy - labelPainter.height / 2,
          ),
        );
      }

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

// painter for complaints over time chart
class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.buckets, required this.textStyle});

  final List<InsightsTimeBucket> buckets;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 32.0;
    const top = 10.0;
    const right = 8.0;
    const bottom = 34.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = math.max(
      1,
      buckets.map((bucket) => bucket.value).reduce(math.max),
    );
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.blue;

    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);

    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final yAxisTicks = _yAxisTicks(maxValue);
    for (final tickValue in yAxisTicks) {
      final y = chart.bottom - (tickValue / maxValue) * chart.height;
      labelPainter.text = TextSpan(
        text: tickValue.toString(),
        style: textStyle,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(0, y - labelPainter.height / 2));
    }

    final points = <Offset>[];
    for (var index = 0; index < buckets.length; index++) {
      final x = buckets.length == 1
          ? chart.left
          : chart.left + chart.width * index / (buckets.length - 1);
      final y = chart.bottom - (buckets[index].value / maxValue) * chart.height;
      points.add(Offset(x, y));

      labelPainter.text = TextSpan(
        text: buckets[index].label,
        style: textStyle,
      );
      labelPainter.layout(maxWidth: 58);
      labelPainter.paint(
        canvas,
        Offset(x - labelPainter.width / 2, chart.bottom + 8),
      );
    }

    final path = Path();
    for (var index = 0; index < points.length; index++) {
      if (index == 0) {
        path.moveTo(points[index].dx, points[index].dy);
      } else {
        path.lineTo(points[index].dx, points[index].dy);
      }
    }

    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets;
  }

  List<int> _yAxisTicks(int maxValue) {
    // Keep ticks as clean integers and avoid repeated labels like 1, 1, 1, 0
    // when the data set is tiny.
    if (maxValue <= 1) return const [0, 1];
    if (maxValue <= 4) {
      return [for (var value = 0; value <= maxValue; value++) value];
    }

    final interval = (maxValue / 4).ceil();
    final ticks = <int>[0];
    for (var value = interval; value < maxValue; value += interval) {
      ticks.add(value);
    }
    ticks.add(maxValue);
    return ticks;
  }
}

// painter for average resolution time bars
class _VerticalBarChartPainter extends CustomPainter {
  const _VerticalBarChartPainter({
    required this.items,
    required this.textStyle,
  });

  final List<InsightsResolutionItem> items;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 24.0;
    const top = 8.0;
    const right = 8.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = math.max(
      1.0,
      items.map((item) => item.averageDays).reduce(math.max),
    );
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);

    final barSpace = chart.width / items.length;
    final barWidth = math.min(26.0, barSpace * 0.48);

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final x = chart.left + barSpace * index + (barSpace - barWidth) / 2;
      final barHeight = item.averageDays / maxValue * chart.height;
      final rect = Rect.fromLTWH(
        x,
        chart.bottom - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(rect, Paint()..color = item.color);

      textPainter.text = TextSpan(
        text: item.averageDays.toStringAsFixed(1),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, rect.top - 16),
      );

      textPainter.text = TextSpan(text: item.category, style: textStyle);
      textPainter.layout(maxWidth: barSpace);
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, chart.bottom + 7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarChartPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}
