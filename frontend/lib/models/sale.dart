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
