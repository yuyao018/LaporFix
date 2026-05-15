import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/function_appbar.dart';
import '../../widgets/chatbox.dart';
import 'widgets/card.dart';

class ChatbotPage extends StatelessWidget {
  final VoidCallback? onBack;
  const ChatbotPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FunctionAppBar(title: 'LAPI', onBack: onBack, showHistory: true),
      backgroundColor: const Color(0xFFF8F9FF), // pale off-white
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.functionBackground,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/image/lapo_robot.png'),
            const SizedBox(height: 20),
            Text(
              'Good Evening, Jane!',
              style: textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 100),
            ChatbotCard(
              title: 'How to report an issue?',
              onPressed: () {},
            ),
            ChatbotCard(
              title: 'Track my existing ticket',
              onPressed: () {},
            ),
            ChatbotCard(
              title: 'Check for water/power cut',
              onPressed: () {},
            ),
          ],
        ),
      ),
      bottomSheet: ChatBox(
        hintText: 'Ask Something ...',
        showPlusButton: true,
      ),
    );
  }
}
