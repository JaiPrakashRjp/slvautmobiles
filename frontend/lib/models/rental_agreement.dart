import 'enums.dart';
import 'gated_entity.dart';
import 'installment.dart';
import 'sale_payment.dart';

/// A vehicle rented to a customer: a total to be collected, an advance, and a
/// remaining balance that drops as rent payments come in. Mirrors [Sale]; gated
/// like every other entity. (Named RentalAgreement to avoid clashing with the
/// legacy mock `Rental` model.)
class RentalAgreement with GatedEntity {
  RentalAgreement({
    required this.id,
    required this.vehicleId,
    required this.customerId,
    this.rentalType,
    this.periodAmount = 0,
    this.totalAmount = 0,
    this.advance = 0,
    this.remainingAmount = 0,
    this.startDate,
    this.invoiceNo,
    this.remarks,
    this.oldBalance = 0,
    this.oldBalanceDate,
    List<Installment>? installments,
    List<SalePayment>? payments,
    this.rentalStatus = 'active',
    this.completedAt,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    this.seizedAt,
    this.seizedBy,
    this.seizeReason,
    this.seizeStage,
    this.seizeConfirmedAt,
    this.seizeConfirmRemarks,
    this.seizeCancelRemarks,
    this.pendingEdit,
    this.editStage,
    this.editRequestedBy,
  })  : installments = installments ?? [],
        payments = payments ?? [];

  @override
  final String id;
  final String vehicleId;
  final String customerId;

  /// Recurring rent cadence: 'weekly' | 'daily' (null = legacy balance rental).
  String? rentalType;

  /// Rent charged per period (per week or per day) for recurring rentals.
  int periodAmount;

  int totalAmount;
  int advance;
  int remainingAmount;
  DateTime? startDate;

  /// A recurring rent rental (weekly/daily) vs the legacy total/remaining model.
  bool get isRecurring => rentalType != null;
  String? invoiceNo;
  String? remarks;

  /// Carried-forward balance recorded for reference only (display; no reminder).
  int oldBalance;
  DateTime? oldBalanceDate;

  List<Installment> installments;
  List<SalePayment> payments;

  /// 'active' | 'completed' | 'cancelled' | 'seized'
  String rentalStatus;
  DateTime? completedAt;

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

  // Seizure (repossession)
  DateTime? seizedAt;
  String? seizedBy;
  String? seizeReason;
  String? seizeStage; // null | 'pending' | 'seized' | 'confirmed'
  DateTime? seizeConfirmedAt;
  String? seizeConfirmRemarks;
  String? seizeCancelRemarks;

  bool get isSeizePending => seizeStage == 'pending';
  bool get isSeizeActive => seizeStage == 'seized';
  bool get isSeizeConfirmed => seizeStage == 'confirmed';

  // Edit approval (admin edit awaiting super-admin approval)
  Map<String, dynamic>? pendingEdit;
  String? editStage;
  String? editRequestedBy;
  bool get isEditPending => editStage == 'pending';

  bool get isCompleted => rentalStatus == 'completed';
  bool get isOngoing => rentalStatus == 'active';

  /// The pending (awaiting-approval) payment for an installment, if any.
  SalePayment? pendingPaymentFor(String installmentId) => payments
      .where((p) => p.installmentId == installmentId && p.isPending)
      .cast<SalePayment?>()
      .firstOrNull;

  int get collected =>
      advance + payments.where((p) => p.isApproved).fold(0, (s, p) => s + p.amount);
}
