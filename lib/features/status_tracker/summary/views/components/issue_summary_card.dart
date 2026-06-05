import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../services/app_settings_service.dart';
import '../../../../../theme/app_theme.dart';
import '../../models/issue_summary.dart';

// Card for one issue summary.
class IssueSummaryCard extends StatelessWidget {
  const IssueSummaryCard({super.key, required this.issue, required this.onTap});

  final IssueSummary issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ReportImagePreview(
                imageUrl: issue.reportImages.isEmpty
                    ? null
                    : issue.reportImages.first,
                fallbackColor: issue.status.foregroundColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            issue.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: issue.status.label,
                          foregroundColor: issue.status.foregroundColor,
                          backgroundColor: issue.status.backgroundColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _MetaRow(
                      icon: Icons.location_on,
                      iconColor: const Color(0xFFFF5B5B),
                      text: issue.location.displayName,
                    ),
                    _MetaRow(
                      icon: Icons.calendar_month,
                      iconColor: const Color(0xFF7C7C7C),
                      text: _formatDate(issue.latestStatusChangedAt),
                    ),
                    _MetaRow(
                      icon: Icons.receipt_long,
                      iconColor: const Color(0xFF7C7C7C),
                      text: 'Issue ID: ${issue.id}',
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _CountBadge(
                          icon: Icons.thumb_up_alt_rounded,
                          value: issue.engagement.likesCount,
                        ),
                        const SizedBox(width: 12),
                        _CountBadge(
                          icon: Icons.comment_rounded,
                          value: issue.engagement.commentCount,
                        ),
                      ],
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';
    return DateFormat('d MMMM yyyy').format(date);
  }
}

// Thumbnail used at the left.
class _ReportImagePreview extends StatefulWidget {
  const _ReportImagePreview({
    required this.imageUrl,
    required this.fallbackColor,
  });

  final String? imageUrl;
  final Color fallbackColor;

  @override
  State<_ReportImagePreview> createState() => _ReportImagePreviewState();
}

class _ReportImagePreviewState extends State<_ReportImagePreview> {
  OverlayEntry? _previewOverlay;

  @override
  void dispose() {
    _hideExpandedPreview();
    super.dispose();
  }

  void _showExpandedPreview() {
    final imageUrl = widget.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty || _previewOverlay != null) {
      return;
    }

    _previewOverlay = OverlayEntry(
      builder: (context) => _ExpandedReportImagePreview(imageUrl: imageUrl),
    );

    Overlay.of(context).insert(_previewOverlay!);
  }

  void _hideExpandedPreview() {
    _previewOverlay?.remove();
    _previewOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final trimmedImageUrl = widget.imageUrl?.trim();

    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        final reduceMedia = AppSettingsService.instance.shouldReduceMedia;

        return MouseRegion(
          onHover: (_) {
            if (!reduceMedia) _showExpandedPreview();
          },
          onExit: (_) => _hideExpandedPreview(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              if (!reduceMedia) _showExpandedPreview();
            },
            onTapUp: (_) => _hideExpandedPreview(),
            onTapCancel: _hideExpandedPreview,
            onTap: _hideExpandedPreview,
            child: Container(
              width: 62,
              height: 74,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child:
                  trimmedImageUrl == null ||
                      trimmedImageUrl.isEmpty ||
                      reduceMedia
                  ? _FallbackDocumentIcon(color: widget.fallbackColor)
                  : Image.network(
                      trimmedImageUrl,
                      width: 62,
                      height: 74,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: progress.expectedTotalBytes == null
                                  ? null
                                  : progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          _FallbackDocumentIcon(color: widget.fallbackColor),
                    ),
            ),
          ),
        );
      },
    );
  }
}

// Full page preview while thumbnail is hovered.
class _ExpandedReportImagePreview extends StatelessWidget {
  const _ExpandedReportImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Material(
          color: Colors.black.withValues(alpha: 0.78),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.8,
              heightFactor: 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return ColoredBox(
                        color: Colors.black.withValues(alpha: 0.18),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes == null
                                ? null
                                : progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: Colors.black.withValues(alpha: 0.18),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fallback when an issue has no report image or fails to load.
class _FallbackDocumentIcon extends StatelessWidget {
  const _FallbackDocumentIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.description_outlined, color: color, size: 48),
    );
  }
}

// Reusable status pill.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 94),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// Icon and text row inside the card.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Row of engagement counts.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF344054)),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
