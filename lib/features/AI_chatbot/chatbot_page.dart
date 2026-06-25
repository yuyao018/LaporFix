import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/function_appbar.dart';
import '../../widgets/chatbox.dart';
import '../issue_reporting/issue_reporting_page.dart';
import '../../../widgets/button.dart';
import 'models/chat_message.dart';
import 'view_models/chat_view_model.dart';
import 'widgets/card.dart';
import 'widgets/disruption_notice_card.dart';

// ── Chat list item type alias for brevity ─────────────────────────────────────
export 'view_models/chat_view_model.dart'
    show ChatItem, MessageItem, DateHeaderItem, TicketItem, PendingAttachment, AttachType;

class ChatbotPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ChatbotPage({super.key, this.onBack});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialise once after first frame so ViewModel is already in tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().init();
    });
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
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── File pickers ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    context.read<ChatViewModel>().setPendingAttachment(PendingAttachment(
      name: picked.name,
      path: picked.path,
      type: AttachType.image,
    ));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    context.read<ChatViewModel>().setPendingAttachment(PendingAttachment(
      name: file.name,
      path: file.path ?? '',
      type: AttachType.doc,
    ));
  }

  // ── History ────────────────────────────────────────────────────────────────
  Future<void> _showHistory() async {
    final vm = context.read<ChatViewModel>();
    final error = await vm.loadHistory();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  Future<void> _onSend(String text) async {
    final vm = context.read<ChatViewModel>();
    await vm.onSend(text);
    _scrollToBottom();
  }

  // ── Suggestion card tap ────────────────────────────────────────────────────
  Future<void> _onSuggestionTap(String suggestion) async {
    final vm = context.read<ChatViewModel>();
    if (suggestion == 'Check for water/power cut') {
      await vm.checkDisruptions();
    } else if (suggestion == 'Check for road maintenance') {
      await vm.checkRoadMaintenance();
    } else if (suggestion == 'Track my existing ticket') {
      await vm.checkTickets();
    } else if (suggestion == ChatViewModel.reportIssueSuggestion) {
      await vm.sendMessage(suggestion, showReportIssueButton: true);
    } else {
      await vm.sendMessage(suggestion);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FunctionAppBar(
        title: 'LAPI',
        onBack: widget.onBack,
        showHistory: true,
        onHistoryTap: context.select<ChatViewModel, bool>(
                (vm) => vm.isLoadingHistory)
            ? null
            : _showHistory,
      ),
      backgroundColor: const Color(0xFFF8F9FF),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration:
            const BoxDecoration(gradient: AppTheme.functionBackground),
        child: Consumer<ChatViewModel>(
          builder: (context, vm, _) {
            return Column(
              children: [
                // ── Chat area ──────────────────────────────────────
                Expanded(
                  child: vm.hasStartedChat
                      ? _buildChatList(vm, textTheme)
                      : _buildWelcomeScreen(vm, textTheme),
                ),

                // ── Typing indicator ───────────────────────────────
                if (vm.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: _TypingIndicator(),
                  ),

                // ── Pending attachment chip ────────────────────────
                if (vm.pendingAttachment != null)
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
                              vm.pendingAttachment!.type ==
                                      AttachType.image
                                  ? Icons.image_outlined
                                  : Icons.description_outlined,
                              size: 16,
                              color: const Color(0xFF5F80F8),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width *
                                        0.55,
                              ),
                              child: Text(
                                vm.pendingAttachment!.name,
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
                                  vm.setPendingAttachment(null),
                              child: const Icon(Icons.close,
                                  size: 14,
                                  color: Color(0xFF5F80F8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Input box ──────────────────────────────────────
                ChatBox(
                  hintText: 'Ask Something ...',
                  showPlusButton: true,
                  onSend: _onSend,
                  onUploadImage: _pickImage,
                  onUploadDoc: _pickDocument,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Welcome screen ─────────────────────────────────────────────────────────
  Widget _buildWelcomeScreen(ChatViewModel vm, TextTheme textTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/icons/lapo_robot.png'),
        const SizedBox(height: 20),
        Text(
          vm.greeting,
          style: textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 40),
        ...ChatViewModel.suggestions.map(
          (s) => ChatbotCard(
            title: s,
            onPressed: () => _onSuggestionTap(s),
          ),
        ),
      ],
    );
  }

  // ── Chat list ──────────────────────────────────────────────────────────────
  Widget _buildChatList(ChatViewModel vm, TextTheme textTheme) {
    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: vm.items.length,
      itemBuilder: (context, index) {
        final item = vm.items[vm.items.length - 1 - index];
        return switch (item) {
          MessageItem(:final message) when message.ticketData != null =>
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 4),
                child: _TicketCard(
                  ticket: TicketItem(
                    ticketId: (message.ticketData!['ticketId'] ?? '')
                        .toString(),
                    category: (message.ticketData!['category'] ?? '')
                        .toString(),
                    status: (message.ticketData!['status'] ??
                            'submitted')
                        .toString(),
                    expectedFixDate:
                        (message.ticketData!['expectedFixDate'] ?? '')
                            .toString(),
                    title:
                        (message.ticketData!['title'] ?? '').toString(),
                    description:
                        (message.ticketData!['description'] ?? '')
                            .toString(),
                    location:
                        (message.ticketData!['location'] ?? '')
                            .toString(),
                  ),
                ),
              ),
            ),
          MessageItem(:final message) =>
            _ChatBubble(message: message),
          DateHeaderItem(:final sessionTime) =>
            _SessionDivider(time: sessionTime),
          TicketItem() => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 4),
                child: _TicketCard(ticket: item),
              ),
            ),
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
    return '$h:$m  ${time.day} ${_months[time.month]} ${time.year}';
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
          const Expanded(
              child: Divider(color: Colors.white54, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_format(), style: labelStyle),
          ),
          const Expanded(
              child: Divider(color: Colors.white54, thickness: 1)),
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

  TextStyle _baseStyle(TextTheme tt, {required bool isUser}) =>
      (isUser ? tt.bodyLarge! : tt.bodyMedium!).copyWith(
        fontSize: 15,
        height: 1.5,
        letterSpacing: 0.1,
        color: AppTheme.textPrimary,
        fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
      );

  TextStyle _boldStyle(TextTheme tt) => tt.titleLarge!.copyWith(
        fontSize: 15,
        height: 1.5,
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
      );

  Widget _buildMessageBody(TextTheme tt, {required bool isUser}) {
    final base = _baseStyle(tt, isUser: isUser);
    final bold = _boldStyle(tt);
    final text = message.displayText;
    if (!text.contains('**')) return Text(text, style: base);

    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final match in _boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
            TextSpan(text: text.substring(lastEnd, match.start), style: base));
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
    final tt = Theme.of(context).textTheme;
    final notice = message.disruptionNotice;

    if (!isUser && notice != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88),
          child: DisruptionNoticeCard(notice: notice),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              Colors.white.withValues(alpha: isUser ? 0.95 : 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12)),
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
            if (message.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.imageUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: AppTheme.surfaceGrey,
                    child: const Icon(Icons.broken_image,
                        color: AppTheme.textSecondary),
                  ),
                ),
              ),
              if (message.displayText.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.displayText.isNotEmpty)
              _buildMessageBody(tt, isUser: isUser),
            if (message.showReportButton) ...[
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Report Issue',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const IssueReportingPage()),
                ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          builder: (_, _) => Row(
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
          ),
        ),
      ),
    );
  }
}

// ── Ticket card ───────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final TicketItem ticket;
  const _TicketCard({required this.ticket});

  static const _statusOrder = ['submitted', 'in_progress', 'resolved'];

  int get _stepIndex {
    final s = ticket.status.toLowerCase().replaceAll(' ', '_');
    final i = _statusOrder.indexOf(s);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final step = _stepIndex;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF5F80F8), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticket: #${ticket.ticketId}',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          Text('Category: ${ticket.category}',
              style:
                  const TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFFD1D5DB), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 16),
                _ProgressTracker(currentStep: step),
                if (ticket.expectedFixDate != null &&
                    ticket.expectedFixDate!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF4B5563)),
                      children: [
                        const TextSpan(
                            text: 'Expected Fix Date: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        TextSpan(text: ticket.expectedFixDate),
                      ],
                    ),
                  ),
                ],
                if (ticket.title != null &&
                    ticket.title!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(ticket.title!,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.bold)),
                ],
                if (ticket.description != null &&
                    ticket.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(ticket.description!,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF6B7280)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
                if (ticket.location != null &&
                    ticket.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 20, color: Color(0xFFFF0000)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(ticket.location!,
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF000000))),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress tracker ──────────────────────────────────────────────────────────
class _ProgressTracker extends StatelessWidget {
  final int currentStep;
  const _ProgressTracker({required this.currentStep});

  static const _labels = ['Submitted', 'In Progress', 'Completed'];
  static const _green = Color(0xFF4CAF50);
  static const _yellow = Color(0xFFFFC107);
  static const _grey = Color(0xFFBDBDBD);

  Color _nodeColor(int step) {
    if (step < currentStep) return _green;
    if (step == currentStep) {
      return step == 2 ? _green : (step == 1 ? _yellow : _green);
    }
    return _grey;
  }

  Color _lineColor(int afterStep) =>
      afterStep < currentStep ? _green : _grey;

  Widget _node(int step) {
    final color = _nodeColor(step);
    final done = step < currentStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: color),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          _labels[step],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color == _grey ? _grey : const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _line(int afterStep) => Expanded(
        child: Container(
          height: 3,
          margin: const EdgeInsets.only(bottom: 40),
          color: _lineColor(afterStep),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _node(0), _line(0), _node(1), _line(1), _node(2),
        ],
      );
}
