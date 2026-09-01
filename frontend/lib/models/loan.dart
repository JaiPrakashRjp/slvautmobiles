import 'emi.dart';
import 'enums.dart';
import 'gated_entity.dart';

/// A loan to a customer, repaid via a flat-rate EMI schedule.
class Loan with GatedEntity {
  Loan({
    required this.id,
    required this.customerId,
    this.vehicleId,
    required this.principal,
    this.rate = 0,
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
    this.seizeStage,
    this.seizeReason,
    this.seizedAt,
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

  /// The loan vehicle this loan is booked against (collateral), if any.
  final String? vehicleId;
  final int principal;
  final double rate; // annual % — 0 for typed-EMI loans (no interest)
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

  /// Seizure (repossession): null (none) | 'pending' (admin requested, awaiting
  /// super admin) | 'seized' (confirmed — vehicle repossessed, loan ended).
  String? seizeStage;
  String? seizeReason;
  DateTime? seizedAt;

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

  int get interest => totalInterest(principal, rate, tenureMonths);

  /// Total repayable across the schedule = Σ EMI + Σ penalty. For a typed-EMI
  /// loan (no interest) this is EMI × tenure plus any late penalties.
  int get totalPayableAmount => emis.fold(0, (s, e) => s + e.totalDue);

  int get totalPaid => emis.fold(0, (s, e) => s + e.amountPaid);
  int get balanceOutstanding => emis.fold(0, (s, e) => s + e.remaining);
  int get paidEmis => emis.where((e) => e.isPaid).length;
  int get penaltyAccrued =>
      emis.where((e) => !e.isPaid).fold(0, (s, e) => s + e.penalty);

  Emi? nextDueEmi(DateTime now) {
    final unpaid = emis.where((e) => !e.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaid.isEmpty ? null : unpaid.first;
  }

  /// How long after booking a loan stays editable (schedule + all details).
  static const editWindow = Duration(hours: 5);

  /// True while still inside the 5-hour post-booking edit window AND not seized.
  /// After this the Edit button is hidden (the server enforces it too).
  ///
  /// Compared in UTC on both sides: [createdAt] comes from the server in UTC, so
  /// a naive local comparison would be off by the device's tz offset (e.g. in
  /// IST every loan would look 5.5h old the moment it's booked, hiding the
  /// button immediately).
  bool isEditable([DateTime? now]) {
    if (isSeized || isSeizePending) return false;
    final elapsed = (now ?? DateTime.now()).toUtc().difference(createdAt.toUtc());
    return !elapsed.isNegative && elapsed <= editWindow;
  }

  bool get isClosed => loanStatus == 'closed' || loanStatus == 'foreclosed';

  /// Fully repaid (all EMIs cleared) — shows as "Paid".
  bool get isFullyPaid => loanStatus == 'closed';

  bool get isSeizePending => seizeStage == 'pending';
  bool get isSeized => seizeStage == 'seized' || loanStatus == 'seized';
}
