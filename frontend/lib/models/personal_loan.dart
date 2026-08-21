import 'personal_loan_emi.dart';

/// A personal loan — simple monthly EMI (no interest, no penalty). Booked
/// against a vehicle number + a personal-loan-scoped financer; reminders go to
/// [phone]; each month is marked paid one at a time.
class PersonalLoan {
  PersonalLoan({
    required this.id,
    required this.vehicleNumber,
    this.financerId,
    this.financerName,
    required this.loanAmount,
    required this.emiAmount,
    required this.tenureMonths,
    required this.loanDate,
    required this.firstDueDate,
    this.phone,
    this.loanStatus = 'active',
    List<PersonalLoanEmi>? emis,
  }) : emis = emis ?? [];

  final String id;
  final String vehicleNumber;
  final int? financerId;
  final String? financerName;
  final int loanAmount;
  final int emiAmount;
  final int tenureMonths;
  final DateTime loanDate;
  final DateTime firstDueDate;
  final String? phone;
  String loanStatus; // 'active' | 'closed'
  List<PersonalLoanEmi> emis;

  int get paidCount => emis.where((e) => e.isPaid).length;
  int get totalPaid => emis.where((e) => e.isPaid).fold(0, (s, e) => s + e.amount);
  int get outstanding =>
      emis.where((e) => !e.isPaid).fold(0, (s, e) => s + e.amount);
  bool get isClosed => loanStatus == 'closed';

  PersonalLoanEmi? nextDue() {
    final unpaid = emis.where((e) => !e.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaid.isEmpty ? null : unpaid.first;
  }
}
