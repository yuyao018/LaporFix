import 'package:flutter/material.dart';

import 'summary/data/status_tracker_repository.dart';
import 'summary/views/status_tracker_view.dart';

// entry point to status tracker summary page
class StatusTrackerPage extends StatelessWidget {
  const StatusTrackerPage({super.key, this.repository});

  final StatusTrackerRepository? repository;

  @override
  Widget build(BuildContext context) {
    // only creates the feature and injects data access
    // real screen state starts inside StatusTrackerView/ViewModel
    return StatusTrackerView(
      repository: repository ?? StatusTrackerRepository(),
    );
  }
}
