import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_warning_dialog.dart';
import '../../../../widgets/function_appbar.dart';
import '../../update_issue/views/update_issue_page.dart';
import '../viewmodels/issue_details_view_model.dart';
import 'components/issue_details_widgets.dart';

// main detail view for a single issue
// does not query or mutate Firebase directly
class IssueDetailsView extends StatelessWidget {
  const IssueDetailsView({super.key, required this.viewModel});

  final IssueDetailsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FunctionAppBar(
        title: 'Report Status',
        showHistory: true,
        onHistoryTap: () => _openUpdateIssue(context),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              // main content
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                child: Column(
                  children: [
                    IssueReportHeaderCard(viewModel: viewModel),
                    const SizedBox(height: 14),
                    IssueCurrentStatusCard(viewModel: viewModel),
                    const SizedBox(height: 14),
                    IssueProgressCard(viewModel: viewModel),
                    const SizedBox(height: 14),
                    IssueMetricRow(viewModel: viewModel),
                  ],
                ),
              ),
              Align(
                // keep the resolved/unresolved banner visible
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: IssueResolutionBanner(
                    isResolved: viewModel.isResolved,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openUpdateIssue(BuildContext context) {
    if (viewModel.isResolved) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AppWarningDialog(
            title: 'Issue Already Completed',
            message:
                'This issue has already been completed and can no longer be edited or reversed.',
            actionLabel: 'Got it',
            icon: Icons.lock_rounded,
            onAction: () => Navigator.of(dialogContext).pop(),
          );
        },
      );
      return;
    }

    // when writes to Firebase, this detail page refreshes after the flow closes
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpdateIssuePage(issue: viewModel.issue),
      ),
    );
  }
}
