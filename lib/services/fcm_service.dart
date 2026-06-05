import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/announcement/announcement_detail_page.dart';
import '../features/status_tracker/details/views/issue_notification_page.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationNavigation,
    );

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _scheduleNavigation(initialMessage);
    }

    await _messaging.setAutoInitEnabled(true);
    await _requestPermission();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(_saveCurrentToken(user.uid));
      }
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(_saveToken(user.uid, token));
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _saveCurrentToken(user.uid);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (_) {
      // Permission prompts are platform-specific; token save will simply fail if
      // messaging is unavailable on the current target.
    }
  }

  Future<void> _saveCurrentToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }
    } catch (_) {
      // Some platforms need extra messaging setup, such as a web VAPID key.
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmPlatform': defaultTargetPlatform.name,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (!_isAnnouncementMessage(message) && !_isIssueStatusMessage(message)) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? 'New notification';
    final body = message.notification?.body ?? 'Tap to view the details.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _handleNotificationNavigation(message),
        ),
      ),
    );
  }

  void _scheduleNavigation(RemoteMessage message, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationNavigation(message, attempt: attempt + 1);
    });
  }

  void _handleNotificationNavigation(RemoteMessage message, {int attempt = 0}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (attempt < 20) {
        _scheduleNavigation(message, attempt: attempt);
      }
      return;
    }

    if (_isIssueStatusMessage(message)) {
      final issueId = _firstDataValue(message, const [
        'issueId',
        'issue_id',
        'docId',
        'id',
      ]);
      if (issueId.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => IssueNotificationPage(issueId: issueId),
        ),
      );
      return;
    }

    if (!_isAnnouncementMessage(message)) return;

    final announcementId = _firstDataValue(message, const [
      'announcementId',
      'announcement_id',
      'docId',
      'id',
    ]);
    if (announcementId.isEmpty) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailPage(docId: announcementId),
      ),
    );
  }

  bool _isAnnouncementMessage(RemoteMessage message) {
    return message.data['type'] == 'announcement' ||
        message.data['type'] == 'announcement_detail' ||
        message.data['route'] == 'announcement' ||
        message.data['route'] == 'announcement_detail';
  }

  bool _isIssueStatusMessage(RemoteMessage message) {
    return message.data['type'] == 'issue_status_update' ||
        message.data['type'] == 'issue_detail' ||
        message.data['route'] == 'issue_detail';
  }

  String _firstDataValue(RemoteMessage message, List<String> keys) {
    for (final key in keys) {
      final value = message.data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
}
