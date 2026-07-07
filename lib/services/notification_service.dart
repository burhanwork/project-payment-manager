import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

/// Handles background FCM messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are shown automatically by FCM on iOS
  // You can do silent data processing here if needed
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  /// Global navigator key — set on MaterialApp so notifications can navigate
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Tab indices in HomeShell: 0=Dashboard 1=Projects 2=Payments 3=Approvals 4=Profile
  static const _typeToTabIndex = {
    'project': 1,
    'payment': 2,
    'approval': 3,
    'deletion': 3,
    'project_request': 3,
  };

  /// Updated by HomeShell whenever the bottom tab changes.
  static int _activeTabIndex = 0;
  static void setActiveTab(int index) => _activeTabIndex = index;

  /// HomeShell listens to this to switch tabs on notification tap.
  /// Value is the target tab index; -1 means no pending switch.
  static final tabSwitchNotifier = ValueNotifier<int>(-1);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // iOS channel for local notifications (shown while app is foreground)
  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  static const _notifDetails = NotificationDetails(iOS: _iosDetails);

  Future<void> initialize() async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. Initialize local notifications plugin (if not already done by initializeLocalOnly)
    if (_localInitFuture != null) await _localInitFuture;
    if (!_initialized) {
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(iOS: iosInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = true;
    }

    // 3. Handle foreground messages (show as local notification)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 4. Handle background-to-foreground tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 5. Handle terminated-to-foreground tap (app was closed)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 6. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 7. Upload FCM token to backend (fire-and-forget — getToken() can hang on simulator)
    _uploadToken();

    // 8. Listen for token refresh
    _fcm.onTokenRefresh.listen((token) => _sendTokenToBackend(token));
  }

  Future<void> _uploadToken() async {
    try {
      // Timeout prevents hanging on iOS simulator where APNs is unavailable
      final token = await _fcm.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (_) {
      // Token upload is best-effort
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.post('/auth/fcm-token', {'fcmToken': token});
    } catch (_) {
      // Silently fail — will retry on next app launch
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      _notifDetails,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate based on data payload
    // e.g. message.data['type'] == 'payment' → open payment screen
    // Navigation is handled via a global navigator key (see main.dart)
    final data = message.data;
    _navigateFromNotification(data);
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _navigateFromNotification({'type': payload});
  }

  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final targetTab = _typeToTabIndex[type];
    if (targetTab == null) return;

    // Already on the correct tab with nothing pushed on top
    if (_activeTabIndex == targetTab) return;

    // Pop any pushed routes back to HomeShell, then switch tab
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    tabSwitchNotifier.value = targetTab;
  }

  bool _initialized = false;
  Future<void>? _localInitFuture;

  /// Initialize ONLY the local notifications plugin — no Firebase required.
  /// Stores the Future so showLocalNotification can await it if called early.
  void initializeLocalOnly() {
    if (_initialized || _localInitFuture != null) return;
    _localInitFuture = _doLocalInit();
  }

  Future<void> _doLocalInit() async {
    try {
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(iOS: iosInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = true;
    } catch (_) {}
  }

  /// Show a local notification directly (works on simulators for testing)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    // Ensure local notifications are initialized before showing
    if (_localInitFuture != null) await _localInitFuture;
    if (!_initialized) return;
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        _notifDetails,
        payload: payload,
      );
    } catch (_) {}
  }

  /// Simulate a foreground FCM message (for testing on simulator)
  void simulateForegroundMessage({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    _handleForegroundMessage(RemoteMessage(
      notification: RemoteNotification(title: title, body: body),
      data: Map<String, dynamic>.from(data),
    ));
  }

  /// Called after Firebase completes its async init — sets up messaging
  /// if a user session is already active.
  void initializeIfNeeded() {
    if (ApiClient.token != null) {
      initialize();
    }
  }

  /// Call this after user logs out to remove their token from backend
  Future<void> removeToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiClient.post('/auth/fcm-token/remove', {'fcmToken': token});
      }
      await _fcm.deleteToken();
    } catch (_) {}
  }
}
