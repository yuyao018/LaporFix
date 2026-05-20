import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/function_appbar.dart';
import '../models/proof_attachment.dart';
import '../viewmodels/update_issue_view_model.dart';
import 'components/update_issue_widgets.dart';
import 'update_issue_success_page.dart';

// completion-only screen for proof upload and completion comment
// reuses same ViewModel created by UpdateIssuePage
// so selected status and proof draft stay together until saveCompletion called
class UpdateIssueProofPage extends StatelessWidget {
  const UpdateIssueProofPage({super.key, required this.viewModel});

  final UpdateIssueViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: const FunctionAppBar(title: 'Proof Of Completion'),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.functionBackground,
            ),
            child: SafeArea(
              top: false,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          CompletionProofCard(
                            viewModel: viewModel,
                            onAddImage: () => _pickImage(context),
                            onAddVideo: () => _pickVideo(context),
                            onRemoveProof: viewModel.removeProofAttachment,
                          ),
                          const Spacer(),
                          UpdateIssuePrimaryButton(
                            label: 'Complete',
                            isLoading: viewModel.isSaving,
                            onPressed: () => _handleComplete(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    await _pickProof(
      context,
      pick: () => ImagePicker().pickImage(source: ImageSource.gallery),
      type: ProofAttachmentType.image,
      errorPrefix: 'Image pick error',
    );
  }

  Future<void> _pickVideo(BuildContext context) async {
    await _pickProof(
      context,
      pick: () => ImagePicker().pickVideo(source: ImageSource.gallery),
      type: ProofAttachmentType.video,
      errorPrefix: 'Video pick error',
    );
  }

  Future<void> _pickProof(
    BuildContext context, {
    required Future<XFile?> Function() pick,
    required ProofAttachmentType type,
    required String errorPrefix,
  }) async {
    if (!viewModel.canAddProof) {
      // gives immediate feedback before opening another picker
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 5 proof files.')),
      );
      return;
    }

    try {
      final file = await pick();
      if (file == null || !context.mounted) return;

      // local file reference is stored here before submit
      viewModel.addProofAttachment(
        ProofAttachment(file: File(file.path), name: file.name, type: type),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$errorPrefix: $error')));
    }
  }

  Future<void> _handleComplete(BuildContext context) async {
    final validationMessage = viewModel.completionValidationMessage;
    if (validationMessage != null) {
      // keep validation text in ViewModel
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    try {
      await viewModel.saveCompletion();
      if (!context.mounted) return;
      // after success page auto-closes
      final wasUpdated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const UpdateIssueSuccessPage()),
      );
      if (wasUpdated == true && context.mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete issue: $error')),
      );
    }
  }
}
