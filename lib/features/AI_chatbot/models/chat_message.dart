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

  /// When set, the assistant bubble renders a ticket card instead of plain text.
  final Map<String, dynamic>? ticketData;

  /// Firebase Storage download URL for a user-uploaded chat image.
  final String? imageUrl;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.showReportButton = false,
    this.disruptionNotice,
    this.ticketData,
    this.imageUrl,
  });

  bool get isUser => role == MessageRole.user;

  /// Text shown in the bubble (strips the [Image] prefix when an image is attached).
  String get displayText {
    const prefix = '[Image] ';
    if (imageUrl != null && text.startsWith(prefix)) {
      return text.substring(prefix.length).trim();
    }
    return text;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['content'] as String? ?? '',
      role: (json['role'] as String) == 'user'
          ? MessageRole.user
          : MessageRole.assistant,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      imageUrl: json['image_url'] as String?,
      disruptionNotice: json['disruption_notice'] != null
          ? DisruptionNotice.fromJson(
              json['disruption_notice'] as Map<String, dynamic>,
            )
          : null,
      ticketData: json['ticket'] != null
          ? Map<String, dynamic>.from(json['ticket'] as Map)
          : null,
    );
  }
}
