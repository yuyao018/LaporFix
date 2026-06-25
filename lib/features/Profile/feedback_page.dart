import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/function_appbar.dart';
import '../../theme/app_theme.dart';

enum FeedbackType {
  appIssue,
  reportDissatisfaction,
  suggestion,
  other,
}

class FeedbackPage extends StatefulWidget {
  final VoidCallback? onBack;

  const FeedbackPage({super.key, this.onBack});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _detailsController = TextEditingController();
  FeedbackType _selectedType = FeedbackType.appIssue;
  bool _isSubmitting = false;

  String _getFeedbackTypeLabel(FeedbackType type) {
    switch (type) {
      case FeedbackType.appIssue:
        return 'Issue with the app';
      case FeedbackType.reportDissatisfaction:
        return 'Not satisfied with report resolution';
      case FeedbackType.suggestion:
        return 'Suggestion for improvement';
      case FeedbackType.other:
        return 'Other';
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to submit feedback.')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'userEmail': user.email,
        'type': _selectedType.name,
        'subject': _subjectController.text.trim(),
        'details': _detailsController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FunctionAppBar(title: 'Feedback & Complaints', onBack: widget.onBack),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradientDiagonal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.feedback_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'We want to hear from you',
                              style: tt.titleLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your feedback helps us improve.',
                              style: tt.bodySmall?.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Feedback type selection
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category_rounded, color: AppTheme.primaryBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'What is this about?',
                            style: tt.titleLarge?.copyWith(
                              color: AppTheme.primaryBlue,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...FeedbackType.values.map((type) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: RadioListTile<FeedbackType>(
                            value: type,
                            groupValue: _selectedType,
                            onChanged: _isSubmitting
                                ? null
                                : (value) => setState(() => _selectedType = value!),
                            title: Text(
                              _getFeedbackTypeLabel(type),
                              style: tt.bodyLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppTheme.primaryBlue,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Subject and details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Tell us more',
                            style: tt.titleLarge?.copyWith(
                              color: AppTheme.primaryBlue,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Subject
                      TextFormField(
                        controller: _subjectController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          labelStyle: tt.bodyMedium,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.short_text_rounded),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter a subject';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Details
                      TextFormField(
                        controller: _detailsController,
                        enabled: !_isSubmitting,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Details',
                          labelStyle: tt.bodyMedium,
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.description_rounded),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please provide details';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
