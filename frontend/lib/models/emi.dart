import 'enums.dart';

/// One EMI installment of a [Loan].
class Emi {
  Emi({
    required this.id,
    required this.sequenceNumber,
    required this.dueDate,
    required this.amountDue,
    this.amountPaid = 0,
    this.penalty = 0,
    this.paidDate,
  });

  final String id;
  final int sequenceNumber; // 1-based
  final DateTime dueDate;
  final int amountDue;
  int amountPaid;
  int penalty;
  DateTime? paidDate;

  bool get isPaid => amountPaid >= amountDue;
  bool get isPartial => amountPaid > 0 && amountPaid < amountDue;
  int get remaining => (amountDue - amountPaid).clamp(0, amountDue);

  /// EMI status derived from paid state and the due date (spec 8.2 / 11.3).
  ScheduleStatus statusAt(DateTime now) {
    if (isPaid) return ScheduleStatus.paid;
    final days = DateTime(dueDate.year, dueDate.month, dueDate.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days < 0) return ScheduleStatus.overdue;
    if (isPartial) return ScheduleStatus.partial;
    if (days <= 5) return ScheduleStatus.dueSoon; // 5-day rule
    return ScheduleStatus.upcoming;
  }
}
