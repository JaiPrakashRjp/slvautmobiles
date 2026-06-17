import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Channels a customer-facing message can go out on.
enum NotificationChannel { whatsapp, sms }

/// Sends customer-facing reminders/receipts over WhatsApp + SMS.
///
/// Mock-first: the [MockNotificationService] logs to the console and opens the
/// platform deep link (wa.me / sms:) when possible. Phase 7 swaps in a
/// provider (MSG91 / Gupshup) called from a Cloud Function.
abstract class NotificationService {
  Future<void> send({
    required String phone,
    required String message,
    NotificationChannel channel = NotificationChannel.whatsapp,
  });

  /// Convenience: "₹{amount} due on {date}" reminder template (spec 11.2).
  Future<void> paymentReminder({
    required String phone,
    required String name,
    required String amount,
    required String dueDate,
    bool overdue = false,
  });
}

class MockNotificationService implements NotificationService {
  const MockNotificationService();

  /// Normalises a +91/10-digit number to the `91XXXXXXXXXX` wa.me form.
  static String _waNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final ten = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return '91$ten';
  }

  @override
  Future<void> send({
    required String phone,
    required String message,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    final uri = switch (channel) {
      NotificationChannel.whatsapp => Uri.parse(
          'https://wa.me/${_waNumber(phone)}?text=${Uri.encodeComponent(message)}'),
      NotificationChannel.sms => Uri.parse(
          'sms:$phone?body=${Uri.encodeComponent(message)}'),
    };
    debugPrint('[notification] ${channel.name} → $phone: $message');
    debugPrint('[notification] deep link: $uri');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[notification] launch failed (mock continues): $e');
    }
  }

  @override
  Future<void> paymentReminder({
    required String phone,
    required String name,
    required String amount,
    required String dueDate,
    bool overdue = false,
  }) {
    final message = overdue
        ? 'Reminder: your payment of $amount was due on $dueDate. '
            'Please pay soon to avoid further penalty. — SLV Auto Consultant'
        : 'Namaste $name, your payment of $amount is due on $dueDate. '
            'Please pay to avoid penalty. — SLV Auto Consultant';
    return send(phone: phone, message: message);
  }
}
