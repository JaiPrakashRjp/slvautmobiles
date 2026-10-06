import 'emi.dart';
import 'loan.dart';

/// Aggregated loan data for the business report PDF over a month / custom range.
/// Built on the client from the loaded loans / customers / vehicles. Mirrors the
/// rental report, but loan-shaped: loans BOOKED in the period, EMI amounts
/// COLLECTED in the period, EMIs DUE in the period, and the current outstanding
/// balance across active loans.
///
/// Loans track payments per-EMI (there is no separate payment list with an
/// approval flag like rentals have), so "collected" keys off each EMI's
/// received/paid date and its [amountPaid].
class LoanReport {
  LoanReport({
    required this.from,
    required this.to,
    required this.label,
    required this.loans,
    required this.collections,
    required this.dues,
    required this.duesByCustomer,
    required this.outstandingTotal,
    required this.newCustomerCount,
  });

  final DateTime from; // inclusive start of the period
  final DateTime to; // inclusive end of the period
  final String label; // e.g. "July 2026" or "01–15 Jul 2026"
  final List<LoanReportRow> loans; // loans BOOKED in the period
  final List<LoanCollectionRow> collections; // EMI collected in the period
  final List<LoanDueRow> dues; // EMIs DUE in the period (one row per EMI)
  final List<LoanDueGroupRow> duesByCustomer; // same EMIs, grouped per customer+vehicle
  final int outstandingTotal; // current balance across active loans
  final int newCustomerCount; // customers added in the period

  int get loanCount => loans.length;
  int get disbursedTotal => loans.fold(0, (s, e) => s + e.principal);
  int get collectedTotal => collections.fold(0, (s, e) => s + e.amount);
  int get dueCount => dues.length;
  int get dueTotal => dues.fold(0, (s, e) => s + e.amount);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Aggregates the report from the loaded [loans] over [from]…[to] (inclusive,
  /// date-only). [customerName]/[vehicleLabel] resolve display strings; each
  /// entry of [customerCreatedAt] is a customer's created date (for the new-
  /// customer count). The single source of truth for the monthly screen + tests.
  static LoanReport build({
    required Iterable<Loan> loans,
    required Iterable<DateTime> customerCreatedAt,
    required String Function(String customerId) customerName,
    required String Function(String customerId) customerPhone,
    required String Function(String? vehicleId) vehicleLabel,
    required DateTime from,
    required DateTime to,
    required String label,
  }) {
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    bool inRange(DateTime? d) {
      if (d == null) return false;
      final x = _dateOnly(d);
      return !x.isBefore(start) && !x.isAfter(end);
    }

    final loanRows = <LoanReportRow>[];
    final collections = <LoanCollectionRow>[];
    final dues = <LoanDueRow>[];
    final dueGroups = <String, _DueAcc>{};
    var outstanding = 0;

    for (final l in loans) {
      // Approved, live book only — drop rejected and seized loans (matches the
      // daily report's filter).
      if (!l.isActive || l.loanStatus == 'rejected' || l.isSeized) continue;
      final custName = customerName(l.customerId);
      final custPhone = customerPhone(l.customerId);
      final vlabel = vehicleLabel(l.vehicleId);

      if (!l.isClosed) outstanding += l.balanceOutstanding;

      if (inRange(l.disbursementDate)) {
        loanRows.add(LoanReportRow(
          date: l.disbursementDate,
          customerName: custName,
          vehicle: vlabel,
          principal: l.principal,
          tenureMonths: l.tenureMonths,
          emiAmount: l.emiAmount,
        ));
      }

      for (final emi in l.emis) {
        final paidOn = emi.receivedDate ?? emi.paidDate;
        if (emi.amountPaid > 0 && inRange(paidOn)) {
          collections.add(LoanCollectionRow(
            date: paidOn ?? l.createdAt,
            customerName: custName,
            vehicle: vlabel,
            emiNumber: emi.sequenceNumber,
            amount: emi.amountPaid,
          ));
        }
        if (inRange(emi.dueDate)) {
          final status = emi.isPaid
              ? 'Paid'
              : emi.isPartial
                  ? 'Partial'
                  : 'Pending';
          dues.add(LoanDueRow(
            date: emi.dueDate,
            customerName: custName,
            vehicle: vlabel,
            emiNumber: emi.sequenceNumber,
            amount: emi.totalDue,
            status: status,
          ));

          // Group the same EMIs per customer+vehicle so the PDF can show
          // "3 × ₹1,000" instead of one row per EMI.
          final key = '${l.customerId}|${l.vehicleId ?? ''}';
          final acc = dueGroups.putIfAbsent(
            key,
            () => _DueAcc(date: emi.dueDate, phone: custPhone, vehicle: vlabel),
          );
          acc.add(emi.dueDate, emi.totalDue);
        }
      }
    }
    loanRows.sort((a, b) => a.date.compareTo(b.date));
    collections.sort((a, b) => a.date.compareTo(b.date));
    dues.sort((a, b) => a.date.compareTo(b.date));
    final duesByCustomer = [
      for (final acc in dueGroups.values) acc.toRow(),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return LoanReport(
      from: start,
      to: end,
      label: label,
      loans: loanRows,
      collections: collections,
      dues: dues,
      duesByCustomer: duesByCustomer,
      outstandingTotal: outstanding,
      newCustomerCount: customerCreatedAt.where(inRange).length,
    );
  }

  /// EMIs due on [date] across live loans (approved, not seized) — the daily-
  /// report rows, as (loan, emi) pairs. Single source of truth for the daily
  /// screen + tests.
  static List<(Loan, Emi)> emisDueOn(Iterable<Loan> loans, DateTime date) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final out = <(Loan, Emi)>[];
    for (final l in loans) {
      if (!l.isActive || l.isSeized) continue;
      for (final e in l.emis) {
        if (sameDay(e.dueDate, date)) out.add((l, e));
      }
    }
    return out;
  }
}

class LoanReportRow {
  LoanReportRow({
    required this.date,
    required this.customerName,
    required this.vehicle,
    required this.principal,
    required this.tenureMonths,
    required this.emiAmount,
  });

  final DateTime date; // loan disbursement date
  final String customerName;
  final String vehicle;
  final int principal;
  final int tenureMonths;
  final int emiAmount;
}

class LoanCollectionRow {
  LoanCollectionRow({
    required this.date,
    required this.customerName,
    required this.vehicle,
    required this.emiNumber,
    required this.amount,
  });

  final DateTime date; // EMI received / paid date
  final String customerName;
  final String vehicle;
  final int emiNumber; // 1-based EMI sequence
  final int amount; // amount collected for that EMI
}

/// Accumulator used only while grouping [LoanDueRow]s per customer+vehicle.
class _DueAcc {
  _DueAcc({required this.date, required this.phone, required this.vehicle});

  DateTime date; // earliest due date in the group
  final String phone;
  final String vehicle;
  int count = 0;
  int total = 0;
  int? amount; // the per-EMI amount, when every EMI in the group matches

  void add(DateTime dueDate, int dueAmount) {
    if (dueDate.isBefore(date)) date = dueDate;
    count += 1;
    total += dueAmount;
    amount = (count == 1 || amount == dueAmount) ? dueAmount : null;
  }

  LoanDueGroupRow toRow() => LoanDueGroupRow(
        date: date,
        customerPhone: phone,
        vehicle: vehicle,
        count: count,
        perEmiAmount: amount,
        total: total,
      );
}

/// EMIs due in the period, grouped per customer+vehicle — e.g. 3 pending EMIs
/// of ₹1,000 each renders as "3 × ₹1,000" with a ₹3,000 total, instead of 3
/// separate rows.
class LoanDueGroupRow {
  LoanDueGroupRow({
    required this.date,
    required this.customerPhone,
    required this.vehicle,
    required this.count,
    required this.perEmiAmount,
    required this.total,
  });

  final DateTime date; // earliest due date in the group
  final String customerPhone;
  final String vehicle;
  final int count; // number of EMIs due
  final int? perEmiAmount; // null when the EMIs in the group differ in amount
  final int total; // sum of all EMI amounts in the group
}

class LoanDueRow {
  LoanDueRow({
    required this.date,
    required this.customerName,
    required this.vehicle,
    required this.emiNumber,
    required this.amount,
    required this.status,
  });

  final DateTime date; // EMI due date
  final String customerName;
  final String vehicle;
  final int emiNumber;
  final int amount; // EMI + penalty owed
  final String status; // 'Paid' | 'Partial' | 'Pending'
}
