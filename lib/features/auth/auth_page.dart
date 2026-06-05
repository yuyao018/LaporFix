import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'login_page.dart';
import 'signup_page.dart';

/// Wrapper that shows the gradient header + tab toggle (Sign In / Sign Up)
/// and switches between LoginPage and SignupPage content.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true; // true = Sign In tab, false = Sign Up tab

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradientDiagonal,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── App title ──
                          const Text(
                            'LaporFix',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textOnGradient,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── White card ──
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Tab toggle ──
                                _TabToggle(
                                  isLogin: _isLogin,
                                  onToggle: (val) =>
                                      setState(() => _isLogin = val),
                                ),
                                const SizedBox(height: 24),

                                // ── Form content ──
                                if (_isLogin)
                                  const LoginPage()
                                else
                                  const SignupPage(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Toggle Widget
// ─────────────────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;

  const _TabToggle({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isLogin ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign In',
                  style: tt.labelLarge?.copyWith(
                    color: isLogin ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isLogin ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign Up',
                  style: tt.labelLarge?.copyWith(
                    color: !isLogin ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
