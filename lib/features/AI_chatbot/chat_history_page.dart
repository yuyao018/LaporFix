import 'package:flutter/material.dart';
import 'models/chat_session.dart';
import 'services/chatbot_service.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  final ChatbotService _service = ChatbotService();
  late Future<List<ChatSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _service.fetchSessions();
  }

  void _refresh() {
    setState(() {
      _sessionsFuture = _service.fetchSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // WhatsApp-like grey bg
      appBar: AppBar(
        backgroundColor: const Color(0xFF5F80F8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'LAPI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<ChatSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load history.\nMake sure the backend is running.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icons/lapo_robot.png', width: 80),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet.\nStart chatting with LAPI!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                ],
              ),
            );
          }

          // Group sessions by date
          final grouped = _groupByDate(sessions);

          return ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (context, i) {
              final entry = grouped[i];

              // Date header
              if (entry is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    entry,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }

              // Session tile
              final session = entry as ChatSession;
              return _SessionTile(
                session: session,
                onTap: () => Navigator.pop(context, session),
                onDelete: () async {
                  await _service.resetSession(session.sessionId);
                  _refresh();
                },
              );
            },
          );
        },
      ),
      // New chat FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, null), // null = new session
        backgroundColor: const Color(0xFF5F80F8),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Chat', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Returns a flat list alternating between String (date headers) and ChatSession.
  List<Object> _groupByDate(List<ChatSession> sessions) {
    final result = <Object>[];
    String? lastLabel;

    for (final session in sessions) {
      final label = _dateLabel(session.updatedAt);
      if (label != lastLabel) {
        result.add(label);
        lastLabel = label;
      }
      result.add(session);
    }
    return result;
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return 'Older';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Session tile (WhatsApp-style) ─────────────────────────────────────────────
class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final time = session.updatedAt != null
        ? _formatTime(session.updatedAt!)
        : '';

    return Dismissible(
      key: Key(session.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete conversation?'),
            content: const Text('This will permanently delete this chat history.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        color: Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFE8ECFF),
            child: Image.asset('assets/icons/lapo_robot.png', width: 30),
          ),
          title: Text(
            session.preview.isNotEmpty ? session.preview : 'Chat session',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1A1A2E),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${session.sessionId.substring(0, 8)}...',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          trailing: Text(
            time,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
