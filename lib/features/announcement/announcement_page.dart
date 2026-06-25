import 'package:flutter/material.dart';
import '../../widgets/main_appbar.dart';
import '../../theme/app_theme.dart';
import 'announcement_detail_page.dart';
import 'create_announcement_page.dart';
import 'colours.dart';
import 'models/announcement.dart';
import 'viewmodels/announcement_view_model.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  late final AnnouncementViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AnnouncementViewModel();
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: MainAppBar(
            title: 'Announcement',
            showSearchBar: true,
            showFilter: false,
            onSearchChanged: (q) => _viewModel.setSearchQuery(q),
          ),
          body: StreamBuilder<List<Announcement>>(
            stream: _viewModel.watchAnnouncements(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allAnnouncements = snapshot.data ?? [];
              final filtered = _viewModel.filterAnnouncements(allAnnouncements);
              final splitData = _viewModel.splitByDate(filtered);
              final upcoming = splitData['upcoming'] ?? [];
              final past = splitData['past'] ?? [];
              final displayLocation = _viewModel.getDisplayLocation(filtered);

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
                    child: (upcoming.isEmpty && past.isEmpty)
                        ? const Center(child: Text('No announcements found.'))
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                              if (upcoming.isNotEmpty) ...[
                                _SectionHeader(title: 'Upcoming'),
                                ...upcoming.map((announcement) {
                                  return _AnnouncementCard(
                                    announcement: announcement,
                                  );
                                }),
                              ],
                              if (past.isNotEmpty) ...[
                                _SectionHeader(title: 'Past Announcements'),
                                ...past.map((announcement) {
                                  return _AnnouncementCard(
                                    announcement: announcement,
                                    isPast: true,
                                  );
                                }),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
          ),

          // ── FAB for admin to create new post ──
          floatingActionButton: _viewModel.isAdmin
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
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcement Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isPast;

  const _AnnouncementCard({
    required this.announcement,
    this.isPast = false,
  });

  Color get _cardColor =>
      AnnouncementColours.get(announcement.colour).background;

  Color get _borderColor => AnnouncementColours.get(announcement.colour).border;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Opacity(
      opacity: isPast ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementDetailPage(docId: announcement.id),
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
                announcement.title,
                style: tt.titleLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                announcement.caption,
                style: tt.bodySmall?.copyWith(color: AppTheme.textPrimary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (announcement.attachments.isNotEmpty) ...[
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
      ),
    );
  }
}
