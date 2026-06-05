import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/disruption_notice.dart';
import '../services/chatbot_service.dart';

// ── Chat list item union ──────────────────────────────────────────────────────
sealed class ChatItem {}

class MessageItem extends ChatItem {
  final ChatMessage message;
  MessageItem(this.message);
}

class DateHeaderItem extends ChatItem {
  final DateTime sessionTime;
  DateHeaderItem(this.sessionTime);
}

class TicketItem extends ChatItem {
  final String ticketId;
  final String category;
  final String status;
  final String? expectedFixDate;
  final String? title;
  final String? description;
  final String? location;
  final DateTime? createdAt;

  TicketItem({
    required this.ticketId,
    required this.category,
    required this.status,
    this.expectedFixDate,
    this.title,
    this.description,
    this.location,
    this.createdAt,
  });
}

// ── Pending attachment ────────────────────────────────────────────────────────
enum AttachType { image, doc }

class PendingAttachment {
  final String name;
  final String path;
  final AttachType type;
  const PendingAttachment({
    required this.name,
    required this.path,
    required this.type,
  });
}

// ── ViewModel ─────────────────────────────────────────────────────────────────
class ChatViewModel extends ChangeNotifier {
  final ChatbotService _service;

  ChatViewModel({ChatbotService? service})
      : _service = service ?? ChatbotService();

  // ── State ─────────────────────────────────────────────────────────────────
  final List<ChatItem> items = [];
  String? sessionId;
  bool isLoading = false;
  bool hasStartedChat = false;
  bool isLoadingHistory = false;
  PendingAttachment? pendingAttachment;
  String userArea = '';
  String userState = '';

  static const String reportIssueSuggestion = 'How to report an issue?';
  static const List<String> suggestions = [
    reportIssueSuggestion,
    'Track my existing ticket',
    'Check for water/power cut',
  ];

  // ── Greeting ──────────────────────────────────────────────────────────────
  String get greeting {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final hour = DateTime.now().hour;
    final timeOfDay =
        hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : 'Evening';
    return 'Good $timeOfDay, $name!';
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await fetchUserLocation();
  }

  Future<void> fetchUserLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      userArea = (doc.data()?['area'] ?? '').toString();
      userState = (doc.data()?['state'] ?? '').toString();
      notifyListeners();
    }
  }

  // ── Attachment ────────────────────────────────────────────────────────────
  void setPendingAttachment(PendingAttachment? attachment) {
    pendingAttachment = attachment;
    notifyListeners();
  }

  // ── Send (plain text or with attachment) ─────────────────────────────────
  Future<void> onSend(String text) async {
    if (text.trim().toLowerCase() == '/clear') {
      setPendingAttachment(null);
      await clearAllHistory();
      return;
    }
    final attach = pendingAttachment;
    setPendingAttachment(null);
    await sendMessage(text, attachment: attach);
  }

  Future<void> sendMessage(
    String text, {
    PendingAttachment? attachment,
    bool showReportIssueButton = false,
  }) async {
    final hasText = text.trim().isNotEmpty;
    if (!hasText && attachment == null) return;
    if (isLoading) return;

    String? uploadedImageUrl;
    if (attachment != null && attachment.type == AttachType.image) {
      try {
        uploadedImageUrl = await _uploadChatImage(attachment.path);
      } catch (_) {
        _addErrorMessage(
            'Could not upload image. Please try again.');
        return;
      }
    }

    String displayText = text.trim();
    if (attachment != null && attachment.type == AttachType.doc) {
      final label = '📄 ${attachment.name}';
      displayText = hasText ? '$label\n$displayText' : label;
    }

    hasStartedChat = true;
    items.add(MessageItem(ChatMessage(
      text: displayText,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      imageUrl: uploadedImageUrl,
    )));
    isLoading = true;
    notifyListeners();

    try {
      Map<String, String> result;
      if (attachment != null && attachment.type == AttachType.image) {
        result = await _service.sendVisionMessage(
          imagePath: attachment.path,
          imageUrl: uploadedImageUrl!,
          message: text.trim(),
          sessionId: sessionId,
        );
      } else if (attachment != null && attachment.type == AttachType.doc) {
        result = await _service.sendDocumentMessage(
          documentPath: attachment.path,
          message: text.trim(),
          sessionId: sessionId,
        );
      } else {
        result = await _service.sendMessage(
          message: text.trim(),
          sessionId: sessionId,
        );
      }

      sessionId = result['session_id'];
      items.add(MessageItem(ChatMessage(
        text: result['answer']!,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        showReportButton: showReportIssueButton,
      )));
    } catch (_) {
      _addErrorMessage(
          'Sorry, I could not connect to the server. Please try again.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Disruption check ──────────────────────────────────────────────────────
  Future<void> checkDisruptions() async {
    hasStartedChat = true;
    items.add(MessageItem(ChatMessage(
      text: 'Check for water/power cut',
      role: MessageRole.user,
      timestamp: DateTime.now(),
    )));
    isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .get();

      const disruptionKeywords = [
        'water', 'air', 'bekalan air', 'power', 'electric', 'elektrik',
        'tenaga', 'tnb', 'road', 'jalan', 'highway', 'construction',
        'traffic', 'outage', 'disruption', 'gangguan', 'cut', 'putus',
        'maintenance', 'penyelenggaraan',
      ];

      final area = userArea.toLowerCase();
      final state = userState.toLowerCase();
      final matches = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;

        final target = data['target'] as Map<String, dynamic>? ?? {};
        final location = target['location'] as Map<String, dynamic>? ?? {};
        final annArea = (location['area'] ?? '').toString().toLowerCase();
        final annState = (location['state'] ?? '').toString().toLowerCase();
        final annFull = (location['full'] ?? '').toString().toLowerCase();

        bool locationMatch = area.isEmpty && state.isEmpty;
        if (!locationMatch && area.isNotEmpty) {
          locationMatch = annArea == area ||
              annFull.contains(area) ||
              annArea.contains(area);
        }
        if (!locationMatch && state.isNotEmpty) {
          locationMatch =
              annState == state || annFull.contains(state);
        }
        if (!locationMatch) continue;

        final title = (data['title'] ?? '').toString().toLowerCase();
        final caption = (data['caption'] ?? '').toString().toLowerCase();
        final combined = '$title $caption';
        if (disruptionKeywords.any((kw) => combined.contains(kw))) {
          matches.add(data);
        }
      }

      const userMessage = 'Check for water/power cut';
      final List<Map<String, dynamic>> assistantPayloads;
      final List<ChatMessage> assistantMessages;

      if (matches.isEmpty) {
        final loc = area.isNotEmpty
            ? area
            : state.isNotEmpty
            ? state
            : 'your area';
        final reply =
            '✅ No water, power, or road maintenance announcements found for $loc at the moment.\n\n'
            'If you are experiencing an issue, you can report it directly through the app.';
        assistantPayloads = [
          {'content': reply},
        ];
        assistantMessages = [
          ChatMessage(
              text: reply,
              role: MessageRole.assistant,
              timestamp: DateTime.now()),
        ];
      } else {
        final now = DateTime.now();
        assistantPayloads = [];
        assistantMessages = [];
        for (final data in matches) {
          final notice = DisruptionNotice.fromAnnouncement(data);
          assistantPayloads.add({'disruption_notice': notice.toJson()});
          assistantMessages.add(ChatMessage(
            text: '',
            role: MessageRole.assistant,
            timestamp: now,
            disruptionNotice: notice,
          ));
        }
      }

      items.addAll(assistantMessages.map(MessageItem.new));
      sessionId = await _service.saveTurn(
        userMessage: userMessage,
        assistantMessages: assistantPayloads,
        sessionId: sessionId,
      );
    } catch (_) {
      _addErrorMessage(
          'Sorry, I could not check announcements right now. Please try again.');
      try {
        await _service.saveTurn(
          userMessage: 'Check for water/power cut',
          assistantMessages: [
            {'content': 'Sorry, I could not check announcements right now. Please try again.'},
          ],
          sessionId: sessionId,
        );
      } catch (_) {}
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Ticket check ──────────────────────────────────────────────────────────
  Future<void> checkTickets() async {
    final user = FirebaseAuth.instance.currentUser;

    hasStartedChat = true;
    items.add(MessageItem(ChatMessage(
      text: 'Track my existing ticket',
      role: MessageRole.user,
      timestamp: DateTime.now(),
    )));
    isLoading = true;
    notifyListeners();

    try {
      if (user == null) {
        const reply = 'You need to be logged in to check your tickets.';
        _addAssistantMessage(reply);
        try {
          await _service.saveTurn(
            userMessage: 'Track my existing ticket',
            assistantMessages: [
              {'content': reply},
            ],
            sessionId: sessionId,
          );
        } catch (_) {}
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('issue')
          .where('reporterID', isEqualTo: user.uid)
          .get();

      final docs =
          snapshot.docs.where((doc) {
            final s = (doc.data()['status'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            return s != 'resolved' &&
                s != 'completed' &&
                s != 'closed' &&
                s.isNotEmpty;
          }).toList()
            ..sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              if (ta is Timestamp && tb is Timestamp) {
                return tb.compareTo(ta);
              }
              return 0;
            });

      if (docs.isEmpty) {
        const reply =
            '✅ You have no open tickets at the moment.\n\n'
            'If you have an issue to report, tap the **Report Issue** button to get started.';
        _addAssistantMessage(reply);
        try {
          await _service.saveTurn(
            userMessage: 'Track my existing ticket',
            assistantMessages: [
              {'content': reply},
            ],
            sessionId: sessionId,
          );
        } catch (_) {}
        return;
      }

      final headerText =
          '📋 You have ${docs.length} open ticket${docs.length > 1 ? 's' : ''}:';
      final now = DateTime.now();
      final assistantPayloads = <Map<String, dynamic>>[];

      assistantPayloads.add({'content': headerText});
      items.add(MessageItem(ChatMessage(
        text: headerText,
        role: MessageRole.assistant,
        timestamp: now,
      )));

      for (final doc in docs) {
        final data = doc.data();
        final rawStatus = (data['status'] ?? 'submitted').toString();
        final normStatus = rawStatus.toLowerCase().replaceAll(' ', '_');

        String? fixDate;
        final fixTs = data['estimatedResolutionAt'];
        if (fixTs is Timestamp) {
          final dt = fixTs.toDate();
          const months = [
            '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          fixDate = '${dt.day} ${months[dt.month]} ${dt.year}';
        } else if (fixTs is String && fixTs.isNotEmpty) {
          fixDate = fixTs;
        }

        final ticketId = (data['ticketId'] ?? doc.id.substring(0, 8))
            .toString()
            .toUpperCase();
        final category = (data['category'] ?? 'Issue').toString();
        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final loc = data['location'];
        String location = '';
        if (loc is Map) {
          final h = (loc['heading'] ?? '').toString().trim();
          final p = (loc['postcode'] ?? '').toString().trim();
          location = [h, p].where((s) => s.isNotEmpty).join(', ');
        }

        items.add(TicketItem(
          ticketId: ticketId,
          category: category,
          status: normStatus,
          expectedFixDate: fixDate,
          title: title,
          description: description,
          location: location,
          createdAt: data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        ));

        assistantPayloads.add({
          'content': '',
          'ticket': {
            'ticketId': ticketId,
            'category': category,
            'title': title,
            'description': description,
            'location': location,
            'status': normStatus,
            'expectedFixDate': fixDate ?? '',
          },
        });
      }

      try {
        sessionId = await _service.saveTurn(
          userMessage: 'Track my existing ticket',
          assistantMessages: assistantPayloads,
          sessionId: sessionId,
        );
      } catch (_) {}
    } catch (_) {
      _addErrorMessage(
          'Could not retrieve your tickets right now. Please check the My Reports section directly.');
      try {
        await _service.saveTurn(
          userMessage: 'Track my existing ticket',
          assistantMessages: [
            {'content': 'Could not retrieve your tickets right now. Please check the My Reports section directly.'},
          ],
          sessionId: sessionId,
        );
      } catch (_) {}
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Load history ──────────────────────────────────────────────────────────
  Future<String?> loadHistory() async {
    if (isLoadingHistory) return null;
    isLoadingHistory = true;
    notifyListeners();

    try {
      final sessions = await _service.fetchSessions();
      final pastSessions = sessions
          .where((s) => s.sessionId != sessionId)
          .toList()
          .reversed
          .toList();

      if (pastSessions.isEmpty) {
        isLoadingHistory = false;
        notifyListeners();
        return 'No past sessions found.';
      }

      final allMessages = await Future.wait(
        pastSessions.map((s) => _service.fetchMessages(s.sessionId)),
      );

      final historyItems = <ChatItem>[];
      for (var i = 0; i < pastSessions.length; i++) {
        final session = pastSessions[i];
        final messages = allMessages[i];
        if (messages.isEmpty) continue;
        final sessionTime =
            session.updatedAt ?? session.createdAt ?? messages.first.timestamp;
        historyItems.add(DateHeaderItem(sessionTime));
        historyItems.addAll(messages.map(MessageItem.new));
      }

      if (historyItems.isEmpty) {
        isLoadingHistory = false;
        notifyListeners();
        return 'No messages found in past sessions.';
      }

      hasStartedChat = true;
      items.insertAll(0, historyItems);
    } catch (e) {
      isLoadingHistory = false;
      notifyListeners();
      return 'Could not load history: $e';
    }

    isLoadingHistory = false;
    notifyListeners();
    return null; // null = success
  }

  // ── Load specific session (from ChatHistoryPage) ──────────────────────────
  Future<void> loadSession(ChatSession session) async {
    isLoading = true;
    notifyListeners();

    try {
      final messages = await _service.fetchMessages(session.sessionId);
      sessionId = session.sessionId;
      hasStartedChat = true;
      items
        ..clear()
        ..addAll(messages.map(MessageItem.new));
    } catch (_) {
      _addErrorMessage('Could not load session. Please try again.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Clear all history ─────────────────────────────────────────────────────
  Future<int> clearAllHistory() async {
    if (isLoading) return 0;
    isLoading = true;
    notifyListeners();

    try {
      final count = await _service.clearAllSessions();
      items.clear();
      sessionId = null;
      hasStartedChat = false;
      pendingAttachment = null;
      return count;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Session list (for ChatHistoryPage) ───────────────────────────────────
  Future<List<ChatSession>> fetchSessions() => _service.fetchSessions();

  Future<void> deleteSession(String sessionId) =>
      _service.resetSession(sessionId);

  // ── New chat ──────────────────────────────────────────────────────────────
  void startNewChat() {
    items.clear();
    sessionId = null;
    hasStartedChat = false;
    pendingAttachment = null;
    notifyListeners();
  }

  // ── Image upload ──────────────────────────────────────────────────────────
  Future<String?> _uploadChatImage(String localPath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final fileName = localPath.split(Platform.pathSeparator).last;
    final sessionPart = sessionId ?? 'new';
    final ref = FirebaseStorage.instance.ref().child(
      'chat_images/${user.uid}/$sessionPart/${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _addAssistantMessage(String text) {
    items.add(MessageItem(ChatMessage(
      text: text,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
    )));
    notifyListeners();
  }

  void _addErrorMessage(String text) {
    items.add(MessageItem(ChatMessage(
      text: text,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
    )));
    notifyListeners();
  }
}
