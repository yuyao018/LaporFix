import 'package:flutter/material.dart';

/// Announcement card colour definitions.
/// Each colour has a background fill and a border/accent colour.
class AnnouncementColours {
  AnnouncementColours._();

  static const Map<String, AnnouncementColour> all = {
    'green': AnnouncementColour(
      background: Color(0xFFE8FFE8),
      border: Color(0xFF4CAF50),
    ),
    'pink': AnnouncementColour(
      background: Color(0xFFFADAF7),
      border: Color(0xFFA40BA2),
    ),
    'blue': AnnouncementColour(
      background: Color(0xFFE8F1FF),
      border: Color(0xFF5F80F8),
    ),
    'yellow': AnnouncementColour(
      background: Color(0xFFFFF9E0),
      border: Color(0xFFF5A623),
    ),
    'orange': AnnouncementColour(
      background: Color(0xFFFFF0E0),
      border: Color(0xFFFF6B00),
    ),
    'red': AnnouncementColour(
      background: Color(0xFFFFE8E8),
      border: Color(0xFFE53935),
    ),
    'purple': AnnouncementColour(
      background: Color(0xFFF3E8FF),
      border: Color(0xFF7B1FA2),
    ),
    'teal': AnnouncementColour(
      background: Color(0xFFE0F7FA),
      border: Color(0xFF00897B),
    ),
  };

  /// Get colour by name, defaults to green if not found.
  static AnnouncementColour get(String name) {
    return all[name.toLowerCase()] ?? all['green']!;
  }

  /// List of all available colour names (for dropdowns).
  static List<String> get names => all.keys.toList();
}

class AnnouncementColour {
  final Color background;
  final Color border;

  const AnnouncementColour({
    required this.background,
    required this.border,
  });
}
