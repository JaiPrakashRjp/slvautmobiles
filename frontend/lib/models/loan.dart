import 'emi.dart';
import 'enums.dart';
import 'gated_entity.dart';

/// A loan to a customer, repaid via a flat-rate EMI schedule.
class Loan with GatedEntity {
  Loan({
    required this.id,
    required this.customerId,
    required this.principal,
    required this.rate,
    required this.tenureMonths,
    required this.disbursementDate,
    required this.firstEmiDueDate,
    required this.emiAmount,
    List<Emi>? emis,
    this.penaltyType = PenaltyType.flatPerDay,
    this.penaltyValue = 0,
    this.loanStatus = 'active',
    this.agreementPath,
    this.nocPath,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
  }) : emis = emis ?? [];

  @override
  final String id;
  final String customerId;
  final int principal;
  final double rate; // annual %
  final int tenureMonths;
  final DateTime disbursementDate;
  final DateTime firstEmiDueDate;
  final int emiAmount;
  List<Emi> emis;
  PenaltyType penaltyType;
  num penaltyValue;

  /// 'active' | 'overdue' | 'closed' | 'foreclosed' | 'rejected'
  String loanStatus;
  String? agreementPath;
  String? nocPath;

  @override
  final String createdBy;
  @override
  final DateTime createdAt;
  @override
  EntityStatus status;
  @override
  String? confirmedBy;
  @override
  DateTime? confirmedAt;
  @override
  String? rejectionReason;

  // ---- Flat-rate maths (spec 8.3) -------------------------------------------

  static int totalInterest(int principal, double rate, int tenureMonths) =>
      (principal * (rate / 100) * (tenureMonths / 12)).round();

  static int totalPayable(int principal, double rate, int tenureMonths) =>
      principal + totalInterest(principal, rate, tenureMonths);

  /// Rounded EMI; the final EMI absorbs the rounding difference.
  static int emiFor(int principal, double rate, int tenureMonths) {
    if (tenureMonths <= 0) return 0;
    return (totalPayable(principal, rate, tenureMonths) / tenureMonths).round();
  }

  int get totalPayableAmount => principal + interest;
  int get interest => totalInterest(principal, rate, tenureMonths);

  int get totalPaid => emis.fold(0, (s, e) => s + e.amountPaid);
  int get balanceOutstanding => (totalPayableAmount - totalPaid).clamp(0, totalPayableAmount);
  int get paidEmis => emis.where((e) => e.isPaid).length;
  int get penaltyAccrued => emis.fold(0, (s, e) => s + e.penalty);

  Emi? nextDueEmi(DateTime now) {
    final unpaid = emis.where((e) => !e.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaid.isEmpty ? null : unpaid.first;
  }

  bool get isClosed => loanStatus == 'closed' || loanStatus == 'foreclosed';
}
