/// A printable statement for one personal loan — the loan details, its whole
/// monthly EMI schedule and headline totals. Built in the personal-loan detail
/// screen and rendered as a branded PDF (Share + Print).
class PersonalLoanReport {
  const PersonalLoanReport({
    required this.vehicleNumber,
    required this.financerName,
    required this.loanAmount,
    required this.emiAmount,
    required this.tenureMonths,
    required this.loanDate,
    required this.paid,
    required this.outstanding,
    required this.status,
    required this.emis,
  });

  final String vehicleNumber;
  final String financerName;
  final int loanAmount;
  final int emiAmount;
  final int tenureMonths;
  final DateTime loanDate;
  final int paid;
  final int outstanding;
  final String status;
  final List<PersonalLoanReportEmi> emis;

  int get paidCount => emis.where((e) => e.paid).length;
}

class PersonalLoanReportEmi {
  const PersonalLoanReportEmi({
    required this.seq,
    required this.dueDate,
    required this.amount,
    required this.paid,
    this.paidDate,
  });

  final int seq;
  final DateTime dueDate;
  final int amount;
  final bool paid;
  final DateTime? paidDate;
}
