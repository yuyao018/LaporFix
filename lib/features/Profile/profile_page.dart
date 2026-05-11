import 'package:flutter/material.dart';
import '../../widgets/function_appbar.dart';
import '../../theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback? onBack;

  const ProfilePage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FunctionAppBar(title: 'My Profile', onBack: onBack),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: const Text('Profile Page'),
      ),
    );
  }
}
