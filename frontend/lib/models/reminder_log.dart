/// One entry from the reminder_logs table — shows when a WhatsApp nudge was
/// dispatched to the customer or super admin for an installment.
class ReminderLog {
  const ReminderLog({
    required this.id,
    required this.saleId,
    required this.installmentId,
    required this.recipientType,
    required this.recipientPhone,
    required this.channel,
    required this.message,
    required this.dueDate,
    this.sentAt,
    required this.status,
  });

  final int id;
  final int saleId;
  final int? installmentId;
  final String recipientType; // 'customer' | 'super_admin'
  final String recipientPhone;
  final String channel; // 'whatsapp'
  final String message;
  final DateTime dueDate;
  final DateTime? sentAt;
  final String status; // 'pending' | 'sent' | 'failed'

  bool get isSent => status == 'sent';

  factory ReminderLog.fromJson(Map<String, dynamic> j) => ReminderLog(
        id: j['id'] as int,
        saleId: j['sale_id'] as int,
        installmentId: j['installment_id'] as int?,
        recipientType: (j['recipient_type'] as String?) ?? '',
        recipientPhone: (j['recipient_phone'] as String?) ?? '',
        channel: (j['channel'] as String?) ?? 'whatsapp',
        message: (j['message'] as String?) ?? '',
        dueDate:
            DateTime.tryParse((j['due_date'] as String?) ?? '') ?? DateTime.now(),
        sentAt: j['sent_at'] == null
            ? null
            : DateTime.tryParse(j['sent_at'] as String),
        status: (j['status'] as String?) ?? 'pending',
      );
}
