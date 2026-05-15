import 'package:flutter/material.dart';

class ChatbotCard extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const ChatbotCard({
    super.key,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onPressed,
      child: Card(
        color: Colors.white.withAlpha(60),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 360,
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 30,
                  color: Colors.black,
                ),
                const SizedBox(width: 20),
                Text(
                  title,
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
