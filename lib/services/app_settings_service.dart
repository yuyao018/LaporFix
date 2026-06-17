import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const Map<String, Object> defaults = {'urgentAlerts': true, 'statusUpdates': true, 'profileVisibleToCommunity': true, 'lowDataMode': false};

  static const List<String> deprecatedSettingKeys = ['anonymousReportMode', 'includePreciseLocation'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Map<String, dynamic> _settings = Map<String, dynamic>.from(defaults);
  bool _initialized = false;
  bool _isCellular = false;

  Map<String, dynamic> get settings => Map<String, dynamic>.from(_settings);
  bool get urgentAlerts => _boolValue('urgentAlerts');
  bool get statusUpdates => _boolValue('statusUpdates');
  bool get profileVisibleToCommunity => _boolValue('profileVisibleToCommunity');
  bool get lowDataMode => _boolValue('lowDataMode');
  bool get isCellular => _isCellular;
  bool get shouldReduceMedia => lowDataMode || _isCellular;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _authSubscription = _auth.authStateChanges().listen(_listenForUserSettings);

    final connectivity = await _connectivity.checkConnectivity();
    _setConnectivity(connectivity);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_setConnectivity);

    final user = _auth.currentUser;
    if (user != null) {
      _listenForUserSettings(user);
    }
  }

  Future<void> updateSetting(String key, Object value) async {
    if (!defaults.containsKey(key)) {
      throw ArgumentError.value(key, 'key', 'Unknown app setting');
    }

    final next = Map<String, dynamic>.from(_settings)..[key] = value;
    _settings = next;
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.set({
      'appSettings': {key: value},
    }, SetOptions(merge: true));
    await _deleteDeprecatedSettings(userRef);
  }

  Future<void> reset() async {
    _settings = Map<String, dynamic>.from(defaults);
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.set({'appSettings': Map<String, dynamic>.from(defaults)}, SetOptions(merge: true));
    await _deleteDeprecatedSettings(userRef);
  }

  Future<void> disposeService() async {
    await _authSubscription?.cancel();
    await _settingsSubscription?.cancel();
    await _connectivitySubscription?.cancel();
  }

  void _listenForUserSettings(User? user) {
    unawaited(_settingsSubscription?.cancel());

    if (user == null) {
      _settings = Map<String, dynamic>.from(defaults);
      notifyListeners();
      return;
    }

    _settingsSubscription = _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
      final data = snapshot.data();
      final saved = data?['appSettings'];
      final savedSettings = saved is Map ? Map<String, dynamic>.from(saved) : <String, dynamic>{};
      final filteredSettings = <String, dynamic>{};

      for (final key in defaults.keys) {
        if (savedSettings.containsKey(key)) {
          filteredSettings[key] = savedSettings[key];
        }
      }

      _settings = {...Map<String, dynamic>.from(defaults), ...filteredSettings};
      notifyListeners();
    });
  }

  void _setConnectivity(List<ConnectivityResult> results) {
    final isCellular = results.contains(ConnectivityResult.mobile);
    if (_isCellular == isCellular) return;
    _isCellular = isCellular;
    notifyListeners();
  }

  bool _boolValue(String key) {
    final value = _settings[key];
    return value is bool ? value : defaults[key] == true;
  }

  Future<void> _deleteDeprecatedSettings(DocumentReference<Map<String, dynamic>> userRef) {
    return userRef.update({for (final key in deprecatedSettingKeys) 'appSettings.$key': FieldValue.delete()});
  }

  Future<bool> shouldShowAppTour() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return true;
    final appSettings = data['appSettings'];
    if (appSettings is Map && appSettings['showAppTour'] == false) {
      return false;
    }
    return true;
  }

  Future<void> completeAppTour() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'appSettings': {'showAppTour': false},
    }, SetOptions(merge: true));
  }
}
