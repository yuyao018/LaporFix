import '../../summary/models/issue_status.dart';

// for the detail progress row
class IssueDetailProgressStep {
  const IssueDetailProgressStep({
    required this.status,
    required this.label,
    required this.isReached,
    this.date,
  });

  final IssueStatus status;
  final String label;
  final bool isReached;
  final DateTime? date;
}

//  for the detailed updates
class IssueDetailUpdate {
  const IssueDetailUpdate({
    required this.title,
    required this.description,
    this.timestamp,
  });

  final String title;
  final String description;
  final DateTime? timestamp;
}
