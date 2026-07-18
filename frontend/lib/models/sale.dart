import 'enums.dart';
import 'gated_entity.dart';
import 'installment.dart';
import 'sale_payment.dart';

/// A vehicle sale to a customer — either full cash or advance + monthly
/// installments. Gated like every other entity.
class Sale with GatedEntity {
  Sale({
    required this.id,
    required this.vehicleId,
    required this.customerId,
    required this.mode,
    this.salePrice,
    this.advance = 0,
    this.monthly = 0,
    this.dueDate,
    this.saleDate,
    this.vehicleAmount = 0,
    this.additionalFitting = 0,
    this.dlCharges = 0,
    this.documentCharges = 0,
    this.otherExpenses = 0,
    this.hpAmount,
    this.remainingAmount = 0,
    this.customerWhatsapp = '',
    this.financerId,
    this.financerName,
    this.invoiceNo,
    this.closedAt,
    List<Installment>? installments,
    List<SalePayment>? payments,
    this.saleStatus = 'active',
    this.invoicePath,
    this.remarks,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    this.unsellReason,
    this.unsellStage,
    this.unsellRequestedBy,
    this.seizedAt,
    this.seizedBy,
    this.seizeReason,
    this.seizeStage,
    this.seizeConfirmedAt,
    this.seizeConfirmRemarks,
    this.seizeCancelRemarks,
    this.sold = false,
    this.pendingEdit,
    this.editStage,
    this.editRequestedBy,
  })  : installments = installments ?? [],
        payments = payments ?? [];

  @override
  final String id;
  final String vehicleId;
  final String customerId;
  PaymentMode mode;
  int? salePrice;

  // Advance + installments terms:
  int advance;
  int monthly; // per-month installment amount
  DateTime? dueDate; // first installment due date

  // Price breakdown (total = salePrice = sum of the five below).
  int vehicleAmount;
  int additionalFitting;
  int dlCharges;
  int documentCharges;
  int otherExpenses;
  // Loan case only:
  int? hpAmount; // HP / loan amount (super admin only)
  int remainingAmount; // typed by the user

  // Fields added for the real API flow:
  DateTime? saleDate;
  String customerWhatsapp;
  int? financerId; // finance company for this sale (optional)
  String? financerName; // its display name, from the API
  String? invoiceNo;
  DateTime? closedAt;

  List<Installment> installments;
  List<SalePayment> payments;

  /// The pending (awaiting-approval) payment for an installment, if any.
  SalePayment? pendingPaymentFor(String installmentId) => payments
      .where((p) => p.installmentId == installmentId && p.isPending)
      .cast<SalePayment?>()
      .firstOrNull;

  /// 'active' | 'closed' | 'cancelled' | 'rejected'
  String saleStatus;
  String? invoicePath;
  String? remarks;

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
  String? unsellReason;

  /// Unsell approval: null | 'pending' (admin requested, awaiting super admin).
  String? unsellStage;
  String? unsellRequestedBy;

  /// An admin requested an unsell that a super admin hasn't approved yet.
  bool get isUnsellPending => unsellStage == 'pending';

  // Seizure (repossession) audit — set on a seized sale (kept as history).
  DateTime? seizedAt;
  String? seizedBy;
  String? seizeReason;

  /// Seize lifecycle: null | 'pending' (admin requested, awaiting super admin) |
  /// 'seized' (active — badge shown, cancel/confirm available) | 'confirmed'.
  String? seizeStage;
  DateTime? seizeConfirmedAt;
  String? seizeConfirmRemarks;
  String? seizeCancelRemarks;

  /// True once the user confirms a fully-paid sale as sold. While false the
  /// Seize button is available; once true it is hidden.
  bool sold;

  /// Admin requested a seize that a super admin hasn't approved yet.
  bool get isSeizePending => seizeStage == 'pending';

  /// Pending edit: an admin proposed changes that a super admin hasn't approved
  /// yet. The live sale keeps its current values; [pendingEdit] holds the
  /// proposed field values (for the approval diff).
  Map<String, dynamic>? pendingEdit;
  String? editStage;
  String? editRequestedBy;

  /// An admin requested an edit that a super admin hasn't approved yet.
  bool get isEditPending => editStage == 'pending';

  /// Seize is active — the 'Seized' badge stage (can be cancelled or confirmed).
  bool get isSeizeActive => seizeStage == 'seized';

  /// Seize has been finalised (badge cleared; vehicle is a plain free vehicle).
  bool get isSeizeConfirmed => seizeStage == 'confirmed';

  /// A sale can be reversed ("unsold") only within this window after creation.
  static const unsellWindow = Duration(days: 1);

  /// Whether the 1-day unsell window is still open. [createdAt] is a UTC
  /// instant, so compare against the current UTC time (the server and phone can
  /// be in different time zones). Mirrors the backend's own check.
  bool get canUnsell =>
      DateTime.now().toUtc().difference(createdAt.toUtc()) < unsellWindow;

  DepositType get depositType =>
      mode == PaymentMode.full ? DepositType.fullCash : DepositType.downPayment;

  int get paidCount => installments.where((i) => i.isPaid).length;
  int get totalInstallments => installments.length;

  int get collected =>
      advance + installments.where((i) => i.isPaid).fold(0, (s, i) => s + i.amount);

  int get outstanding {
    final scheduled = installments.fold(0, (s, i) => s + i.amount);
    final paid = installments.where((i) => i.isPaid).fold(0, (s, i) => s + i.amount);
    return scheduled - paid;
  }
}
