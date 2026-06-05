import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/chat_session.dart';

class ChatbotService {
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  // static const String _baseUrl = 'http://localhost:8000'; // iOS simulator

  final http.Client _client;

  ChatbotService({http.Client? client}) : _client = client ?? http.Client();

  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  /// Send a message and get an AI answer.
  Future<Map<String, String>> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'session_id': sessionId,
            'user_id': _userId,
          }),
        )
        .timeout(const Duration(seconds: 120)); // local LLM needs more time

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'answer': data['answer'] as String,
        'session_id': data['session_id'] as String,
      };
    }
    throw Exception('Backend error ${response.statusCode}: ${response.body}');
  }

  /// Fetch all past sessions for the current user.
  Future<List<ChatSession>> fetchSessions() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/chat/sessions/$_userId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['sessions'] as List<dynamic>;
      return list.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load sessions: ${response.statusCode}');
  }

  /// Fetch all messages for a specific session.
  Future<List<ChatMessage>> fetchMessages(String sessionId) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/chat/sessions/$_userId/$sessionId/messages'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['messages'] as List<dynamic>;
      return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load messages: ${response.statusCode}');
  }

  /// Send a document + optional text to the document endpoint.
  Future<Map<String, String>> sendDocumentMessage({
    required String documentPath,
    String message = '',
    String? sessionId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/chat/document'),
    );
    request.fields['message'] = message;
    request.fields['user_id'] = _userId;
    if (sessionId != null) request.fields['session_id'] = sessionId;
    request.files.add(await http.MultipartFile.fromPath('document', documentPath));

    final streamed = await _client.send(request).timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'answer': data['answer'] as String,
        'session_id': data['session_id'] as String,
      };
    }
    throw Exception('Document backend error ${response.statusCode}: ${response.body}');
  }

  /// Send an image + optional text to the vision endpoint.
  Future<Map<String, String>> sendVisionMessage({
    required String imagePath,
    required String imageUrl,
    String message = '',
    String? sessionId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/chat/vision'),
    );
    request.fields['message'] = message;
    request.fields['user_id'] = _userId;
    request.fields['image_url'] = imageUrl;
    if (sessionId != null) request.fields['session_id'] = sessionId;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await _client.send(request).timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'answer': data['answer'] as String,
        'session_id': data['session_id'] as String,
      };
    }
    throw Exception('Vision backend error ${response.statusCode}: ${response.body}');
  }

  /// Persist a client-generated turn (suggestion cards) without calling the LLM.
  Future<String> saveTurn({
    required String userMessage,
    required List<Map<String, dynamic>> assistantMessages,
    String? sessionId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/chat/save-turn'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_message': userMessage,
            'assistant_messages': assistantMessages,
            'session_id': sessionId,
            'user_id': _userId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['session_id'] as String;
    }
    throw Exception('Save turn failed ${response.statusCode}: ${response.body}');
  }

  /// Delete all chat sessions for the current user (Firestore + backend memory).
  Future<int> clearAllSessions() async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/chat/clear-all'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': _userId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['deleted_count'] as int? ?? 0;
    }
    throw Exception('Clear all failed ${response.statusCode}: ${response.body}');
  }

  /// Clear a session from backend memory and Firestore.
  Future<void> resetSession(String sessionId) async {
    await _client
        .post(
          Uri.parse('$_baseUrl/chat/reset'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'session_id': sessionId}),
        )
        .timeout(const Duration(seconds: 10));
  }
}
