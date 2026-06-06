import 'package:flutter/material.dart';

import '../../../services/app_settings_service.dart';
import '../../../theme/app_theme.dart';
import '../models/community_issue.dart';

class CommunityIssueCard extends StatelessWidget {
  const CommunityIssueCard({
    super.key,
    required this.issue,
    required this.topRank,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
  });

  final CommunityIssue issue;
  final int? topRank; // 1..3 or null
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  static const _unlikedGrey = Color(0xFF98A2B3);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final reduceMedia = AppSettingsService.instance.shouldReduceMedia;

    final imageUrl = issue.reportImages.isEmpty
        ? null
        : issue.reportImages.first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // image area
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: const Color(0xFFE5E7EB),
                    child: (imageUrl == null || imageUrl.isEmpty || reduceMedia)
                        ? const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 56,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 56,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                  ),
                ),
                if (topRank != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '#$topRank Top',
                          style: tt.bodySmall?.copyWith(
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

            // content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category: ${issue.category.isEmpty ? 'Unknown' : issue.category}',
                    style: tt.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    issue.description.isEmpty
                        ? 'No description provided.'
                        : issue.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resident',
                        style: tt.bodySmall?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          issue.location.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: onLikeTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_up_alt_rounded,
                              size: 18,
                              color: isLiked
                                  ? AppTheme.accentBlue
                                  : _unlikedGrey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              issue.likesCount.toString(),
                              style: tt.bodySmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );
  }
}
