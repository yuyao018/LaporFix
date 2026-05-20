import 'package:flutter/material.dart';

class FunctionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showHistory;
  final VoidCallback? onBack;
  final VoidCallback? onHistoryTap;
  const FunctionAppBar({
    super.key,
    required this.title,
    this.showHistory = false,
    this.onBack,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF5F5F5),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black,
                weight: 700,
              ),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: [
            if (showHistory)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.black,
                    size: 32,
                  ),
                  onPressed: onHistoryTap,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);
}
