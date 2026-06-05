import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const MethodChannel _foregroundNotificationChannel = MethodChannel(
    'laporfix/foreground_notifications',
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      _foregroundNotificationChannel.setMethodCallHandler(
        _handleNativeNotificationCall,
      );
      await _handleInitialForegroundNotificationTap();
    }

    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationNavigation,
    );

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundSystemNotification,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _scheduleNavigation(initialMessage);
    }

    await _messaging.setAutoInitEnabled(true);
    await _requestPermission();
    await _configureForegroundPresentation();

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

  Future<void> _configureForegroundPresentation() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Android foreground display is handled by the native channel below.
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

  Future<void> _showForegroundSystemNotification(RemoteMessage message) async {
    if (!_isAnnouncementMessage(message) && !_isIssueStatusMessage(message)) {
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) return;

    final title = message.notification?.title ?? 'New notification';
    final body = message.notification?.body ?? 'Tap to view the details.';

    try {
      await _foregroundNotificationChannel.invokeMethod<void>(
        'showForegroundNotification',
        {
          'title': title,
          'body': body,
          'payload': jsonEncode({'data': message.data}),
        },
      );
    } catch (_) {
      // Do not fall back to an in-app banner; foreground notifications should
      // use the platform notification surface only.
    }
  }

  Future<void> _handleNativeNotificationCall(MethodCall call) async {
    if (call.method != 'foregroundNotificationTap') return;

    final payload = call.arguments?.toString();
    if (payload == null || payload.isEmpty) return;

    _handleForegroundNotificationTapPayload(payload);
  }

  Future<void> _handleInitialForegroundNotificationTap() async {
    try {
      final payload = await _foregroundNotificationChannel.invokeMethod<String>(
        'getInitialForegroundNotification',
      );
      if (payload != null && payload.isNotEmpty) {
        _handleForegroundNotificationTapPayload(payload);
      }
    } catch (_) {
      // The method channel exists only on Android.
    }
  }

  void _handleForegroundNotificationTapPayload(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return;
    }

    if (decoded is! Map) return;
    final rawData = decoded['data'];
    if (rawData is! Map) return;

    final data = <String, dynamic>{
      for (final entry in rawData.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    };

    _scheduleDataNavigation(data);
  }

  void _scheduleNavigation(RemoteMessage message, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationNavigation(message, attempt: attempt + 1);
    });
  }

  void _scheduleDataNavigation(Map<String, dynamic> data, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationDataNavigation(data, attempt: attempt + 1);
    });
  }

  void _handleNotificationNavigation(RemoteMessage message, {int attempt = 0}) {
    _handleNotificationDataNavigation(message.data, attempt: attempt);
  }

  void _handleNotificationDataNavigation(
    Map<String, dynamic> data, {
    int attempt = 0,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (attempt < 20) {
        _scheduleDataNavigation(data, attempt: attempt);
      }
      return;
    }

    if (_isIssueStatusData(data)) {
      final issueId = _firstDataValue(data, const [
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

    if (!_isAnnouncementData(data)) return;

    final announcementId = _firstDataValue(data, const [
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
    return _isAnnouncementData(message.data);
  }

  bool _isIssueStatusMessage(RemoteMessage message) {
    return _isIssueStatusData(message.data);
  }

  bool _isAnnouncementData(Map<String, dynamic> data) {
    return data['type'] == 'announcement' ||
        data['type'] == 'announcement_detail' ||
        data['route'] == 'announcement' ||
        data['route'] == 'announcement_detail';
  }

  bool _isIssueStatusData(Map<String, dynamic> data) {
    return data['type'] == 'issue_status_update' ||
        data['type'] == 'issue_detail' ||
        data['route'] == 'issue_detail';
  }

  String _firstDataValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
}
