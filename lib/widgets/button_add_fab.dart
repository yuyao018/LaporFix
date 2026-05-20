import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ButtonAddFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const ButtonAddFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradientDiagonal,
      ),
      child: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        onPressed: onPressed,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}
