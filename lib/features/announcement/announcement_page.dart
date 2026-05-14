import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/main_appbar.dart';
import '../../theme/app_theme.dart';
import 'announcement_detail_page.dart';
import 'create_announcement_page.dart';
import 'colours.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  String _searchQuery = '';
  String _userRole = 'user';
  String _userLocation = '';
  String _userArea = '';
  String _userState = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Retry a few times in case the user doc hasn't been written yet (e.g. right after signup)
    for (int i = 0; i < 3; i++) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'user';
          _userLocation = doc.data()?['homeAddress'] ?? '';
          _userArea = doc.data()?['area'] ?? '';
          _userState = doc.data()?['state'] ?? '';
        });
        return;
      }

      // Wait before retrying
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  bool get _isAdmin => _userRole == 'admin';

  /// Filter announcements by user's home location and search query.
  /// By default, only shows announcements matching the user's area/state.
  /// When searching, matches against title, caption, AND location fields.
  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isDeleted = data['isDeleted'] ?? false;
      if (isDeleted == true) return false;

      // Extract announcement location
      final target = data['target'] as Map<String, dynamic>? ?? {};
      final location = target['location'] as Map<String, dynamic>? ?? {};
      final announcementArea = (location['area'] ?? '').toString().toLowerCase();
      final announcementCity = (location['city'] ?? '').toString().toLowerCase();
      final announcementState = (location['state'] ?? '').toString().toLowerCase();
      final announcementFull = (location['full'] ?? '').toString().toLowerCase();

      // If user is searching, filter by search query across all fields
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final caption = (data['caption'] ?? '').toString().toLowerCase();

        return title.contains(query) ||
            caption.contains(query) ||
            announcementArea.contains(query) ||
            announcementCity.contains(query) ||
            announcementState.contains(query) ||
            announcementFull.contains(query);
      }

      // Default: filter by user's home location
      // Only show announcements that match the user's specific area/suburb
      if (_userArea.isEmpty && _userState.isEmpty) return true; // no location set, show all

      final userArea = _userArea.toLowerCase();

      // Strict match: announcement area must match user's area
      if (userArea.isNotEmpty) {
        if (announcementArea == userArea) return true;
        if (announcementFull.contains(userArea)) return true;
      }

      return false;
    }).toList();
  }

  /// Derive the display location from the current search or user's home address.
  /// Standardizes to show only suburb/city + state.
  String _getDisplayLocation(List<QueryDocumentSnapshot> filteredDocs) {
    // If user is searching, show the location from the first matching doc
    if (_searchQuery.isNotEmpty && filteredDocs.isNotEmpty) {
      final data = filteredDocs.first.data() as Map<String, dynamic>;
      final target = data['target'] as Map<String, dynamic>? ?? {};
      final location = target['location'] as Map<String, dynamic>? ?? {};
      return _formatShortLocation(location);
    }

    // Default: show user's home address (standardized)
    if (_userLocation.isNotEmpty) {
      return _standardizeAddress(_userLocation);
    }
    return 'All Locations';
  }

  /// Format location map to "Area, State" or "City, State"
  String _formatShortLocation(Map<String, dynamic> location) {
    final area = (location['area'] ?? '').toString();
    final city = (location['city'] ?? '').toString();
    final state = (location['state'] ?? '').toString();
    final full = (location['full'] ?? '').toString();

    // Prefer area + state
    if (area.isNotEmpty && state.isNotEmpty) return '$area, $state';
    if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
    if (area.isNotEmpty) return area;
    // Fallback: standardize the full string
    if (full.isNotEmpty) return _standardizeAddress(full);
    return 'Unknown';
  }

  /// Extract suburb/city + state from a free-form address string.
  /// e.g. "Jalan 123, Taman Indah, Ayer Itam, Penang" → "Ayer Itam, Penang"
  String _standardizeAddress(String address) {
    final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      // Take the last two parts (usually suburb/city and state)
      return parts.sublist(parts.length - 2).join(', ');
    }
    return parts.isNotEmpty ? parts.last : address;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Announcement',
        showSearchBar: true,
        showFilter: false,
        onSearchChanged: (q) => setState(() => _searchQuery = q),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final filtered = _filterDocs(docs);
          final displayLocation = _getDisplayLocation(filtered);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Location row ──
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    const Text('📌', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayLocation,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Announcement list ──
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No announcements found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return _AnnouncementCard(
                            docId: doc.id,
                            title: data['title'] ?? '',
                            caption: data['caption'] ?? '',
                            color: data['colour'] ?? 'green',
                            hasAttachments: (data['attachments'] as List?)?.isNotEmpty ?? false,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // ── FAB for admin to create new post ──
      floatingActionButton: _isAdmin
          ? Container(
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateAnnouncementPage(),
                    ),
                  );
                },
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcement Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final String docId;
  final String title;
  final String caption;
  final String color;
  final bool hasAttachments;

  const _AnnouncementCard({
    required this.docId,
    required this.title,
    required this.caption,
    required this.color,
    this.hasAttachments = false,
  });

  Color get _cardColor => AnnouncementColours.get(color).background;

  Color get _borderColor => AnnouncementColours.get(color).border;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnnouncementDetailPage(docId: docId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: tt.bodySmall?.copyWith(color: AppTheme.textPrimary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasAttachments) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_file, size: 14, color: _borderColor),
                  const SizedBox(width: 4),
                  Text(
                    'Attachments',
                    style: tt.bodySmall?.copyWith(
                      fontSize: 12,
                      color: _borderColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
