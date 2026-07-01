/// A recorded installment payment, with its approval status + proof screenshots.
class SalePayment {
  SalePayment({
    required this.id,
    this.installmentId,
    required this.amount,
    required this.status,
    this.documentIds = const [],
    this.rejectionReason,
  });

  final String id;
  final String? installmentId;
  final int amount;

  /// 'pending_confirmation' | 'active' (approved) | 'rejected' (declined)
  final String status;
  final List<int> documentIds; // proof screenshot ids
  final String? rejectionReason;

  bool get isPending => status == 'pending_confirmation';
  bool get isApproved => status == 'active';
  bool get isRejected => status == 'rejected';
}
