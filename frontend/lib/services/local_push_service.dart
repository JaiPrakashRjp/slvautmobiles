import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/users/pending_approvals_screen.dart';
import '../utils/navigator_key.dart';

const _kChannelId   = 'slv_approvals';
const _kChannelName = 'Pending Approvals';
const _kDesc        = 'Admin actions awaiting your review';

final _plugin = FlutterLocalNotificationsPlugin();

/// Called when the user taps a notification while the app is in the background
/// (but not killed). Must be a top-level function.
@pragma('vm:entry-point')
void onBackgroundNotificationTap(NotificationResponse response) {
  _openPendingApprovals();
}

void _openPendingApprovals() {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
  );
}

/// Thin wrapper around [FlutterLocalNotificationsPlugin].
/// Call [LocalPushService.init] once in main() before runApp.
class LocalPushService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _openPendingApprovals(),
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTap,
    );

    // Create the Android notification channel.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: _kDesc,
          importance: Importance.high,
        ));

    // Ask for POST_NOTIFICATIONS permission on Android 13+.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
