import 'enums.dart';

/// One scheduled installment of an advance+installments [Sale].
class Installment {
  Installment({
    required this.id,
    required this.monthNumber,
    required this.dueDate,
    required this.amount,
    this.paidDate,
    this.penalty = 0,
    this.reminderSent = false,
  });

  final String id;
  final int monthNumber; // 1-based
  final DateTime dueDate;
  final int amount;
  DateTime? paidDate;
  int penalty;
  bool reminderSent;

  bool get isPaid => paidDate != null;

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
