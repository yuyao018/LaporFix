import '../../summary/models/issue_status.dart';
import 'proof_attachment.dart';

// unsaved form state for the update issue
// model stays separate from IssueSummary before anything is committed to Firebase.
class UpdateIssueDraft {
  const UpdateIssueDraft({
    this.selectedStatus,
    this.proofDescription = '',
    this.proofAttachments = const [],
  });

  final IssueStatus? selectedStatus;
  final String proofDescription;
  final List<ProofAttachment> proofAttachments;

  // updates keep ViewModel state changes to avoid widgets mutate draft list
  UpdateIssueDraft copyWith({
    IssueStatus? selectedStatus,
    String? proofDescription,
    List<ProofAttachment>? proofAttachments,
  }) {
    return UpdateIssueDraft(
      selectedStatus: selectedStatus ?? this.selectedStatus,
      proofDescription: proofDescription ?? this.proofDescription,
      proofAttachments: proofAttachments ?? this.proofAttachments,
    );
  }
}
