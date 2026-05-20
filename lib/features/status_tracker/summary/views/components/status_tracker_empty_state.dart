import 'package:flutter/material.dart';

import '../../../../../theme/app_theme.dart';

// no data and no filtered results cases
class StatusTrackerEmptyState extends StatelessWidget {
  const StatusTrackerEmptyState({
    super.key,
    required this.hasSearchQuery,
    required this.selectedStatusLabel,
  });

  final bool hasSearchQuery;
  final String selectedStatusLabel;

  @override
  Widget build(BuildContext context) {
    final title = hasSearchQuery || selectedStatusLabel != 'All'
        ? 'No matching issues'
        : 'No issues yet';
    final message = hasSearchQuery || selectedStatusLabel != 'All'
        ? 'Try adjusting the search or status filter.'
        : 'Submitted issues will appear here for tracking.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
