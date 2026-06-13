import 'package:flutter/material.dart';

// Status values used for Firestore parsing, filters, and display styling.
enum IssueStatus {
  all('All'),
  submitted('Submitted'),
  inProgress('In Progress'),
  completed('Completed'),
  unknown('Unknown');

  const IssueStatus(this.label);

  final String label;

  static const List<IssueStatus> filters = [
    all,
    submitted,
    inProgress,
    completed,
  ];

  static IssueStatus fromText(String? value) {
    // Firestore values may arrive as "inProgress", "in-progress", or
    // "in progress"; normalize those shapes before matching.
    final normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    return switch (normalized) {
      'all' => IssueStatus.all,
      'submitted' => IssueStatus.submitted,
      'in progress' => IssueStatus.inProgress,
      'completed' => IssueStatus.completed,
      _ => IssueStatus.unknown,
    };
  }

  bool get isFilter => this != IssueStatus.unknown;

  Color get foregroundColor {
    return switch (this) {
      IssueStatus.submitted => const Color(0xFF2458D4),
      IssueStatus.inProgress => const Color(0xFFC27A00),
      IssueStatus.completed => const Color(0xFF087A3A),
      IssueStatus.all || IssueStatus.unknown => const Color(0xFF475467),
    };
  }

  Color get backgroundColor {
    return switch (this) {
      IssueStatus.submitted => const Color(0xFFE6EDFF),
      IssueStatus.inProgress => const Color(0xFFFFF1A6),
      IssueStatus.completed => const Color(0xFFD7FBE4),
      IssueStatus.all || IssueStatus.unknown => const Color(0xFFF2F4F7),
    };
  }
}
