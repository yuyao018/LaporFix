import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'widgets/bottom_navbar.dart';
import 'theme/app_theme.dart';
import 'features/announcement/announcement_page.dart';
import 'features/issue_reporting/issue_reporting_page.dart';
import 'features/upvoting/upvoting_page.dart';
import 'features/profile/profile_page.dart';

// Feature page imports — uncomment each once the file is created:
// import 'features/status_tracker/status_tracker_page.dart';  // Feature 2: Status Tracker
// import 'features/AI_chatbot/ai_chatbot_page.dart';          // Feature 5: AI Policy Chat

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UrbanFix',
      theme: AppTheme.mainTheme,
      home: const RootNavigation(),
    );
  }
}

class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _selectedIndex = 0;

  // Tab mapping:
  // 0 — Home      => AnnouncementPage
  // 1 — Issue     => IssueReportingPage
  // 2 — Community => UpvotingPage
  // 3 — Profile   => ProfilePage

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const AnnouncementPage(),
      const IssueReportingPage(),
      const UpvotingPage(),
      ProfilePage(onBack: () => setState(() => _selectedIndex = 0)),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: _selectedIndex == 3
          ? null
          : BottomNavBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
            ),
    );
  }
}
