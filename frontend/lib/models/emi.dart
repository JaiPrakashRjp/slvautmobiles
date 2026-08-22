import 'enums.dart';

/// One EMI installment of a [Loan]. The month's amount owed is the EMI plus any
/// late [penalty]; part payments accumulate into [amountPaid] until the whole
/// [totalDue] is cleared, at which point the month is [isPaid].
class Emi {
  Emi({
    required this.id,
    required this.sequenceNumber,
    required this.dueDate,
    required this.amountDue,
    this.amountPaid = 0,
    this.penalty = 0,
    this.paidDate,
    this.receivedDate,
    this.remarks,
    this.screenshotName,
    this.screenshotDocId,
  });

  final String id;
  final int sequenceNumber; // 1-based
  final DateTime dueDate;
  final int amountDue;
  int amountPaid;
  int penalty;

  /// Date the month was fully cleared (set once [isPaid]).
  DateTime? paidDate;

  /// Date of the most recent (part) payment received.
  DateTime? receivedDate;

  /// Free-text note captured with the payment.
  String? remarks;

  /// File name of the attached payment screenshot (proof).
  String? screenshotName;

  /// Backend id of the stored payment screenshot (for view / delete). Null when
  /// none is stored yet.
  int? screenshotDocId;

  /// Total owed this month = EMI + any late penalty.
  int get totalDue => amountDue + penalty;

  bool get isPaid => amountPaid >= totalDue;
  bool get isPartial => amountPaid > 0 && amountPaid < totalDue;

  /// Amount still to collect this month (EMI + penalty − paid).
  int get remaining => (totalDue - amountPaid).clamp(0, totalDue);

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
