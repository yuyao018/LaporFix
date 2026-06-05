import 'package:flutter/material.dart';

import '../../summary/data/status_tracker_repository.dart';
import '../../summary/models/issue_summary.dart';
import '../viewmodels/issue_details_view_model.dart';
import 'issue_details_view.dart';

class IssueDetailsPage extends StatefulWidget {
  const IssueDetailsPage({super.key, required this.issue, this.repository});

  final IssueSummary issue;
  final StatusTrackerRepository? repository;

  @override
  State<IssueDetailsPage> createState() => _IssueDetailsPageState();
}

class _IssueDetailsPageState extends State<IssueDetailsPage> {
  late final StatusTrackerRepository _repository;

  // single-document stream backing this page
  // keeps detail screen after update_issue writes without reloading the whole summary list
  late final Stream<IssueSummary> _issueStream;
  late final Stream<List<IssueSummary>> _systemIssuesStream;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StatusTrackerRepository();
    // keeps the first render instant
    // this stream replaces it after a status update.
    _issueStream = _repository.watchIssue(widget.issue.id);
    _systemIssuesStream = _repository.watchSystemIssues();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IssueSummary>>(
      stream: _systemIssuesStream,
      builder: (context, systemSnapshot) {
        final systemIssues = systemSnapshot.data ?? const <IssueSummary>[];

        return StreamBuilder<IssueSummary>(
          stream: _issueStream,
          builder: (context, snapshot) {
            // use tapped issue until the first snapshot arrives
            final issue = snapshot.data ?? widget.issue;
            return IssueDetailsView(
              viewModel: IssueDetailsViewModel(
                issue: issue,
                systemIssues: systemIssues,
              ),
            );
          },
        );
      },
    );
  }
}
