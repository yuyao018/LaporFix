import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:group2_urbanfix/features/issue_reporting/models/issue_report_model.dart';
import 'package:group2_urbanfix/features/issue_reporting/viewmodels/issue_reporting_view_model.dart';

import 'package:group2_urbanfix/theme/app_theme.dart';

import 'package:group2_urbanfix/widgets/function_appbar.dart';

import '../issue_reporting/issue_reporting_map.dart';

class IssueReportingPage extends StatefulWidget {
  const IssueReportingPage({super.key});

  VoidCallback? get onBack => null;

  @override
  State<IssueReportingPage> createState() => _IssueReportingPageState();
}

class _IssueReportingPageState extends State<IssueReportingPage> {
  late final IssueReportingViewModel viewModel;

  @override
  void initState() {
    super.initState();

    viewModel = IssueReportingViewModel();
    viewModel.loadDraftIfEnabled().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _pickImage(BuildContext context) async {
    await _pickProof(
      context,
      pick: () => ImagePicker().pickImage(source: ImageSource.gallery),
      type: ReportAttachmentType.image,
      errorPrefix: 'Image pick error',
    );
  }

  Future<void> _pickVideo(BuildContext context) async {
    await _pickProof(
      context,
      pick: () => ImagePicker().pickVideo(source: ImageSource.gallery),
      type: ReportAttachmentType.video,
      errorPrefix: 'Video pick error',
    );
  }

  Future<void> _pickProof(
    BuildContext context, {
    required Future<XFile?> Function() pick,
    required ReportAttachmentType type,
    required String errorPrefix,
  }) async {
    if (!viewModel.canAddProof) {
      // gives immediate feedback before opening another picker
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 5 report files.')),
      );
      return;
    }

    try {
      final file = await pick();
      if (file == null || !context.mounted) return;

      // local file reference is stored here before submit
      viewModel.addProofAttachment(
        ReportAttachment(file: File(file.path), name: file.name, type: type),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$errorPrefix: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOtherSelected = viewModel.isOtherCategorySelected;

    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: FunctionAppBar(title: 'Create Report', onBack: widget.onBack),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ReportProofPanel(
                                viewModel: viewModel,
                                onAddImage: () => _pickImage(context),
                                onAddVideo: () => _pickVideo(context),
                                onRemoveProof: (index) {
                                  setState(() {
                                    viewModel.removeProofAttachment(index);
                                  });
                                },
                              ),

                              const SizedBox(height: 20),

                              // Category Section
                              const Text(
                                'Select Category',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF1F3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),

                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value:
                                        (viewModel.categories.contains(
                                          viewModel.report.category,
                                        ))
                                        ? viewModel.report.category
                                        : null,

                                    hint: const Text(
                                      'Select Category',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),

                                    isExpanded: true,

                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.grey,
                                      size: 28,
                                    ),

                                    items: viewModel.categories.map((category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),

                                    onChanged: (e) {
                                      viewModel.updateCategory(e);
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),

                              // Show custom category input if "Other" is selected
                              if (isOtherSelected) ...[
                                const SizedBox(height: 12),

                                TextField(
                                  style: const TextStyle(fontSize: 16),
                                  controller: viewModel.categoryController,
                                  onChanged: (value) {
                                    viewModel.updateCustomCategory(value);
                                    setState(() {});
                                  },
                                  maxLength: 12,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your category',
                                    hintStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),

                                    filled: true,
                                    fillColor: const Color(0xFFEBF1F3),
                                    isDense: true,

                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),

                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Description
                              const Text(
                                'Add Description',

                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Description Input Field
                              SizedBox(
                                height: 280,
                                child: TextField(
                                  controller: viewModel.descriptionController,
                                  style: const TextStyle(fontSize: 16),
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  onChanged: (value) {
                                    viewModel.updateDescription(value);
                                    setState(() {}); // Refresh UI
                                  },

                                  decoration: InputDecoration(
                                    hintText: 'Add a description text...',
                                    hintStyle: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),

                                    filled: true,
                                    fillColor: const Color(0xFFEBF1F3),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),

                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Next Button
                              SizedBox(
                                width: 350,
                                height: 55,

                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: viewModel.validateStepOne()
                                        ? AppTheme.accentBlue
                                        : Colors.grey.shade400,

                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),

                                  onPressed: () async {
                                    // Prevent navigation if required fields are missing

                                    if (!viewModel.validateStepOne()) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please upload an image or video, select a category, and add a description. If you choose Other, enter the category name.',
                                          ),

                                          backgroundColor: Colors.redAccent,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );

                                      return; // Prevent navigation
                                    }

                                    // Capture navigator before async gap
                                    final navigator = Navigator.of(context);

                                    // Show loading indicator while fetching location
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    try {
                                      await viewModel.getCurrentLocation();
                                    } catch (e) {
                                      debugPrint('Location error: $e');
                                    }

                                    if (!mounted) return;
                                    navigator
                                        .pop(); // Always close loading dialog
                                    navigator.push(
                                      MaterialPageRoute(
                                        builder: (_) => IssueReportingMap(
                                          viewModel: viewModel,
                                        ),
                                      ),
                                    );
                                  },

                                  child: Text(
                                    'Next',

                                    style: AppTheme.appTextTheme.labelLarge
                                        ?.copyWith(
                                          fontSize: 20,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReportProofPanel extends StatelessWidget {
  const _ReportProofPanel({
    required this.viewModel,
    required this.onAddImage,
    required this.onAddVideo,
    required this.onRemoveProof,
  });

  final IssueReportingViewModel viewModel;
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
                  child: viewModel.report.attachments.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.photo_camera_outlined,
                            color: Color(0xFF8F9398),
                            size: 58,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: viewModel.report.attachments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final attachment =
                                viewModel.report.attachments[index];

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
                  '${viewModel.report.attachments.length}/5 report files selected',
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

class _ProofAttachmentTile extends StatelessWidget {
  const _ProofAttachmentTile({
    required this.attachment,
    required this.onRemove,
  });

  final ReportAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = attachment.type == ReportAttachmentType.video;

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
