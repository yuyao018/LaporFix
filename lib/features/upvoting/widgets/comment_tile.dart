import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../models/community_comment.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.isLiked,
    required this.onLikeTap,
  });

  final CommunityComment comment;
  final bool isLiked;
  final VoidCallback onLikeTap;

  static const _unlikedGrey = Color(0xFF98A2B3);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final dateText = comment.timestamp == null
        ? ''
        : DateFormat('d MMM yyyy').format(comment.timestamp!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: comment.isAdmin
                ? const Color(0xFFE8ECFF)
                : AppTheme.surfaceGrey,
            child: Icon(
              comment.isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: comment.isAdmin
                  ? AppTheme.primaryBlue
                  : AppTheme.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: comment.isAdmin
                      ? AppTheme.primaryBlue.withValues(alpha: 0.25)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.userName.isEmpty
                              ? (comment.isAdmin ? 'Admin' : 'User')
                              : comment.userName,
                          style: tt.bodySmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onLikeTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_up_alt_rounded,
                              size: 16,
                              color: isLiked
                                  ? AppTheme.accentBlue
                                  : _unlikedGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              comment.likesCount.toString(),
                              style: tt.bodySmall?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Text(
                    comment.comment,
                    style: tt.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      if (dateText.isNotEmpty) ...[
                        Text(
                          dateText,
                          style: tt.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (comment.userLocation.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            comment.userLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                      if (comment.isAdmin) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: AppTheme.primaryBlue,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
