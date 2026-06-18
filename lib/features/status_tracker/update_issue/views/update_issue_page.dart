import 'package:flutter/material.dart';

import '../../summary/models/issue_summary.dart';
import '../viewmodels/update_issue_view_model.dart';
import 'update_issue_view.dart';

// Creates and disposes the ViewModel once.
// Child views can rebuild freely without losing form state or selected proof files.
class UpdateIssuePage extends StatefulWidget {
  const UpdateIssuePage({super.key, required this.issue});

  final IssueSummary issue;

  @override
  State<UpdateIssuePage> createState() => _UpdateIssuePageState();
}

class _UpdateIssuePageState extends State<UpdateIssuePage> {
  late final UpdateIssueViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // update flow starts from the latest issue object passed by details
    // after saving, details refreshes from Firestore through its own stream
    _viewModel = UpdateIssueViewModel(issue: widget.issue);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UpdateIssueView(viewModel: _viewModel);
  }
}
