import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/main_appbar.dart';
import 'models/community_user_profile.dart';
import 'post_details_page.dart';
import 'services/community_repository.dart';
import 'vote_insight_page.dart';
import 'viewmodels/community_view_model.dart';
import 'widgets/community_issue_card.dart';

class UpvotingPage extends StatefulWidget {
  const UpvotingPage({super.key});

  @override
  State<UpvotingPage> createState() => _UpvotingPageState();
}

class _UpvotingPageState extends State<UpvotingPage> {
  late final CommunityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CommunityViewModel(repository: CommunityRepository())..start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openDetails(String issueId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailsPage(issueId: issueId)),
    );
  }

  void _openInsights() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VoteInsightPage()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: MainAppBar(
            title: 'Community',
            insight: _viewModel.isAdmin,
            onInsightTap: _viewModel.isAdmin ? _openInsights : null,
            showSearchBar: true,
            showFilter: true,
            filterList: const ['All', 'Newest', 'Most Supported', 'Complete'],
            onSearchChanged: _viewModel.updateSearchQuery,
            onFilterChanged: _viewModel.updateSortLabel,
          ),
          body: ColoredBox(
            color: AppTheme.mainBackground,
            child: _buildBody(context),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Could not load community posts.\n${_viewModel.error}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final issues = _viewModel.visibleIssues;
    if (issues.isEmpty) {
      return Center(
        child: Text(
          'No posts found.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final uid = _viewModel.currentUserId ?? '';

    return RefreshIndicator(
      onRefresh: () async => _viewModel.start(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: issues.length,
        itemBuilder: (context, index) {
          final issue = issues[index];
          final rank = _viewModel.topRankForIssue(issue.id);
          final isLiked = uid.isNotEmpty && issue.isLikedBy(uid);

          return FutureBuilder<CommunityUserProfile?>(
            future: _viewModel.profileFor(issue.reporterId),
            builder: (context, snapshot) {
              final profile = snapshot.data;

              final reporterName =
                  profile?.displayName ?? issue.reporterDisplayText;
              final reporterArea = profile?.area ?? '';
              final reporterPhoto = profile?.photoURL;

              return CommunityIssueCard(
                issue: issue,
                topRank: rank,
                isLiked: isLiked,
                reporterName: reporterName,
                reporterArea: reporterArea,
                reporterPhotoUrl: reporterPhoto,
                onTap: () => _openDetails(issue.id),
                onLikeTap: () async {
                  final err = await _viewModel.toggleLike(issue.id);
                  if (!mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err.toString())));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
