/// One row of the daily reminder/collection report — an installment due on the
/// selected day, with its customer, vehicle and current status.
class DailyReminder {
  DailyReminder({
    required this.installmentId,
    required this.saleId,
    required this.customerName,
    required this.customerPhone,
    this.vehicleReg,
    required this.amount,
    required this.status,
    this.takenByName,
    this.paidDate,
  });

  final int installmentId;
  final int saleId;
  final String customerName;
  final String customerPhone;
  final String? vehicleReg;
  final int amount;

  /// 'pending' | 'in_progress' | 'paid' | 'cancelled' | 'overdue'
  final String status;
  final String? takenByName;
  final DateTime? paidDate;

  bool get isPaid => status == 'paid';
  bool get isTaken => status == 'in_progress';
  bool get isCancelled => status == 'cancelled';

  factory DailyReminder.fromJson(Map<String, dynamic> j) => DailyReminder(
        installmentId: j['installment_id'] as int,
        saleId: j['sale_id'] as int,
        customerName: (j['customer_name'] as String?) ?? '',
        customerPhone: (j['customer_phone'] as String?) ?? '',
        vehicleReg: j['vehicle_reg'] as String?,
        amount: (j['amount'] as num?)?.round() ?? 0,
        status: (j['status'] as String?) ?? 'pending',
        takenByName: j['taken_by_name'] as String?,
        paidDate: j['paid_date'] == null
            ? null
            : DateTime.tryParse(j['paid_date'] as String),
      );
}
