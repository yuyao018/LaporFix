import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_theme.dart';
import '../../widgets/chatbox.dart';
import '../../widgets/function_appbar.dart';
import 'models/community_issue.dart';
import 'services/community_repository.dart';
import 'viewmodels/post_details_view_model.dart';
import 'widgets/comment_tile.dart';
import 'widgets/image_carousel.dart';

class PostDetailsPage extends StatefulWidget {
  const PostDetailsPage({super.key, required this.issueId});

  final String issueId;

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  late final CommunityRepository _repository;
  late final PostDetailsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _repository = CommunityRepository();
    _viewModel = PostDetailsViewModel(repository: _repository);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showCommentPostedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.accentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Comment posted',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CommunityIssue>(
      stream: _repository.watchIssue(widget.issueId),
      builder: (context, issueSnap) {
        final issue = issueSnap.data;

        // AppBar title requirement: reporter username
        return FutureBuilder(
          future: issue == null
              ? Future.value(null)
              : _viewModel.profileFor(issue.reporterId),
          builder: (context, profileSnap) {
            final reporterProfile = profileSnap.data;
            final title =
                reporterProfile?.displayName ??
                issue?.reporterDisplayText ??
                'Resident';

            return AnimatedBuilder(
              animation: _viewModel,
              builder: (context, _) {
                return Scaffold(
                  appBar: FunctionAppBar(title: title),
                  body: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.functionBackground,
                    ),
                    child: SafeArea(
                      top: false,
                      child: _buildBody(issueSnap, reporterProfile?.area ?? ''),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<CommunityIssue> snapshot,
    String reporterArea,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return const Center(
        child: Text(
          'Could not load post.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final issue = snapshot.data!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLiked = uid.isNotEmpty && issue.isLikedBy(uid);

    final dateText = issue.createdAt == null
        ? ''
        : DateFormat('d MMM yyyy').format(issue.createdAt!);

    // REQUIREMENT: post location should be area like Bayan Lepas / Ayer Itam
    final displayArea = reporterArea.trim().isNotEmpty
        ? reporterArea.trim()
        : '';

    final comments = _viewModel.sortComments(issue.community.comments);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImageCarousel(imageUrls: issue.reportImages),
                      const SizedBox(height: 12),
                      Text(
                        'Category: ${issue.category.isEmpty ? 'Unknown' : issue.category}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        issue.description.isEmpty
                            ? 'No description provided.'
                            : issue.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (dateText.isNotEmpty) ...[
                            Text(
                              dateText,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                          ],
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              displayArea.isNotEmpty
                                  ? displayArea
                                  : 'Location unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);

                              final err = await _viewModel.toggleIssueLike(
                                issue.id,
                              );
                              if (!mounted) return;
                              if (err != null) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(err.toString())),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.thumb_up_alt_rounded,
                                  size: 18,
                                  color: isLiked
                                      ? AppTheme.accentBlue
                                      : const Color(0xFF98A2B3),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  issue.likesCount.toString(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Comments header + count + filter
                Row(
                  children: [
                    Text(
                      'Comments (${issue.commentsCount})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Sort comments',
                      onSelected: _viewModel.updateCommentSort,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'Newest', child: Text('Newest')),
                        PopupMenuItem(
                          value: 'Most Supported',
                          child: Text('Most Supported'),
                        ),
                      ],
                      child: const Icon(
                        Icons.filter_list_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else
                  for (final c in comments)
                    FutureBuilder(
                      future: _viewModel.profileFor(c.userId),
                      builder: (context, snap) {
                        final profile = snap.data;
                        return CommentTile(
                          comment: c,
                          isLiked: uid.isNotEmpty && c.isLikedBy(uid),
                          photoUrl: profile?.photoURL,
                          overrideUserName: profile?.displayName,
                          overrideArea:
                              profile?.area, // REQUIREMENT: from users.area
                          onLikeTap: () async {
                            final messenger = ScaffoldMessenger.of(context);

                            if (uid.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please sign in to like comments.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final err = await _viewModel.toggleCommentLike(
                              issueId: issue.id,
                              comment: c,
                            );
                            if (!mounted) return;
                            if (err != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(err.toString())),
                              );
                            }
                          },
                        );
                      },
                    ),
              ],
            ),
          ),
        ),

        // Comment input
        ChatBox(
          hintText: 'Comment Something..',
          onSend: (msg) async {
            final messenger = ScaffoldMessenger.of(context);
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Please sign in to comment.')),
              );
              return;
            }

            final err = await _viewModel.sendComment(issue.id, msg);
            if (!mounted) return;
            if (err != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(err.toString())));
              return;
            }
            _showCommentPostedSnack();
          },
        ),
      ],
    );
  }
}
