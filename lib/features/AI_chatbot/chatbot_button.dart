import 'package:flutter/material.dart';

class ChatbotFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const ChatbotFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    const double size = 64.0;
    const double radius = 20.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF7B9BF8), // soft periwinkle blue
            Color(0xFF1CE6DA), // bright cyan / teal
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F80F8).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.asset(
                'assets/icons/lapo_robot.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
