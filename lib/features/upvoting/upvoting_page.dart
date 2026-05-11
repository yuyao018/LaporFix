import 'package:flutter/material.dart';
import '../../widgets/main_appbar.dart';

class UpvotingPage extends StatelessWidget {
  const UpvotingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Community',
        showSearchBar: true,
        showFilter: true,
        filterList: const ['All', 'Newest', 'Most Supported'],
      ),
      body: const Center(
        child: Text('Upvoting Page'),
      ),
    );
  }
}
