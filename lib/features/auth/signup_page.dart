import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/button.dart';
import '../../widgets/location_search_sheet.dart';

/// Sign up form content — displayed inside AuthPage's white card.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Location data
  String _selectedAddress = '';
  String _selectedArea = '';
  String _selectedState = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LocationSearchSheet(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result['full'] ?? '';
        _selectedArea = result['area'] ?? '';
        _selectedState = result['state'] ?? '';
      });
    }
  }

  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        _selectedAddress.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(username);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': username,
          'email': email,
          'homeAddress': _selectedAddress,
          'area': _selectedArea,
          'state': _selectedState,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'photoURL': '',
        });
      }
    } on FirebaseAuthException catch (e) {
      _showError('Auth error: ${e.code} — ${e.message}');
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Username field ──
        Text('Username', style: tt.bodySmall),
        const SizedBox(height: 8),
        _InputField(
          controller: _usernameController,
          hintText: 'User A',
        ),
        const SizedBox(height: 20),

        // ── Email field ──
        Text('Email', style: tt.bodySmall),
        const SizedBox(height: 8),
        _InputField(
          controller: _emailController,
          hintText: 'user@gmail.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),

        // ── Password field ──
        Text('Password', style: tt.bodySmall),
        const SizedBox(height: 8),
        _InputField(
          controller: _passwordController,
          hintText: '••••••••',
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 20),

        // ── Confirm Password field ──
        Text('Confirm Password', style: tt.bodySmall),
        const SizedBox(height: 8),
        _InputField(
          controller: _confirmPasswordController,
          hintText: '••••••••',
          obscureText: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 20),

        // ── Home Address (location picker) ──
        Text('Home Address', style: tt.bodySmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickLocation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedAddress.isEmpty
                        ? 'Search your location...'
                        : _selectedAddress,
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedAddress.isEmpty
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.location_on_outlined,
                    color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Sign in button ──
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(label: 'Sign Up', onPressed: _signUp),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Input Field
// ─────────────────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}


