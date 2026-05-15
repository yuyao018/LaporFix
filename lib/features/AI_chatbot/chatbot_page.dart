import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/function_appbar.dart';
import '../../widgets/chatbox.dart';
import 'models/chat_message.dart';
import 'models/disruption_notice.dart';
import 'services/chatbot_service.dart';
import 'widgets/card.dart';
import 'widgets/disruption_notice_card.dart';
import '../issue_reporting/issue_reporting_page.dart';
import '../../../widgets/button.dart';

// ── Chat list item: either a real message or a date-separator header ──────────
sealed class _ChatItem {}

class _MessageItem extends _ChatItem {
  final ChatMessage message;
  _MessageItem(this.message);
}

class _DateHeader extends _ChatItem {
  final DateTime sessionTime;
  _DateHeader(this.sessionTime);
}

// ── Pending attachment ────────────────────────────────────────────────────────
enum _AttachType { image, doc }

class _Attachment {
  final String name;
  final String path;
  final _AttachType type;
  const _Attachment({required this.name, required this.path, required this.type});
}

class ChatbotPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ChatbotPage({super.key, this.onBack});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final ChatbotService _service = ChatbotService();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatItem> _items = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _hasStartedChat = false;
  bool _isLoadingHistory = false;

  // Pending attachment — set when user picks a file, cleared after send
  _Attachment? _pendingAttachment;

  // User location — loaded once on init for disruption checks
  String _userArea = '';
  String _userState = '';

  static const String _reportIssueSuggestion = 'How to report an issue?';

  static const List<String> _suggestions = [
    _reportIssueSuggestion,
    'Track my existing ticket',
    'Check for water/power cut',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  String get _greeting {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'Morning'
        : hour < 17
            ? 'Afternoon'
            : 'Evening';
    return 'Good $timeOfDay, $name!';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Called by ChatBox.onSend (plain text only) ─────────────────────────────
  Future<void> _onSend(String text) async {
    final attach = _pendingAttachment;
    setState(() => _pendingAttachment = null);
    await _sendMessage(text, attachment: attach);
  }

  Future<void> _sendMessage(
    String text, {
    _Attachment? attachment,
    bool showReportIssueButton = false,
  }) async {
    final hasText = text.trim().isNotEmpty;
    if (!hasText && attachment == null) return;
    if (_isLoading) return;

    // Build the display text for the user bubble
    String displayText = text.trim();
    if (attachment != null) {
      final label = attachment.type == _AttachType.image
          ? '📷 ${attachment.name}'
          : '📄 ${attachment.name}';
      displayText = hasText ? '$label\n$displayText' : label;
    }

    setState(() {
      _hasStartedChat = true;
      _items.add(_MessageItem(ChatMessage(
        text: displayText,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      )));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      Map<String, String> result;

      if (attachment != null && attachment.type == _AttachType.image) {
        result = await _service.sendVisionMessage(
          imagePath: attachment.path,
          message: text.trim(),
          sessionId: _sessionId,
        );
      } else if (attachment != null && attachment.type == _AttachType.doc) {
        result = await _service.sendDocumentMessage(
          documentPath: attachment.path,
          message: text.trim(),
          sessionId: _sessionId,
        );
      } else {
        result = await _service.sendMessage(
          message: text.trim(),
          sessionId: _sessionId,
        );
      }

      final answer = result['answer']!;

      setState(() {
        _sessionId = result['session_id'];
        _items.add(_MessageItem(ChatMessage(
          text: answer,
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          showReportButton: showReportIssueButton,
        )));
      });
    } catch (e) {
      setState(() {
        _items.add(_MessageItem(ChatMessage(
          text: 'Sorry, I could not connect to the server. Please try again.',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        )));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // ── File pickers ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _pendingAttachment = _Attachment(
          name: picked.name,
          path: picked.path,
          type: _AttachType.image,
        ));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    setState(() => _pendingAttachment = _Attachment(
          name: file.name,
          path: file.path ?? '',
          type: _AttachType.doc,
        ));
  }

  Future<void> _fetchUserLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _userArea = (doc.data()?['area'] ?? '').toString();
        _userState = (doc.data()?['state'] ?? '').toString();
      });
    }
  }

  /// Query Firestore announcements for water/power disruptions in the user's area.
  /// Called when the user taps the "Check for water/power cut" suggestion card.
  Future<void> _checkDisruptions() async {
    // Show the user's question as a chat bubble immediately
    setState(() {
      _hasStartedChat = true;
      _items.add(_MessageItem(ChatMessage(
        text: 'Check for water/power cut',
        role: MessageRole.user,
        timestamp: DateTime.now(),
      )));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .get();

      // Keywords that indicate a water, power, or road disruption
      const disruptionKeywords = [
        'water', 'air', 'bekalan air',
        'power', 'electric', 'elektrik', 'tenaga', 'tnb',
        'road', 'jalan', 'highway', 'construction', 'traffic',
        'outage', 'disruption', 'gangguan', 'cut', 'putus',
        'maintenance', 'penyelenggaraan',
      ];

      final userArea = _userArea.toLowerCase();
      final userState = _userState.toLowerCase();

      final matches = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;

        // Check location match
        final target = data['target'] as Map<String, dynamic>? ?? {};
        final location = target['location'] as Map<String, dynamic>? ?? {};
        final annArea = (location['area'] ?? '').toString().toLowerCase();
        final annState = (location['state'] ?? '').toString().toLowerCase();
        final annFull = (location['full'] ?? '').toString().toLowerCase();

        bool locationMatch = userArea.isEmpty && userState.isEmpty; // show all if no location set
        if (!locationMatch && userArea.isNotEmpty) {
          locationMatch = annArea == userArea ||
              annFull.contains(userArea) ||
              annArea.contains(userArea);
        }
        if (!locationMatch && userState.isNotEmpty) {
          locationMatch = annState == userState || annFull.contains(userState);
        }
        if (!locationMatch) continue;

        // Check keyword match in title or caption
        final title = (data['title'] ?? '').toString().toLowerCase();
        final caption = (data['caption'] ?? '').toString().toLowerCase();
        final combined = '$title $caption';

        final isDisruption = disruptionKeywords.any((kw) => combined.contains(kw));
        if (!isDisruption) continue;

        matches.add(data);
      }

      if (matches.isEmpty) {
        final location = userArea.isNotEmpty
            ? userArea
            : userState.isNotEmpty
                ? userState
                : 'your area';
        setState(() {
          _items.add(_MessageItem(ChatMessage(
            text: '✅ No water, power, or road maintenance announcements found for $location at the moment.\n\n'
                'If you are experiencing an issue, you can report it directly through the app.',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          )));
        });
      } else {
        setState(() {
          final now = DateTime.now();
          for (final data in matches) {
            _items.add(_MessageItem(ChatMessage(
              text: '',
              role: MessageRole.assistant,
              timestamp: now,
              disruptionNotice: DisruptionNotice.fromAnnouncement(data),
            )));
          }
        });
      }
    } catch (e) {
      setState(() {
        _items.add(_MessageItem(ChatMessage(
          text: 'Sorry, I could not check announcements right now. Please try again.',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        )));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  /// Query Firestore issues collection for the current user's open tickets.
  Future<void> _checkTickets() async {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _hasStartedChat = true;
      _items.add(_MessageItem(ChatMessage(
        text: 'Track my existing ticket',
        role: MessageRole.user,
        timestamp: DateTime.now(),
      )));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      if (user == null) {
        setState(() {
          _items.add(_MessageItem(ChatMessage(
            text: 'You need to be logged in to check your tickets.',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          )));
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('issues')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['submitted', 'in_progress', 'Submitted', 'In Progress'])
          .orderBy('createdAt', descending: true)
          .get();

      String answer;
      if (snapshot.docs.isEmpty) {
        answer = '✅ You have no open tickets at the moment.\n\n'
            'If you have an issue to report, tap the **Report Issue** button to get started.';
      } else {
        final buf = StringBuffer();
        buf.writeln('📋 You have ${snapshot.docs.length} open ticket${snapshot.docs.length > 1 ? 's' : ''}:\n');

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = data['title'] ?? data['category'] ?? 'Issue';
          final status = data['status'] ?? 'Submitted';
          final ticketId = data['ticketId'] ?? doc.id.substring(0, 8).toUpperCase();
          final createdAt = data['createdAt'];
          String dateStr = '';
          if (createdAt is Timestamp) {
            final dt = createdAt.toDate();
            dateStr = ' • ${dt.day}/${dt.month}/${dt.year}';
          }

          final statusIcon = status.toLowerCase().contains('progress') ? '🔧' : '📨';
          buf.writeln('$statusIcon **$title**');
          buf.writeln('   Ticket: #$ticketId$dateStr');
          buf.writeln('   Status: $status\n');
        }

        buf.write('Go to **My Reports** to view full details.');
        answer = buf.toString();
      }

      setState(() {
        _items.add(_MessageItem(ChatMessage(
          text: answer,
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        )));
      });
    } catch (e) {
      // Collection may not exist yet or index missing — handle gracefully
      setState(() {
        _items.add(_MessageItem(ChatMessage(
          text: 'Could not retrieve your tickets right now. Please check the My Reports section directly.',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        )));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _showHistory() async {
    if (_isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);

    try {
      final sessions = await _service.fetchSessions();

      final pastSessions = sessions
          .where((s) => s.sessionId != _sessionId)
          .toList()
          .reversed
          .toList();

      if (pastSessions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No past sessions found.')),
          );
        }
        return;
      }

      final allMessages = await Future.wait(
        pastSessions.map((s) => _service.fetchMessages(s.sessionId)),
      );

      final historyItems = <_ChatItem>[];
      for (var i = 0; i < pastSessions.length; i++) {
        final session = pastSessions[i];
        final messages = allMessages[i];
        if (messages.isEmpty) continue;

        final sessionTime = session.updatedAt ??
            session.createdAt ??
            messages.first.timestamp;

        historyItems.add(_DateHeader(sessionTime));
        historyItems.addAll(messages.map(_MessageItem.new));
      }

      if (historyItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No messages found in past sessions.')),
          );
        }
        return;
      }

      setState(() {
        _hasStartedChat = true;
        _items.insertAll(0, historyItems);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load history: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FunctionAppBar(
        title: 'LAPI',
        onBack: widget.onBack,
        showHistory: true,
        onHistoryTap: _isLoadingHistory ? null : _showHistory,
      ),
      backgroundColor: const Color(0xFFF8F9FF),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.functionBackground,
        ),
        child: Column(
          children: [
            // ── Chat area ──────────────────────────────────────────
            Expanded(
              child: _hasStartedChat
                  ? _buildChatList(textTheme)
                  : _buildWelcomeScreen(textTheme),
            ),

            // ── Loading indicator ──────────────────────────────────
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: _TypingIndicator(),
              ),

            // ── Attachment chip (shown above ChatBox when file is pending) ──
            if (_pendingAttachment != null)
              Container(
                color: const Color(0xFFF3F4F6),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1FE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF5F80F8), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _pendingAttachment!.type == _AttachType.image
                              ? Icons.image_outlined
                              : Icons.description_outlined,
                          size: 16,
                          color: const Color(0xFF5F80F8),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.55,
                          ),
                          child: Text(
                            _pendingAttachment!.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5F80F8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _pendingAttachment = null),
                          child: const Icon(Icons.close,
                              size: 14, color: Color(0xFF5F80F8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Input box ──────────────────────────────────────────
            ChatBox(
              hintText: 'Ask Something ...',
              showPlusButton: true,
              onSend: _onSend,
              onUploadImage: _pickImage,
              onUploadDoc: _pickDocument,
            ),
          ],
        ),
      ),
    );
  }

  // ── Welcome screen ─────────────────────────────────────────────────────────
  Widget _buildWelcomeScreen(TextTheme textTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/icons/lapo_robot.png'),
        const SizedBox(height: 20),
        Text(
          _greeting,
          style: textTheme.titleLarge
              ?.copyWith(color: Colors.white, fontSize: 24),
        ),
        const SizedBox(height: 40),
        ..._suggestions.map(
          (s) => ChatbotCard(
            title: s,
            onPressed: () {
              if (s == 'Check for water/power cut') {
                _checkDisruptions();
              } else if (s == 'Track my existing ticket') {
                _checkTickets();
              } else if (s == _reportIssueSuggestion) {
                _sendMessage(s, showReportIssueButton: true);
              } else {
                _sendMessage(s);
              }
            },
          ),
        ),
      ],
    );
  }

  // ── Chat message list ──────────────────────────────────────────────────────
  Widget _buildChatList(TextTheme textTheme) {
    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[_items.length - 1 - index];
        return switch (item) {
          _MessageItem(:final message) => _ChatBubble(message: message),
          _DateHeader(:final sessionTime) => _SessionDivider(time: sessionTime),
        };
      },
    );
  }
}

// ── Session date divider ──────────────────────────────────────────────────────
class _SessionDivider extends StatelessWidget {
  final DateTime time;
  const _SessionDivider({required this.time});

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _format() {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final month = _months[time.month];
    return '$h:$m  ${time.day} $month ${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: AppTheme.textOnGradient.withValues(alpha: 0.85),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white54, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_format(), style: labelStyle),
          ),
          const Expanded(child: Divider(color: Colors.white54, thickness: 1)),
        ],
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');

  TextStyle _baseStyle(TextTheme textTheme, {required bool isUser}) {
    final style = isUser ? textTheme.bodyLarge! : textTheme.bodyMedium!;
    return style.copyWith(
      fontSize: 15,
      height: 1.5,
      letterSpacing: 0.1,
      color: AppTheme.textPrimary,
      fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
    );
  }

  TextStyle _boldStyle(TextTheme textTheme) {
    return textTheme.titleLarge!.copyWith(
      fontSize: 15,
      height: 1.5,
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }

  Widget _buildMessageBody(TextTheme textTheme, {required bool isUser}) {
    final base = _baseStyle(textTheme, isUser: isUser);
    final bold = _boldStyle(textTheme);
    final text = message.text;

    if (!text.contains('**')) {
      return Text(text, style: base);
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final match in _boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: base));
      }
      spans.add(TextSpan(text: match.group(1), style: bold));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: base));
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final textTheme = Theme.of(context).textTheme;
    final notice = message.disruptionNotice;

    if (!isUser && notice != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.88,
          ),
          child: DisruptionNoticeCard(notice: notice),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isUser ? 0.95 : 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.text.isNotEmpty)
              _buildMessageBody(textTheme, isUser: isUser),
            if (message.showReportButton) ...[
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Report Issue',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const IssueReportingPage()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i / 3;
                final opacity =
                    ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFFD1D5DB),
                      const Color(0xFF5F80F8),
                      opacity,
                    )!,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
