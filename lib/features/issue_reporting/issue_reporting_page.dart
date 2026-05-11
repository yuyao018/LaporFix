import 'package:flutter/material.dart';
import '../../widgets/main_appbar.dart';

class IssueReportingPage extends StatelessWidget {
  const IssueReportingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Issue Reporting',
        showSearchBar: true,
        insight: true,
        showFilter: true,
        filterList: const ['All', 'Submitted', 'In Progress', 'Completed'],
      ),
      body: const Center(
        child: Text('Issue Reporting Page'),
      ),
    );
  }
}
