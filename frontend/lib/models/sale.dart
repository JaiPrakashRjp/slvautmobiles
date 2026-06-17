import 'enums.dart';
import 'gated_entity.dart';
import 'installment.dart';

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
    this.customerWhatsapp = '',
    this.invoiceNo,
    this.closedAt,
    List<Installment>? installments,
    this.saleStatus = 'active',
    this.invoicePath,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    this.unsellReason,
  }) : installments = installments ?? [];

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

  // Fields added for the real API flow:
  DateTime? saleDate;
  String customerWhatsapp;
  String? invoiceNo;
  DateTime? closedAt;

  List<Installment> installments;

  /// 'active' | 'closed' | 'cancelled' | 'rejected'
  String saleStatus;
  String? invoicePath;

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
