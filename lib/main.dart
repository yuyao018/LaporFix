import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'widgets/bottom_navbar.dart';
import 'theme/app_theme.dart';
import 'features/auth/auth_page.dart';
import 'features/announcement/announcement_page.dart';
import 'features/status_tracker/status_tracker_page.dart';
import 'features/upvoting/upvoting_page.dart';
import 'features/Profile/profile_page.dart';
import 'features/AI_chatbot/chatbot_button.dart';
import 'features/AI_chatbot/chatbot_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LaporFix',
      theme: AppTheme.mainTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // If logged in, show main app
          if (snapshot.hasData) {
            return const RootNavigation();
          }
          // If not logged in, show auth page
          return const AuthPage();
        },
      ),
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
  // 1 — Issue     => StatusTrackerPage
  // 2 — Community => UpvotingPage
  // 3 — Profile   => ProfilePage

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const AnnouncementPage(),
      // The Issue tab now opens the status summary page.
      // The add button is visible there, with the report flow to be wired later.
      const StatusTrackerPage(),
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
      floatingActionButton: _selectedIndex == 3
          ? null
          : ChatbotFab(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatbotPage(onBack: () => Navigator.pop(context)),
                  ),
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
