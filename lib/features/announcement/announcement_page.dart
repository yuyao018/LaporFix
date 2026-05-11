import 'package:flutter/material.dart';
import '../../widgets/main_appbar.dart';
import '../../widgets/button.dart';

class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Announcement',
        showSearchBar: true,
        showFilter: false,
        showBottomContent: true,
        bottomContent: Text('Address'), //no text styling
      ),
      body: const Center(
        child: Text('Announcement Page'), //your code here
      ),
    );
  }
}
