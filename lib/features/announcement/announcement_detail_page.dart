import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_settings_service.dart';
import '../../widgets/function_appbar.dart';
import '../../widgets/chatbox.dart';
import '../../theme/app_theme.dart';
import 'colours.dart';
import 'edit_announcement_page.dart';

class AnnouncementDetailPage extends StatefulWidget {
  final String docId;

  const AnnouncementDetailPage({super.key, required this.docId});

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _userRole = doc.data()?['role'] ?? 'user';
      });
    }
  }

  bool get _isAdmin => _userRole == 'admin';

  Future<void> _deleteAnnouncement() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text(
          'Are you sure you want to delete this announcement?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(widget.docId)
          .update({'isDeleted': true});

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FunctionAppBar(
        title: 'Announcement',
        showHistory: _isAdmin,
        onHistoryTap: _isAdmin ? () => _showAdminMenu(context) : null,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.mainBackground,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .doc(widget.docId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Announcement not found.'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final title = data['title'] ?? '';
            final caption = data['caption'] ?? '';
            final color = data['colour'] ?? 'green';
            final createdAt = data['createdAt'] as Timestamp?;
            final attachments = (data['attachments'] as List<dynamic>?) ?? [];

            // Read nested target fields
            final target = data['target'] as Map<String, dynamic>? ?? {};
            final audience = target['audience'] ?? 'all';
            final location = target['location'] as Map<String, dynamic>? ?? {};
            final area = location['area'] ?? 'Ayer Itam';
            final postcode = location['postcode']?.toString() ?? '';

            final formattedDate = createdAt != null
                ? '${DateFormat('d MMMM yyyy').format(createdAt.toDate())}, ${DateFormat('h.mm').format(createdAt.toDate())}${DateFormat('a').format(createdAt.toDate()).toLowerCase().replaceAll('am', 'a.m.').replaceAll('pm', 'p.m.')}'
                : '';

            final locationStr = postcode.isNotEmpty ? '$area, $postcode' : area;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Announcement card ──
                        _DetailCard(
                          title: title,
                          caption: caption,
                          color: color,
                          audience: audience,
                          location: locationStr,
                          formattedDate: formattedDate,
                        ),

                        // ── Attachments ──
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _AttachmentsSection(attachments: attachments),
                        ],

                        const SizedBox(height: 24),

                        // ── Comments section ──
                        Text('Comments', style: tt.titleLarge),
                        const SizedBox(height: 12),
                        _CommentsSection(docId: widget.docId),
                      ],
                    ),
                  ),
                ),

                // ── Comment input ──
                ChatBox(
                  hintText: 'Comment Something..',
                  onSend: (message) => _postComment(context, message),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.primaryBlue),
                title: const Text('Edit Announcement'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAnnouncementPage(docId: widget.docId),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Announcement',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteAnnouncement();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _postComment(BuildContext context, String message) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment.')),
      );
      return;
    }

    FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.docId)
        .collection('comments')
        .add({
          'text': message,
          'userId': user.uid,
          'userName': user.displayName ?? 'Anonymous',
          'userPhoto': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Card
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final String title;
  final String caption;
  final String color;
  final String audience;
  final String location;
  final String formattedDate;

  const _DetailCard({
    required this.title,
    required this.caption,
    required this.color,
    required this.audience,
    required this.location,
    required this.formattedDate,
  });

  Color get _cardColor => AnnouncementColours.get(color).background;

  Color get _borderColor => AnnouncementColours.get(color).border;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (formattedDate.isNotEmpty)
            Text(
              formattedDate,
              style: tt.bodySmall?.copyWith(
                color: _borderColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 8),
          Text(title, style: tt.titleLarge),
          const SizedBox(height: 8),
          Text(caption, style: tt.bodyLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          Text(
            '${_capitalizeFirst(audience)} ~ $location',
            style: tt.bodySmall?.copyWith(
              color: _borderColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments Section
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  final String docId;

  const _CommentsSection({required this.docId});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .doc(docId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data?.docs ?? [];

        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No comments yet. Be the first to comment!',
              style: tt.bodySmall,
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            return _CommentTile(
              userName: comment['userName'] ?? 'Anonymous',
              userPhoto: comment['userPhoto'] ?? '',
              text: comment['text'] ?? '',
              createdAt: comment['createdAt'] as Timestamp?,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comment Tile
// ─────────────────────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final String userName;
  final String userPhoto;
  final String text;
  final Timestamp? createdAt;

  const _CommentTile({
    required this.userName,
    required this.userPhoto,
    required this.text,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: userPhoto.isNotEmpty
              ? NetworkImage(userPhoto)
              : null,
          backgroundColor: AppTheme.surfaceGrey,
          child: userPhoto.isEmpty
              ? const Icon(Icons.person, color: AppTheme.textSecondary)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: tt.bodySmall?.copyWith(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachments Section
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentsSection extends StatelessWidget {
  final List<dynamic> attachments;

  const _AttachmentsSection({required this.attachments});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final reduceMedia = AppSettingsService.instance.shouldReduceMedia;

    // Separate by type
    final images = attachments
        .where((a) => (a as Map)['type'] == 'image')
        .toList();
    final videos = attachments
        .where((a) => (a as Map)['type'] == 'video')
        .toList();
    final docs = attachments
        .where((a) => (a as Map)['type'] == 'document')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Images ──
        if (images.isNotEmpty) ...[
          Text(
            'Images',
            style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final img = images[index] as Map;
                final url = img['url'] ?? '';
                return GestureDetector(
                  onTap: () => _openUrl(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: reduceMedia
                        ? const _ReducedAttachmentPreview()
                        : Image.network(
                            url,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 120,
                              height: 120,
                              color: AppTheme.surfaceGrey,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Videos ──
        if (videos.isNotEmpty) ...[
          Text(
            'Videos',
            style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...videos.map((v) {
            final video = v as Map;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _openUrl(video['url'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video['name'] ?? 'Video',
                          style: tt.bodySmall?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: AppTheme.accentBlue,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],

        // ── Documents ──
        if (docs.isNotEmpty) ...[
          Text(
            'Documents',
            style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...docs.map((d) {
            final doc = d as Map;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _openUrl(doc['url'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc['name'] ?? 'Document',
                          style: tt.bodySmall?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: AppTheme.accentBlue,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ReducedAttachmentPreview extends StatelessWidget {
  const _ReducedAttachmentPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 120,
      height: 120,
      child: ColoredBox(
        color: AppTheme.surfaceGrey,
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
