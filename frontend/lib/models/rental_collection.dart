import 'enums.dart';

/// One billing-cycle collection for a [Rental] (a day / week / month of rent).
class RentalCollection {
  RentalCollection({
    required this.id,
    required this.cycleNumber,
    required this.dueDate,
    required this.amount,
    this.paidDate,
    this.penalty = 0,
    this.reminderSent = false,
  });

  final String id;
  final int cycleNumber; // 1-based (Week 1, Month 1, Day 1 ...)
  final DateTime dueDate;
  final int amount;
  DateTime? paidDate;
  int penalty;
  bool reminderSent;

  bool get isPaid => paidDate != null;

  ScheduleStatus statusAt(DateTime now) {
    if (isPaid) return ScheduleStatus.paid;
    final days = DateTime(dueDate.year, dueDate.month, dueDate.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days < 0) return ScheduleStatus.overdue;
    if (days == 0) return ScheduleStatus.dueSoon;
    return ScheduleStatus.upcoming;
  }
}
