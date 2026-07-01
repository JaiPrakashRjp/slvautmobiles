import 'enums.dart';

/// One scheduled installment / collection reminder of a down-payment [Sale].
class Installment {
  Installment({
    required this.id,
    required this.monthNumber,
    required this.dueDate,
    required this.amount,
    this.paidDate,
    this.penalty = 0,
    this.reminderSent = false,
    this.status = 'pending',
    this.takenBy,
    this.createdBy,
    this.cancelReason,
  });

  final String id;
  final int monthNumber; // 1-based
  final DateTime dueDate;
  final int amount;
  DateTime? paidDate;
  int penalty;
  bool reminderSent;

  /// 'pending' | 'in_progress' | 'paid' | 'cancelled' | 'overdue'
  String status;
  String? takenBy; // admin who claimed the call (lock owner)
  String? createdBy;
  String? cancelReason;

  bool get isPaid => status == 'paid' || paidDate != null;
  bool get isCancelled => status == 'cancelled';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';

  /// Derives the schedule status from paid state and the due date.
  ScheduleStatus statusAt(DateTime now) {
    if (isPaid) return ScheduleStatus.paid;
    final days = DateTime(dueDate.year, dueDate.month, dueDate.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days < 0) return ScheduleStatus.overdue;
    if (days <= 3) return ScheduleStatus.dueSoon;
    return ScheduleStatus.upcoming;
  }
}
