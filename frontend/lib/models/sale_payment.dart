/// A recorded installment payment, with its approval status + proof screenshots.
class SalePayment {
  SalePayment({
    required this.id,
    this.installmentId,
    required this.amount,
    required this.status,
    this.documentIds = const [],
    this.rejectionReason,
    this.paidAt,
    this.kind,
  });

  final String id;
  final String? installmentId;
  final int amount;

  /// 'pending_confirmation' | 'active' (approved) | 'rejected' (declined)
  final String status;
  final List<int> documentIds; // proof screenshot ids
  final String? rejectionReason;

  /// When the payment was actually made (from the backend).
  final DateTime? paidAt;

  /// 'installment' | 'advance' | 'early_payoff'. A manual payment is 'advance'
  /// and has no [installmentId].
  final String? kind;

  bool get isPending => status == 'pending_confirmation';
  bool get isApproved => status == 'active';
  bool get isRejected => status == 'rejected';

  /// A standalone (manual) payment — recorded directly, not against a reminder.
  bool get isManual => installmentId == null;
}
