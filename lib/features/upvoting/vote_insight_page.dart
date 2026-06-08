import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/function_appbar.dart';
import 'services/community_repository.dart';
import 'viewmodels/vote_insight_view_model.dart';

class VoteInsightPage extends StatefulWidget {
  const VoteInsightPage({super.key});

  @override
  State<VoteInsightPage> createState() => _VoteInsightPageState();
}

class _VoteInsightPageState extends State<VoteInsightPage> {
  late final VoteInsightViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = VoteInsightViewModel(repository: CommunityRepository())
      ..start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Color _rankBg(int rank) {
    // Match the screenshot vibe: 1=pink, 2=cream, 3=lavender/blue
    return switch (rank) {
      1 => const Color(0xFFF8D7DA),
      2 => const Color(0xFFFFF3CD),
      _ => const Color(0xFFDDE7FF),
    };
  }

  Color _rankFg(int rank) {
    return switch (rank) {
      1 => const Color(0xFFB42318),
      2 => const Color(0xFF7A5C00),
      _ => const Color(0xFF1D4ED8),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: const FunctionAppBar(title: 'Priority Insight'),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.functionBackground,
            ),
            child: SafeArea(top: false, child: _buildBody(context)),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_viewModel.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Could not load insights.\n${_viewModel.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final items = _viewModel.top3Unresolved;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No unresolved issues found.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rank = index + 1;
        final item = items[index];
        final issue = item.issue;

        final title =
            'Category: ${issue.category} - ${issue.location.heading.isNotEmpty ? issue.location.heading : issue.location.postcode}';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _rankBg(rank),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 18, // bigger number
                    fontWeight: FontWeight.w900,
                    color: _rankFg(rank),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.thumb_up_alt_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Supported by ${issue.likesCount} residents',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 18,
                          color: Color(0xFF18B86B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${item.likesLastHour}/hr',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF18B86B),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
