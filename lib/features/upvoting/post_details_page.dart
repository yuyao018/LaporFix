import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_theme.dart';
import '../../widgets/chatbox.dart';
import '../../widgets/function_appbar.dart';
import 'models/community_issue.dart';
import 'models/community_user_profile.dart';
import 'services/community_repository.dart';
import 'utils/community_name_formatter.dart';
import 'viewmodels/post_details_view_model.dart';
import 'package:group2_urbanfix/features/status_tracker/summary/models/issue_completion_proof.dart';
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
        return FutureBuilder<CommunityUserProfile?>(
          future: issue == null
              ? Future.value(null)
              : _viewModel.profileFor(issue.reporterId),
          builder: (context, profileSnap) {
            final reporterProfile = profileSnap.data;
            final maskTitle =
                issue != null &&
                reporterProfile?.profileVisibleToCommunity == true;
            final title = communityNameForDisplay(
              reporterProfile?.displayName ?? issue?.reporterDisplayText,
              maskName: maskTitle,
            );

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
                      bottom: false,
                      child: _buildBody(issueSnap),
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

    // Use formatted location (includes area and state)
    final reportLocation = issue.location.formattedLocation;

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
                              reportLocation.isNotEmpty
                                  ? reportLocation
                                  : 'Location unavailable',
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

                // Completion proof card — pinned above comments when present
                if (issue.completionProof != null &&
                    issue.completionProof!.hasContent)
                  _CompletionProofCard(proof: issue.completionProof!),

                if (comments.isEmpty &&
                    (issue.completionProof == null ||
                        !issue.completionProof!.hasContent))
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else if (comments.isEmpty)
                  const SizedBox.shrink()
                else
                  for (final c in comments)
                    FutureBuilder(
                      future: _viewModel.profileFor(c.userId),
                      builder: (context, snap) {
                        final profile = snap.data;
                        final maskUserName =
                            profile?.profileVisibleToCommunity == true;
                        return CommentTile(
                          comment: c,
                          isLiked: uid.isNotEmpty && c.isLikedBy(uid),
                          photoUrl: profile?.photoURL,
                          overrideUserName: profile?.displayName,
                          maskUserName: maskUserName,
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

// ── Completion Proof Card ─────────────────────────────────────────────────────
// Pinned at the top of the comments section when an admin has uploaded proof.
class _CompletionProofCard extends StatelessWidget {
  const _CompletionProofCard({required this.proof});

  final IssueCompletionProof proof;

  static const _green = Color(0xFF16A34A);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _greenBorder = Color(0xFF86EFAC);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dateText = proof.completedAt != null
        ? DateFormat('d MMM yyyy').format(proof.completedAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _greenBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Issue Resolved',
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (dateText.isNotEmpty)
                  Text(
                    dateText,
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proof images
                if (proof.proofImages.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 180,
                      child: proof.proofImages.length == 1
                          ? GestureDetector(
                              onTap: () => _showImageGallery(
                                context,
                                proof.proofImages,
                              ),
                              child: Image.network(
                                proof.proofImages.first,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _imagePlaceholder(),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: proof.proofImages.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () => _showImageGallery(
                                  context,
                                  proof.proofImages,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    proof.proofImages[i],
                                    width: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _imagePlaceholder(width: 200),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Description
                if (proof.description.isNotEmpty)
                  Text(
                    proof.description,
                    style: tt.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                // Completed-by line
                if (proof.completedBy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 14,
                        color: _green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved by Admin',
                        style: tt.bodySmall?.copyWith(
                          color: _green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: _green,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder({double? width}) => Container(
    width: width,
    color: const Color(0xFFE5E7EB),
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
    ),
  );
}

void _showImageGallery(BuildContext context, List<String> imageUrls) {
  if (imageUrls.isEmpty) return;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close image preview',
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _PostImageGalleryDialog(imageUrls: imageUrls);
    },
  );
}

class _PostImageGalleryDialog extends StatefulWidget {
  const _PostImageGalleryDialog({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_PostImageGalleryDialog> createState() =>
      _PostImageGalleryDialogState();
}

class _PostImageGalleryDialogState extends State<_PostImageGalleryDialog> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close image preview',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.imageUrls.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.imageUrls[index],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const _ImageErrorPlaceholder();
                          },
                        );
                      },
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.imageUrls.length}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.surfaceGrey,
      child: Center(
        child: Icon(Icons.broken_image, color: AppTheme.textSecondary),
      ),
    );
  }
}
