class ChatSession {
  final String sessionId;
  final String preview;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const ChatSession({
    required this.sessionId,
    required this.preview,
    this.updatedAt,
    this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id'] as String,
      preview: (json['preview'] as String?) ?? 'Chat session',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
