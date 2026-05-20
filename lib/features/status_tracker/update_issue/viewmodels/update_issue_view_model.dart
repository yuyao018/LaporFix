import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../summary/models/issue_status.dart';
import '../../summary/models/issue_summary.dart';
import '../data/update_issue_repository.dart';
import '../models/proof_attachment.dart';
import '../models/update_issue_draft.dart';

/// ViewModel for update issue flow
class UpdateIssueViewModel extends ChangeNotifier {
  UpdateIssueViewModel({required this.issue, UpdateIssueRepository? repository})
    : _repository = repository ?? UpdateIssueRepository();

  final IssueSummary issue;
  final UpdateIssueRepository _repository;

  // draft data is local until Next/Complete
  UpdateIssueDraft _draft = const UpdateIssueDraft();
  bool _isSaving = false;
  Object? _error;

  UpdateIssueDraft get draft => _draft;
  bool get isSaving => _isSaving;
  Object? get error => _error;
  bool get canContinue => _draft.selectedStatus != null && !_isSaving;
  bool get canAddProof => _draft.proofAttachments.length < 5 && !_isSaving;
  bool get canComplete =>
      _draft.proofDescription.trim().isNotEmpty &&
      _draft.proofAttachments.isNotEmpty &&
      !_isSaving;

  // validation for completed issue
  // must include a comment and at least one proof file.
  String? get completionValidationMessage {
    if (_draft.proofDescription.trim().isEmpty) {
      return 'Add a completion comment before saving.';
    }
    if (_draft.proofAttachments.isEmpty) {
      return 'Add at least one proof image or video before saving.';
    }
    return null;
  }

  List<IssueStatus> get statusOptions => const [
    // submitted is excluded, no backward or re-update the same state
    IssueStatus.inProgress,
    IssueStatus.completed,
  ];

  String? get reportImageUrl =>
      issue.reportImages.isEmpty ? null : issue.reportImages.first.trim();

  String get submittedDateText {
    final date = issue.submittedAt;
    if (date == null) return 'Date unavailable';
    return DateFormat('d MMMM yyyy').format(date);
  }

  void selectStatus(IssueStatus? status) {
    if (_draft.selectedStatus == status) return;
    _draft = _draft.copyWith(selectedStatus: status);
    notifyListeners();
  }

  void updateProofDescription(String value) {
    if (_draft.proofDescription == value) return;
    _draft = _draft.copyWith(proofDescription: value);
    notifyListeners();
  }

  void addProofAttachment(ProofAttachment attachment) {
    if (!canAddProof) return;

    // create new list so ChangeNotifier listeners see new draft object
    _draft = _draft.copyWith(
      proofAttachments: [..._draft.proofAttachments, attachment],
    );
    notifyListeners();
  }

  void removeProofAttachment(int index) {
    if (index < 0 || index >= _draft.proofAttachments.length) return;

    final attachments = [..._draft.proofAttachments]..removeAt(index);
    _draft = _draft.copyWith(proofAttachments: attachments);
    notifyListeners();
  }

  Future<void> saveStatusUpdate() async {
    // non-completed updates only need selected status
    // completion uses separate saveCompletion path to upload proof files first
    final status = _draft.selectedStatus;
    if (status == null) {
      throw StateError('Select a status before continuing.');
    }

    await _save(() {
      return _repository.updateStatus(issueId: issue.id, status: status);
    });
  }

  Future<void> saveCompletion() async {
    final validationMessage = completionValidationMessage;
    if (validationMessage != null) {
      throw StateError(validationMessage);
    }

    await _save(() {
      return _repository.completeIssue(
        issueId: issue.id,
        description: _draft.proofDescription,
        proofAttachments: _draft.proofAttachments,
      );
    });
  }

  Future<void> _save(Future<void> Function() action) async {
    // loading/error handling
    if (_isSaving) return;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
