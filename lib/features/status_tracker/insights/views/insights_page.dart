import 'package:flutter/material.dart';

import '../data/insights_repository.dart';
import '../viewmodels/insights_view_model.dart';
import 'insights_view.dart';

// Route-level owner for insights MVVM objects
// ViewModel creation here
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key, this.repository});

  final InsightsRepository? repository;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  late final InsightsViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    // start Firestore stream once when the page is opened
    _viewModel = InsightsViewModel(
      repository: widget.repository ?? InsightsRepository(),
    )..start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // view receives a ready ViewModel and does not create data objects
    return InsightsView(viewModel: _viewModel);
  }
}
