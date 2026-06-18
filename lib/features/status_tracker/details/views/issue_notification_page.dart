import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/function_appbar.dart';
import '../../summary/models/issue_summary.dart';
import 'issue_details_page.dart';

// Entry point used when a push notification opens a specific issue.
// It fetches the Firestore document by ID before handing off to the normal
// details page so notification navigation reuses the same detail UI.
class IssueNotificationPage extends StatelessWidget {
  final String issueId;

  const IssueNotificationPage({super.key, required this.issueId});

  @override
  Widget build(BuildContext context) {
    // Notifications only carry the issue ID, so the full issue model is loaded
    // here before rendering the details route.
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('issue').doc(issueId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: FunctionAppBar(title: 'Report Status'),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data;
        final data = doc?.data();

        // The report may have been deleted after the notification was sent.
        if (doc == null || !doc.exists || data == null) {
          return Scaffold(
            appBar: const FunctionAppBar(title: 'Report Status'),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.functionBackground,
              ),
              child: const Center(
                child: Text(
                  'This report could not be found.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        // Convert the raw Firestore document into the shared summary model used
        // throughout status tracking.
        return IssueDetailsPage(
          issue: IssueSummary.fromMap(id: doc.id, data: data),
        );
      },
    );
  }
}
