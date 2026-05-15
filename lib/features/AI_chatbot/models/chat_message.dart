import 'disruption_notice.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  /// When true, the chat bubble renders a "Report Issue" action button
  /// (only set when the user taps the "How to report an issue?" suggestion card).
  final bool showReportButton;

  /// When set, the assistant bubble renders a [DisruptionNoticeCard] instead of plain text.
  final DisruptionNotice? disruptionNotice;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.showReportButton = false,
    this.disruptionNotice,
  });

  bool get isUser => role == MessageRole.user;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['content'] as String,
      role: (json['role'] as String) == 'user'
          ? MessageRole.user
          : MessageRole.assistant,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
