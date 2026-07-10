import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/users/pending_approvals_screen.dart';
import '../utils/navigator_key.dart';
import 'api_client.dart';
import 'local_push_service.dart';

/// Background/terminated FCM handler — must be a top-level function.
/// Notification messages are shown by the OS automatically, so there is nothing
/// to draw here; kept as a hook for future data-only messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wraps FirebaseMessaging: permission, registering the device token with the
/// backend, and routing when a push arrives/tapped. Unlike [LocalPushService],
/// FCM delivers even when the app is closed.
class PushService {
  static final _fm = FirebaseMessaging.instance;
  static bool _wired = false;

  /// Request permission + wire foreground/tap listeners. Call once at startup.
  static Future<void> init() async {
    await _fm.requestPermission();
    if (_wired) return;
    _wired = true;

    // Foreground: Android doesn't auto-show FCM notifications, so draw one.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      LocalPushService.show(
        id: msg.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: n.title ?? 'Notification',
        body: n.body ?? '',
        payload: msg.data['type'] as String?,
      );
    });

    // Tapped while backgrounded, or launched from a terminated state.
    FirebaseMessaging.onMessageOpenedApp.listen(_route);
    final initial = await _fm.getInitialMessage();
    if (initial != null) _route(initial);

    // Keep the backend token in sync when Firebase rotates it.
    _fm.onTokenRefresh.listen(_sendToken);
  }

  /// Fetch the token and register it with the backend. Call after login.
  static Future<void> registerToken() async {
    try {
      final token = await _fm.getToken();
      if (token != null) await _sendToken(token);
    } catch (_) {/* push is best-effort */}
  }

  /// Remove this device's token (call on sign-out) so a shared phone stops
  /// receiving the previous user's pushes.
  static Future<void> unregister() async {
    try {
      final token = await _fm.getToken();
      if (token != null) {
        await ApiClient().post(
          '/devices/unregister',
          body: {'token': token, 'platform': 'android'},
        );
      }
    } catch (_) {}
  }

  static Future<void> _sendToken(String token) async {
    try {
      await ApiClient().post(
        '/devices/register',
        body: {'token': token, 'platform': 'android'},
      );
    } catch (_) {}
  }

  static void _route(RemoteMessage message) {
    // Route by push type; extend as more types are added.
    if (message.data['type'] == 'verification') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
      );
    }
  }
}
