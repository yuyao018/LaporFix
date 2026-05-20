import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/function_appbar.dart';
import '../../summary/models/issue_status.dart';
import '../viewmodels/update_issue_view_model.dart';
import 'components/update_issue_widgets.dart';
import 'update_issue_proof_page.dart';
import 'update_issue_success_page.dart';

// first screen of update flow
class UpdateIssueView extends StatelessWidget {
  const UpdateIssueView({super.key, required this.viewModel});

  final UpdateIssueViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        // keeps the page dependency free
        return Scaffold(
          appBar: const FunctionAppBar(title: 'Update Issue'),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.functionBackground,
            ),
            child: SafeArea(
              top: false,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          UpdateIssueCard(viewModel: viewModel),
                          const Spacer(),
                          UpdateIssuePrimaryButton(
                            label: 'Next',
                            isLoading: viewModel.isSaving,
                            onPressed: viewModel.canContinue
                                ? () => _handleNext(context)
                                : null,
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
      },
    );
  }

  Future<void> _handleNext(BuildContext context) async {
    final status = viewModel.draft.selectedStatus;
    if (status == IssueStatus.completed) {
      // completed issues need proof first
      // page returns true only after Firestore saved and success screen auto-closed
      final wasUpdated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UpdateIssueProofPage(viewModel: viewModel),
        ),
      );
      if (wasUpdated == true && context.mounted) {
        // clear update route
        Navigator.of(context).pop(true);
      }
      return;
    }

    try {
      await viewModel.saveStatusUpdate();
      if (!context.mounted) return;
      // success page pops itself after 2 seconds with true
      // form pops so the user lands back to refreshed detail page
      final wasUpdated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const UpdateIssueSuccessPage()),
      );
      if (wasUpdated == true && context.mounted) {
        // This closes the update form after the success page has closed itself.
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update issue: $error')));
    }
  }
}
