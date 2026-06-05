import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../summary/models/issue_status.dart';
import '../../summary/models/issue_summary.dart';
import '../data/update_issue_repository.dart';
import '../models/proof_attachment.dart';
import '../models/update_issue_draft.dart';

class EstimatedResolutionOption {
  const EstimatedResolutionOption({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration duration;
}

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

  List<EstimatedResolutionOption> get estimatedResolutionOptions {
    return const [
      EstimatedResolutionOption(label: '1h', duration: Duration(hours: 1)),
      EstimatedResolutionOption(label: '2h', duration: Duration(hours: 2)),
      EstimatedResolutionOption(label: '3h', duration: Duration(hours: 3)),
      EstimatedResolutionOption(label: '4h', duration: Duration(hours: 4)),
      EstimatedResolutionOption(label: '5h', duration: Duration(hours: 5)),
      EstimatedResolutionOption(label: '6h', duration: Duration(hours: 6)),
      EstimatedResolutionOption(label: '7h', duration: Duration(hours: 7)),
      EstimatedResolutionOption(label: '8h', duration: Duration(hours: 8)),
      EstimatedResolutionOption(label: '9h', duration: Duration(hours: 9)),
      EstimatedResolutionOption(label: '10h', duration: Duration(hours: 10)),
      EstimatedResolutionOption(label: '11h', duration: Duration(hours: 11)),
      EstimatedResolutionOption(label: '12h', duration: Duration(hours: 12)),
      EstimatedResolutionOption(label: '13h', duration: Duration(hours: 13)),
      EstimatedResolutionOption(label: '14h', duration: Duration(hours: 14)),
      EstimatedResolutionOption(label: '15h', duration: Duration(hours: 15)),
      EstimatedResolutionOption(label: '16h', duration: Duration(hours: 16)),
      EstimatedResolutionOption(label: '17h', duration: Duration(hours: 17)),
      EstimatedResolutionOption(label: '18h', duration: Duration(hours: 18)),
      EstimatedResolutionOption(label: '19h', duration: Duration(hours: 19)),
      EstimatedResolutionOption(label: '20h', duration: Duration(hours: 20)),
      EstimatedResolutionOption(label: '21h', duration: Duration(hours: 21)),
      EstimatedResolutionOption(label: '22h', duration: Duration(hours: 22)),
      EstimatedResolutionOption(label: '23h', duration: Duration(hours: 23)),
      EstimatedResolutionOption(label: '1d', duration: Duration(days: 1)),
      EstimatedResolutionOption(label: '2d', duration: Duration(days: 2)),
      EstimatedResolutionOption(label: '3d', duration: Duration(days: 3)),
      EstimatedResolutionOption(label: '4d', duration: Duration(days: 4)),
      EstimatedResolutionOption(label: '5d', duration: Duration(days: 5)),
      EstimatedResolutionOption(label: '6d', duration: Duration(days: 6)),
      EstimatedResolutionOption(label: '7d', duration: Duration(days: 7)),
    ];
  }

  int get selectedEstimatedResolutionIndex {
    final selectedDuration = _draft.estimatedResolutionDuration;
    final index = estimatedResolutionOptions.indexWhere(
      (option) => option.duration == selectedDuration,
    );

    return index < 0 ? 0 : index;
  }

  String get selectedEstimatedResolutionLabel =>
      estimatedResolutionOptions[selectedEstimatedResolutionIndex].label;

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

  void selectEstimatedResolutionIndex(int index) {
    if (index < 0 || index >= estimatedResolutionOptions.length) return;

    final duration = estimatedResolutionOptions[index].duration;
    if (_draft.estimatedResolutionDuration == duration) return;

    _draft = _draft.copyWith(estimatedResolutionDuration: duration);
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
      return _repository.updateStatus(
        issueId: issue.id,
        status: status,
        estimatedResolutionDuration: status == IssueStatus.inProgress
            ? _draft.estimatedResolutionDuration
            : null,
      );
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
