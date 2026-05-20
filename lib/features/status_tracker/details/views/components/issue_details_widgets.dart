import 'package:flutter/material.dart';

import '../../../../../theme/app_theme.dart';
import '../../models/issue_detail_models.dart';
import '../../viewmodels/issue_details_view_model.dart';

const double _imagePreviewRadius = 12;

// card with issue title, category, location, date, id, report image.
class IssueReportHeaderCard extends StatelessWidget {
  const IssueReportHeaderCard({super.key, required this.viewModel});

  final IssueDetailsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final issue = viewModel.issue;

    return _DetailCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ReportThumbnail(imageUrls: viewModel.reportImageUrls),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _InfoLine(
                  icon: Icons.folder_rounded,
                  iconColor: const Color(0xFFFFC978),
                  text: 'Category: ${issue.category}',
                ),
                _InfoLine(
                  icon: Icons.location_on,
                  iconColor: const Color(0xFFFF5B5B),
                  text: issue.location.displayName,
                ),
                _InfoLine(
                  icon: Icons.calendar_month,
                  iconColor: const Color(0xFF7C7C7C),
                  text: viewModel.formatFullDate(viewModel.submittedAt),
                ),
                _InfoLine(
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFF7C7C7C),
                  text: 'Issue ID: ${issue.id}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// card with status, completion proof image and date
class IssueCurrentStatusCard extends StatelessWidget {
  const IssueCurrentStatusCard({super.key, required this.viewModel});

  final IssueDetailsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final statusImageUrls = viewModel.statusImageUrls;

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: Colors.black87,
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusPill(
                        label: viewModel.issue.status.label,
                        foregroundColor: viewModel.issue.status.foregroundColor,
                        backgroundColor: viewModel.issue.status.backgroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (statusImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CardImagePreview(imageUrls: statusImageUrls, aspectRatio: 1.45),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFF6F6F6F)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateInfoBlock(
                  icon: Icons.calendar_month,
                  title: 'Last Updated',
                  value: viewModel.lastUpdatedText,
                ),
              ),
              Container(width: 1, height: 42, color: Colors.black54),
              Expanded(
                child: _DateInfoBlock(
                  icon: Icons.schedule,
                  title: 'Estimated Resolution',
                  value: viewModel.estimatedResolutionText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// progress card showing status milestones and detail timeline
class IssueProgressCard extends StatelessWidget {
  const IssueProgressCard({super.key, required this.viewModel});

  final IssueDetailsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressSteps(viewModel: viewModel),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFF6F6F6F)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Detailed Updates:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Icon(Icons.keyboard_arrow_up, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          ...viewModel.updates.map(
            (update) => _TimelineUpdate(
              update: update,
              timeText: viewModel.formatUpdateTime(update.timestamp),
            ),
          ),
        ],
      ),
    );
  }
}

// row for average resolution and similar/support count
// developing
class IssueMetricRow extends StatelessWidget {
  const IssueMetricRow({super.key, required this.viewModel});

  final IssueDetailsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.bar_chart_rounded,
            label: 'Avg. Resolution',
            value: viewModel.averageResolutionText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            icon: Icons.location_on_outlined,
            label: 'Similar Reports',
            value: viewModel.similarReportCount.toString(),
          ),
        ),
      ],
    );
  }
}

// bottom banner (resoluion status)
class IssueResolutionBanner extends StatelessWidget {
  const IssueResolutionBanner({super.key, required this.isResolved});

  final bool isResolved;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isResolved ? const Color(0xFF41D665) : const Color(0xFFD9343A),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.black,
                size: 17,
              ),
              const SizedBox(width: 5),
              Text(
                isResolved ? 'Report Is Resolved' : 'Report Still Unresolved',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// reusable card container
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

// thumbnail inside first detail card
// tap to open gallery dialog
class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final firstImageUrl = imageUrls.isEmpty ? null : imageUrls.first;

    return GestureDetector(
      onTap: imageUrls.isEmpty
          ? null
          : () => _showImageGallery(context, imageUrls: imageUrls),
      child: Container(
        width: 62,
        height: 74,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: firstImageUrl == null
            ? const Icon(
                Icons.description_outlined,
                color: Colors.black,
                size: 42,
              )
            : Image.network(
                firstImageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.description_outlined,
                    color: Colors.black,
                    size: 42,
                  );
                },
              ),
      ),
    );
  }
}

// image thumbnail for status/proof images
class _CardImagePreview extends StatelessWidget {
  const _CardImagePreview({required this.imageUrls, required this.aspectRatio});

  final List<String> imageUrls;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final firstImageUrl = imageUrls.first;

    return Center(
      child: GestureDetector(
        onTap: () => _showImageGallery(context, imageUrls: imageUrls),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_imagePreviewRadius),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Image.network(
              firstImageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                return const _ImageErrorPlaceholder();
              },
            ),
          ),
        ),
      ),
    );
  }
}

void _showImageGallery(
  BuildContext context, {
  required List<String> imageUrls,
}) {
  if (imageUrls.isEmpty) return;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close image preview',
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ImageGalleryDialog(imageUrls: imageUrls);
    },
  );
}

// gallery to display one or more images without crop
class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
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
                borderRadius: BorderRadius.circular(_imagePreviewRadius),
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
                          // show the complete image
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
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
                            style: Theme.of(context).textTheme.bodySmall
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

// handle image fail to load
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

// icon+text metadata line for the first card
class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: 11,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// status label pill
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
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foregroundColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// last-updated and estimated-resolution
class _DateInfoBlock extends StatelessWidget {
  const _DateInfoBlock({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// three-step progress row
class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.viewModel});

  final IssueDetailsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final steps = viewModel.progressSteps;

    return Column(
      children: [
        Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(
                flex: 6,
                child: _StepIcon(
                  step: steps[index],
                  dateText: viewModel.formatShortDate(steps[index].date),
                ),
              ),
              if (index < steps.length - 1)
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 1.4,
                    margin: const EdgeInsets.only(bottom: 28),
                    color: steps[index + 1].isReached
                        ? Colors.black
                        : Colors.black45,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

// single progress icon + label + date cell
class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step, required this.dateText});

  final IssueDetailProgressStep step;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          step.isReached
              ? Icons.check_circle_outline_rounded
              : Icons.radio_button_unchecked_rounded,
          color: Colors.black87,
          size: 32,
        ),
        const SizedBox(height: 5),
        Text(
          step.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black, fontSize: 10),
        ),
      ],
    );
  }
}

// detailed update timeline's row
class _TimelineUpdate extends StatelessWidget {
  const _TimelineUpdate({required this.update, required this.timeText});

  final IssueDetailUpdate update;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, color: Colors.black54, size: 8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        update.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  update.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                    fontSize: 9.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// metric tile for quick data display
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 30),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
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
