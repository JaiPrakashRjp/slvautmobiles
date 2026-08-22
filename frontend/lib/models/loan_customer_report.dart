/// A complete loan statement for one customer — all their loans, each loan's
/// EMI schedule, and headline totals. Built in the loan report screen and
/// rendered both on-screen (preview) and as a downloadable PDF.
class LoanCustomerReport {
  const LoanCustomerReport({
    required this.customerName,
    required this.phone,
    required this.branch,
    required this.address,
    this.assurityName,
    this.assurityMobile,
    required this.totalLoaned,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.totalPenalty,
    required this.loans,
  });

  final String customerName;
  final String phone;
  final String branch;
  final String address;
  final String? assurityName;
  final String? assurityMobile;

  final int totalLoaned;
  final int totalPaid;
  final int totalOutstanding;
  final int totalPenalty;

  final List<LoanReportLoan> loans;

  int get loanCount => loans.length;
}

class LoanReportLoan {
  const LoanReportLoan({
    required this.vehicleLabel,
    required this.principal,
    required this.emiAmount,
    required this.tenureMonths,
    required this.loanDate,
    required this.status,
    required this.paid,
    required this.outstanding,
    required this.penalty,
    required this.emis,
  });

  final String vehicleLabel;
  final int principal;
  final int emiAmount;
  final int tenureMonths;
  final DateTime loanDate;
  final String status;
  final int paid;
  final int outstanding;
  final int penalty;
  final List<LoanReportEmi> emis;
}

class LoanReportEmi {
  const LoanReportEmi({
    required this.seq,
    required this.dueDate,
    required this.amount,
    required this.penalty,
    required this.paid,
    required this.balance,
    required this.status,
    this.receivedDate,
  });

  final int seq;
  final DateTime dueDate;
  final int amount;
  final int penalty;
  final int paid;
  final int balance;
  final String status;
  final DateTime? receivedDate;
}
