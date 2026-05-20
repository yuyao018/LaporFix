import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import 'components/update_issue_widgets.dart';

// temporary confirmation screen shown after Firebase save succeeds
// then automatically returns to the refreshed details
class UpdateIssueSuccessPage extends StatefulWidget {
  const UpdateIssueSuccessPage({super.key});

  @override
  State<UpdateIssueSuccessPage> createState() => _UpdateIssueSuccessPageState();
}

class _UpdateIssueSuccessPageState extends State<UpdateIssueSuccessPage> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    // briefly show confirmation
    _closeTimer = Timer(const Duration(seconds: 2), _closePage);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _closePage() {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: const Center(child: UpdateSuccessCard()),
      ),
    );
  }
}
