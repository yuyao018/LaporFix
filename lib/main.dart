import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
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
import 'features/AI_chatbot/view_models/chat_view_model.dart';
import 'services/app_settings_service.dart';
import 'services/fcm_service.dart';
import 'widgets/app_tour.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await AppSettingsService.instance.initialize();
  runApp(const MyApp());
  await FcmService.instance.initialize();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: FcmService.navigatorKey,
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

  final GlobalKey _homeTabKey = GlobalKey();
  final GlobalKey _issueTabKey = GlobalKey();
  final GlobalKey _communityTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();
  final GlobalKey _chatbotFabKey = GlobalKey();

  // Tab mapping:
  // 0 — Home      => AnnouncementPage
  // 1 — Issue     => StatusTrackerPage
  // 2 — Community => UpvotingPage
  // 3 — Profile   => ProfilePage

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTour());
  }

  Future<void> _checkAndShowTour() async {
    final shouldShow = await AppSettingsService.instance.shouldShowAppTour();
    if (shouldShow && mounted) {
      AppTour.start(
        context: context,
        homeKey: _homeTabKey,
        issueKey: _issueTabKey,
        communityKey: _communityTabKey,
        profileKey: _profileTabKey,
        chatbotKey: _chatbotFabKey,
      );
    }
  }

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
              itemKeys: [_homeTabKey, _issueTabKey, _communityTabKey, _profileTabKey],
            ),
      floatingActionButton: _selectedIndex == 3
          ? null
          : ChatbotFab(
              key: _chatbotFabKey,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => ChatViewModel(),
                      child: ChatbotPage(
                          onBack: () => Navigator.pop(context)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
