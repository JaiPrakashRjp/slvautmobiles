import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/auto_sale/sale_detail_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/users/pending_approvals_screen.dart';
import '../utils/navigator_key.dart';

const _kChannelId   = 'slv_approvals';
const _kChannelName = 'Pending Approvals';
const _kDesc        = 'Admin actions awaiting your review';

/// Payload marking an "update available" notification, so tapping it routes to
/// the login screen (where the update gate lives) instead of pending approvals.
const kUpdatePayload = 'update';

final _plugin = FlutterLocalNotificationsPlugin();

/// Called when the user taps a notification while the app is in the background
/// (but not killed). Must be a top-level function.
@pragma('vm:entry-point')
void onBackgroundNotificationTap(NotificationResponse response) {
  _routeForTap(response);
}

/// Routes a notification tap by its payload: update notifications go to the
/// login screen; everything else (approvals) goes to the review queue.
void _routeForTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == kUpdatePayload) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  } else if (payload != null && payload.startsWith('reminder:')) {
    // Reminder tap → open that sale so staff can call + record the payment.
    final saleId = payload.substring('reminder:'.length);
    if (saleId.isNotEmpty) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: saleId)),
      );
    }
  } else {
    _openPendingApprovals();
  }
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
      onDidReceiveNotificationResponse: _routeForTap,
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
    String? payload,
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
      payload: payload,
    );
  }
}
