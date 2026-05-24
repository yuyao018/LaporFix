import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/button_add_fab.dart';
import '../../../../widgets/main_appbar.dart';
import '../../../issue_reporting/issue_reporting_page.dart';
import '../../details/views/issue_details_page.dart';
import '../data/status_tracker_repository.dart';
import '../models/issue_summary.dart';
import '../viewmodels/status_tracker_view_model.dart';
import 'components/issue_summary_card.dart';
import 'components/status_tracker_empty_state.dart';
import 'components/status_tracker_error_state.dart';

// main view for all of the summary
class StatusTrackerView extends StatefulWidget {
  const StatusTrackerView({super.key, required this.repository});

  final StatusTrackerRepository repository;

  @override
  State<StatusTrackerView> createState() => _StatusTrackerViewState();
}

class _StatusTrackerViewState extends State<StatusTrackerView> {
  late final StatusTrackerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // start listening once view created
    // stream subscription itself lives in the ViewModel, not in widget tree
    _viewModel = StatusTrackerViewModel(repository: widget.repository)..start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openIssueDetails(IssueSummary issue) {
    // pass the same repository into details
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            IssueDetailsPage(issue: issue, repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        // keeps this page dependency-free
        // ViewModel is the single ChangeNotifier source for all state.
        return Scaffold(
          appBar: MainAppBar(
            title: 'Issue',
            insight: true,
            showSearchBar: true,
            showFilter: true,
            filterList: _viewModel.filterLabels,
            onInsightTap: () {},
            onSearchChanged: _viewModel.updateSearchQuery,
            onFilterChanged: _viewModel.updateStatusFilter,
          ),
          body: ColoredBox(color: AppTheme.mainBackground, child: _buildBody()),
          // add new issue here
          floatingActionButton: ButtonAddFab(
            onPressed: () {
              final route = MaterialPageRoute(
                builder: (_) => const IssueReportingPage(),
              );
              Navigator.of(context).push(route);
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildBody() {
    // body renders exactly one state at a time
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.hasError) {
      return StatusTrackerErrorState(
        message: _viewModel.error.toString(),
        onRetry: _viewModel.start,
      );
    }

    final issues = _viewModel.visibleIssues;

    if (issues.isEmpty) {
      return StatusTrackerEmptyState(
        hasSearchQuery: _viewModel.searchQuery.trim().isNotEmpty,
        selectedStatusLabel: _viewModel.selectedStatus.label,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _viewModel.start(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
        itemCount: issues.length + 1,
        separatorBuilder: (_, index) {
          return index == issues.length - 1
              ? const SizedBox(height: 16)
              : const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          if (index == issues.length) {
            return _IssueCountCaption(visibleCount: issues.length);
          }

          return IssueSummaryCard(
            issue: issues[index],
            onTap: () => _openIssueDetails(issues[index]),
          );
        },
      ),
    );
  }
}

// need to modify, KIV
class _IssueCountCaption extends StatelessWidget {
  const _IssueCountCaption({required this.visibleCount});

  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '--- Showing $visibleCount active issues ---',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF98A2B3),
        fontSize: 13,
      ),
    );
  }
}
