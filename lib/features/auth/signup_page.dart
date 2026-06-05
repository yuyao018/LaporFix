import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../widgets/button.dart';

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
      builder: (_) => const _LocationSearchSheet(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Location Search Bottom Sheet (OpenStreetMap Nominatim)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _errorMsg = '';
  DateTime _lastSearch = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _errorMsg = '';
      });
      return;
    }

    // Nominatim rate limit: 1 request per second
    final now = DateTime.now();
    final diff = now.difference(_lastSearch).inMilliseconds;
    if (diff < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - diff));
    }
    _lastSearch = DateTime.now();

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query.trim())}'
        '&countrycodes=my'
        '&format=json'
        '&addressdetails=1'
        '&limit=10',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'LaporFix/1.0 (student project)',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _results = data.map((item) {
            final address = item['address'] as Map<String, dynamic>? ?? {};
            final suburb = address['suburb'] ??
                address['village'] ??
                address['town'] ??
                address['city_district'] ??
                '';
            final city = address['city'] ??
                address['town'] ??
                address['county'] ??
                '';
            final state = address['state'] ?? '';

            return {
              'display': item['display_name'] ?? '',
              'suburb': suburb,
              'city': city,
              'state': state,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Search failed. Try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatLocation(Map<String, dynamic> result) {
    final parts = <String>[];
    if (result['suburb'].toString().isNotEmpty) parts.add(result['suburb']);
    if (result['city'].toString().isNotEmpty &&
        result['city'] != result['suburb']) {
      parts.add(result['city']);
    }
    if (result['state'].toString().isNotEmpty) parts.add(result['state']);
    return parts.isNotEmpty ? parts.join(', ') : result['display'];
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Your Location', style: tt.titleLarge),
              const SizedBox(height: 4),
              Text('Search any location in Malaysia', style: tt.bodySmall),
              const SizedBox(height: 12),

              // Search field
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _search,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Type location and press Enter...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon:
                        Icon(Icons.search, color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMsg,
                      style: tt.bodySmall?.copyWith(color: Colors.red)),
                )
              else if (_results.isEmpty && _searchController.text.length >= 3)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No results found.', style: tt.bodySmall),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final formatted = _formatLocation(result);
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: AppTheme.primaryBlue),
                        title: Text(
                          formatted,
                          style: tt.bodySmall
                              ?.copyWith(color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          result['display'],
                          style: tt.bodySmall?.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          // Return structured data
                          final area = result['suburb'].toString().isNotEmpty
                              ? result['suburb']
                              : result['city'];
                          Navigator.pop(context, {
                            'full': formatted,
                            'area': area.toString(),
                            'state': result['state'].toString(),
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
