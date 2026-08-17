/// A printable dues statement for one rental customer: headline totals plus a
/// per-rental, per-reminder breakdown. Built by the Customer-dues screen and
/// rendered to PDF by PdfService (mirrors the report models).
class RentalCustomerStatement {
  RentalCustomerStatement({
    required this.customerName,
    required this.customerPhone,
    required this.totalPending,
    required this.totalCollected,
    required this.activeRentals,
    required this.openReminders,
    required this.overdue,
    required this.awaitingApproval,
    required this.rentals,
  });

  final String customerName;
  final String customerPhone;
  final int totalPending;
  final int totalCollected;
  final int activeRentals;
  final int openReminders;
  final int overdue;
  final int awaitingApproval;
  final List<RentalStatementRow> rentals;
}

class RentalStatementRow {
  RentalStatementRow({
    required this.vehicle,
    required this.invoice,
    required this.status,
    required this.rentLabel,
    required this.collected,
    required this.pending,
    required this.reminders,
  });

  final String vehicle;
  final String invoice;
  final String status; // Active / Ended / Seized / Pending approval
  final String rentLabel; // "₹500 / week" or '' for legacy rentals
  final int collected;
  final int pending;
  final List<StatementReminderRow> reminders;
}

class StatementReminderRow {
  StatementReminderRow({
    required this.dueDate,
    required this.remaining,
    required this.paid,
    required this.overdue,
  });

  final DateTime dueDate;
  final int remaining;
  final int paid;
  final bool overdue;
}
