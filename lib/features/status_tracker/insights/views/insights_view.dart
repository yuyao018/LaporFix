import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/function_appbar.dart';
import '../models/insights_models.dart';
import '../viewmodels/insights_view_model.dart';
import 'components/insights_widgets.dart';

// UI for report insights.
// listens to the ViewModel and decides which layout to show
class InsightsView extends StatelessWidget {
  const InsightsView({super.key, required this.viewModel});

  final InsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        // keeps the page reactive without introducing another state-management
        return Scaffold(
          appBar: const FunctionAppBar(title: 'Report Insights'),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.functionBackground,
            ),
            child: SafeArea(top: false, child: _buildBody(context)),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (viewModel.hasError) {
      return InsightsErrorState(
        message: viewModel.error.toString(),
        onRetry: viewModel.start,
      );
    }

    final dataset = viewModel.dataset;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(
        children: [
          // filter changes stay in ViewModel, view only rebuilds requested layout
          InsightsToolbar(
            selectedLabel: viewModel.selectedFilterLabel,
            filterLabels: viewModel.filterLabels,
            selectedPeriod: viewModel.selectedPeriod,
            onFilterChanged: viewModel.updateFilter,
            onPeriodChanged: viewModel.updatePeriod,
          ),
          const SizedBox(height: 16),
          // null category means Overview
          // else display own dashboard
          if (dataset.categoryDetail == null)
            _OverviewContent(
              dataset: dataset,
              engagementLimit: viewModel.engagementLimit,
              engagementLimitOptions: viewModel.engagementLimitOptions,
              onEngagementLimitChanged: viewModel.updateEngagementLimit,
            )
          else
            _CategoryContent(
              dataset: dataset,
              areaLimit: viewModel.areaLimit,
              areaLimitOptions: viewModel.areaLimitOptions,
              visibleAreas: viewModel.visibleAreaBreakdown,
              onAreaLimitChanged: viewModel.updateAreaLimit,
              engagementLimit: viewModel.engagementLimit,
              engagementLimitOptions: viewModel.engagementLimitOptions,
              onEngagementLimitChanged: viewModel.updateEngagementLimit,
            ),
        ],
      ),
    );
  }
}

// combines whole-system analytics for a period including:
// - 3 KPI cards
// - category charts
// - time trend
// - strongest location signal
class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.dataset,
    required this.engagementLimit,
    required this.engagementLimitOptions,
    required this.onEngagementLimitChanged,
  });

  final InsightsDataset dataset;
  final int engagementLimit;
  final List<int> engagementLimitOptions;
  final ValueChanged<int> onEngagementLimitChanged;

  @override
  Widget build(BuildContext context) {
    final overview = dataset.overview;
    final visibleEngagements = overview.topEngagements
        .take(engagementLimit)
        .toList(growable: false);

    return Column(
      children: [
        InsightsMetricGrid(metrics: overview.metrics),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InsightsSectionCard(
                title: 'Complaints by Category',
                icon: Icons.bar_chart_rounded,
                child: InsightsHorizontalBarChart(
                  items: overview.categoryBreakdown,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InsightsSectionCard(
                title: 'Complaints Distribution',
                icon: Icons.pie_chart_rounded,
                child: InsightsDistributionChart(
                  items: overview.categoryBreakdown,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InsightsSectionCard(
          title: 'Complaints Over Time',
          icon: Icons.trending_up_rounded,
          child: InsightsLineChart(buckets: overview.complaintsOverTime),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InsightsSectionCard(
                title: 'Avg. Resolution Time by Category',
                icon: Icons.bar_chart_rounded,
                child: InsightsResolutionBarChart(
                  items: overview.averageResolutionByCategory,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: InsightsKeyFindingCard(overview.keyFinding)),
          ],
        ),
        const SizedBox(height: 16),
        InsightsActiveAreaCard(activeArea: overview.mostActiveArea),
        const SizedBox(height: 16),
        InsightsSectionCard(
          title: 'Top Engagements',
          icon: Icons.forum_rounded,
          trailing: InsightsEngagementLimitDropdown(
            value: engagementLimit,
            options: engagementLimitOptions,
            onChanged: onEngagementLimitChanged,
          ),
          child: InsightsTopEngagementList(
            items: visibleEngagements,
            showCategory: true,
            onItemTap: (_) {},
          ),
        ),
      ],
    );
  }
}

// combines category analytics for a period including:
// - 6 KPI cards
// - time trend
// - strongest location signal
class _CategoryContent extends StatelessWidget {
  const _CategoryContent({
    required this.dataset,
    required this.areaLimit,
    required this.areaLimitOptions,
    required this.visibleAreas,
    required this.onAreaLimitChanged,
    required this.engagementLimit,
    required this.engagementLimitOptions,
    required this.onEngagementLimitChanged,
  });

  final InsightsDataset dataset;
  final int areaLimit;
  final List<int> areaLimitOptions;
  final List<InsightsAreaItem> visibleAreas;
  final ValueChanged<int> onAreaLimitChanged;
  final int engagementLimit;
  final List<int> engagementLimitOptions;
  final ValueChanged<int> onEngagementLimitChanged;

  @override
  Widget build(BuildContext context) {
    final detail = dataset.categoryDetail!;
    final visibleEngagements = detail.topEngagements
        .take(engagementLimit)
        .toList(growable: false);

    return Column(
      children: [
        InsightsMetricGrid(metrics: detail.metrics),
        const SizedBox(height: 16),
        InsightsSectionCard(
          title: 'Complaints by Area',
          icon: Icons.bar_chart_rounded,
          trailing: InsightsAreaLimitDropdown(
            value: areaLimit,
            options: areaLimitOptions,
            onChanged: onAreaLimitChanged,
          ),
          child: InsightsAreaBarChart(items: visibleAreas),
        ),
        const SizedBox(height: 16),
        InsightsSectionCard(
          title: 'Complaints Over Time (${detail.category})',
          icon: Icons.trending_up_rounded,
          child: InsightsLineChart(buckets: detail.complaintsOverTime),
        ),
        const SizedBox(height: 16),
        InsightsActiveAreaCard(activeArea: detail.mostActiveArea),
        const SizedBox(height: 16),
        InsightsSectionCard(
          title: 'Top Engagements (${detail.category})',
          icon: Icons.forum_rounded,
          trailing: InsightsEngagementLimitDropdown(
            value: engagementLimit,
            options: engagementLimitOptions,
            onChanged: onEngagementLimitChanged,
          ),
          child: InsightsTopEngagementList(
            items: visibleEngagements,
            showCategory: false,
            onItemTap: (_) {},
          ),
        ),
      ],
    );
  }
}
