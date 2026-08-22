/// One monthly EMI of a [PersonalLoan] — a flat amount, simply marked paid.
class PersonalLoanEmi {
  PersonalLoanEmi({
    required this.id,
    required this.sequenceNumber,
    required this.dueDate,
    required this.amount,
    this.status = 'pending',
    this.paidDate,
  });

  final String id;
  final int sequenceNumber; // 1-based
  final DateTime dueDate;
  final int amount;
  String status; // 'pending' | 'paid'
  DateTime? paidDate;

  bool get isPaid => status == 'paid';
}
