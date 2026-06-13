import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../theme/app_theme.dart';
import '../../../summary/models/issue_status.dart';
import '../../models/proof_attachment.dart';
import '../../viewmodels/update_issue_view_model.dart';

// form card for choosing the next issue status
//
// renders current issue context, binds status dropdown to the ViewModel draft
class UpdateIssueCard extends StatelessWidget {
  const UpdateIssueCard({super.key, required this.viewModel});

  final UpdateIssueViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final issue = viewModel.issue;

    return _UpdateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_rounded,
                color: Color(0xFFFFC978),
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Category: ${issue.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReportImagePanel(imageUrl: viewModel.reportImageUrl),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.submittedDateText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              const Icon(Icons.location_on, color: Color(0xFFFF5B5B), size: 12),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  issue.location.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel(text: 'Description'),
          const SizedBox(height: 6),
          _ReadOnlyTextPanel(
            text: issue.description.isEmpty
                ? 'No description provided.'
                : issue.description,
          ),
          const SizedBox(height: 12),
          _SectionLabel(text: 'Update Status'),
          const SizedBox(height: 6),
          _StatusDropdown(viewModel: viewModel),
          if (viewModel.draft.selectedStatus == IssueStatus.inProgress) ...[
            const SizedBox(height: 12),
            _SectionLabel(text: 'Estimated Resolution'),
            const SizedBox(height: 6),
            _EstimatedResolutionPicker(viewModel: viewModel),
          ],
        ],
      ),
    );
  }
}

// form card for proof files and comment
class CompletionProofCard extends StatelessWidget {
  const CompletionProofCard({
    super.key,
    required this.viewModel,
    required this.onAddImage,
    required this.onAddVideo,
    required this.onRemoveProof,
  });

  final UpdateIssueViewModel viewModel;
  final VoidCallback onAddImage;
  final VoidCallback onAddVideo;
  final ValueChanged<int> onRemoveProof;

  @override
  Widget build(BuildContext context) {
    return _UpdateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProofImagePanel(
            viewModel: viewModel,
            onAddImage: onAddImage,
            onAddVideo: onAddVideo,
            onRemoveProof: onRemoveProof,
          ),
          const SizedBox(height: 14),
          _SectionLabel(text: 'Add Description'),
          const SizedBox(height: 6),
          TextField(
            minLines: 6,
            maxLines: 6,
            onChanged: viewModel.updateProofDescription,
            decoration: InputDecoration(
              hintText: 'Add a description text...',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFE8F2F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// action button shared by both update screens
class UpdateIssuePrimaryButton extends StatelessWidget {
  const UpdateIssuePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF315DFF),
          disabledBackgroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// success confirmation card displayed after update saved
class UpdateSuccessCard extends StatelessWidget {
  const UpdateSuccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: 238,
        height: 142,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF08A516), size: 42),
            const SizedBox(height: 14),
            Text(
              'Status Updated!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// white rounded panel used by update cards.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBFF).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

// image preview for the issue completion before upload
class _ReportImagePanel extends StatelessWidget {
  const _ReportImagePanel({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.78,
        child: ColoredBox(
          color: const Color(0xFFDDE2E8),
          child: url == null || url.isEmpty
              ? const Icon(
                  Icons.photo_camera_outlined,
                  color: Color(0xFF8F9398),
                  size: 56,
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.photo_camera_outlined,
                      color: Color(0xFF8F9398),
                      size: 56,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// Proof upload area
class _ProofImagePanel extends StatelessWidget {
  const _ProofImagePanel({
    required this.viewModel,
    required this.onAddImage,
    required this.onAddVideo,
    required this.onRemoveProof,
  });

  final UpdateIssueViewModel viewModel;
  final VoidCallback onAddImage;
  final VoidCallback onAddVideo;
  final ValueChanged<int> onRemoveProof;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.55,
        child: ColoredBox(
          color: const Color(0xFFDDE2E8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: viewModel.draft.proofAttachments.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.photo_camera_outlined,
                            color: Color(0xFF8F9398),
                            size: 58,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: viewModel.draft.proofAttachments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final attachment =
                                viewModel.draft.proofAttachments[index];

                            return _ProofAttachmentTile(
                              attachment: attachment,
                              onRemove: () => onRemoveProof(index),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ProofPickerButton(
                        label: 'Add Image',
                        icon: Icons.image_outlined,
                        onPressed: viewModel.canAddProof ? onAddImage : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProofPickerButton(
                        label: 'Add Video',
                        icon: Icons.videocam_outlined,
                        onPressed: viewModel.canAddProof ? onAddVideo : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${viewModel.draft.proofAttachments.length}/5 proof files selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// image/video proof picker button
class _ProofPickerButton extends StatelessWidget {
  const _ProofPickerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF315DFF),
          disabledBackgroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

// selected proof file with remove action
class _ProofAttachmentTile extends StatelessWidget {
  const _ProofAttachmentTile({
    required this.attachment,
    required this.onRemove,
  });

  final ProofAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = attachment.type == ProofAttachmentType.video;

    return SizedBox(
      width: 118,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F5),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: isVideo
                    ? _SelectedVideoPreview(fileName: attachment.name)
                    : _SelectedImagePreview(
                        file: attachment.file,
                        fileName: attachment.name,
                      ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.white,
                child: Icon(Icons.close, color: Colors.red, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.file, required this.fileName});

  final File file;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF667085),
                size: 30,
              ),
            );
          },
        ),
        _AttachmentNameOverlay(fileName: fileName),
      ],
    );
  }
}

class _SelectedVideoPreview extends StatelessWidget {
  const _SelectedVideoPreview({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF1F2937)),
        Center(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFF1F2937),
              size: 30,
            ),
          ),
        ),
        const Positioned(
          left: 8,
          top: 8,
          child: Icon(Icons.videocam_outlined, color: Colors.white, size: 18),
        ),
        _AttachmentNameOverlay(fileName: fileName),
      ],
    );
  }
}

class _AttachmentNameOverlay extends StatelessWidget {
  const _AttachmentNameOverlay({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
          ),
        ),
        child: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// read-only existing issue details
class _ReadOnlyTextPanel extends StatelessWidget {
  const _ReadOnlyTextPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.black87,
          fontSize: 12,
          height: 1.25,
        ),
      ),
    );
  }
}

// dropdown to UpdateIssueViewModel.selectedStatus.
class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.viewModel});

  final UpdateIssueViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<IssueStatus>(
      initialValue: viewModel.draft.selectedStatus,
      items: viewModel.statusOptions
          .map((status) {
            return DropdownMenuItem(value: status, child: Text(status.label));
          })
          .toList(growable: false),
      onChanged: viewModel.selectStatus,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      hint: const Text('Select Status'),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE8F2F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EstimatedResolutionPicker extends StatelessWidget {
  const _EstimatedResolutionPicker({required this.viewModel});

  final UpdateIssueViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final options = viewModel.estimatedResolutionOptions;

    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
          initialItem: viewModel.selectedEstimatedResolutionIndex,
        ),
        itemExtent: 34,
        magnification: 1.06,
        squeeze: 1.08,
        useMagnifier: true,
        selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
          background: Color(0x1A315DFF),
        ),
        onSelectedItemChanged: viewModel.selectEstimatedResolutionIndex,
        children: [
          for (final option in options)
            Center(
              child: Text(
                option.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Small bold section label (descripion & update status)
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
