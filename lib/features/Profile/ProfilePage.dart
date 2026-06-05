import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/function_appbar.dart';
import '../../theme/app_theme.dart';
import 'app_settings_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBack;

  const ProfilePage({super.key, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _userData = doc.data();
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile_picture.jpg');

      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': url},
      );

      // Update Firebase Auth profile
      await user.updatePhotoURL(url);

      // Refresh local data
      if (mounted) {
        setState(() {
          _userData?['photoURL'] = url;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      }
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AppSettingsPage(),
      ),
    );
  }

  PreferredSizeWidget _buildProfileAppBar() {
    return FunctionAppBar(
      title: 'My Profile',
      onBack: widget.onBack,
      trailingAction: IconButton(
        tooltip: 'App settings',
        icon: const Icon(Icons.settings_rounded, color: Colors.black, size: 28),
        onPressed: _openSettings,
      ),
    );
  }

  String _extractShortLocation(String address) {
    if (address.isEmpty) return 'Malaysia';
    final parts = address
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return parts.sublist(parts.length - 2).join(', ');
    }
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: _buildProfileAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final username = _userData?['username'] ?? user?.displayName ?? 'User';
    final email = _userData?['email'] ?? user?.email ?? '';
    final address = _userData?['homeAddress'] ?? '';
    final role = _userData?['role'] ?? 'user';
    final uid = user?.uid ?? '';
    final photoURL = _userData?['photoURL'] ?? user?.photoURL ?? '';

    return Scaffold(
      appBar: _buildProfileAppBar(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Top gradient section (avatar, name, stats) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar
                    GestureDetector(
                      onTap: _changeProfilePicture,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFE0E0E0),
                              backgroundImage: photoURL.isNotEmpty
                                  ? NetworkImage(photoURL)
                                  : null,
                              child: photoURL.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 45,
                                      color: AppTheme.primaryBlue,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Username
                    Text(
                      username,
                      style: tt.titleLarge?.copyWith(
                        color: AppTheme.textOnGradient,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Role & Location
                    Text(
                      '${role == 'admin' ? 'Admin' : 'Active Resident'}  •  ${_extractShortLocation(address)}',
                      style: tt.bodySmall?.copyWith(
                        color: AppTheme.textOnGradient.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _StatBox(count: '0', label: 'Posts'),
                        SizedBox(width: 16),
                        _StatBox(count: '0', label: 'Likes given'),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Personal Details section (white card) ──
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Details',
                      style: tt.titleLarge?.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _DetailRow(
                      label: 'LaporFix ID',
                      value: '#${uid.length > 9 ? uid.substring(0, 9) : uid}',
                    ),
                    const Divider(height: 1),
                    _DetailRow(label: 'Email', value: email),
                    const Divider(height: 1),
                    _DetailRow(
                      label: 'Password',
                      value: '••••••••••',
                      actionText: 'Change Password',
                      onAction: _changePassword,
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      label: 'Address',
                      value: address.isNotEmpty ? address : 'Not set',
                      actionText: 'Change',
                      onAction: () {},
                    ),

                    const SizedBox(height: 28),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Log Out',
                          style: tt.labelLarge?.copyWith(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Box Widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String count;
  final String label;

  const _StatBox({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(count, style: tt.titleLarge?.copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Row Widget
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String? actionText;
  final VoidCallback? onAction;

  const _DetailRow({
    required this.label,
    required this.value,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(value, style: tt.bodyLarge?.copyWith(fontSize: 16)),
              ),
              if (actionText != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionText!,
                    style: tt.bodySmall?.copyWith(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
