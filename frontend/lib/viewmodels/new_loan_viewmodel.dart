import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/enums.dart';
import '../models/loan.dart';
import '../services/customer_service.dart';
import '../services/loan_service.dart';

/// Backs the new-loan form with a live EMI/interest preview (spec 8.7.3).
class NewLoanViewModel extends ChangeNotifier {
  NewLoanViewModel(this._loans, this._customers, this._auth);

  final LoanService _loans;
  final CustomerService _customers;
  final AuthController _auth;

  final principalController = TextEditingController();
  final rateController = TextEditingController(text: '12');
  final tenureController = TextEditingController(text: '12');
  final penaltyValueController = TextEditingController(text: '50');

  String? _customerId;
  DateTime? _disbursementDate;
  PenaltyType _penaltyType = PenaltyType.flatPerDay;

  String? get customerId => _customerId;
  DateTime? get disbursementDate => _disbursementDate;
  PenaltyType get penaltyType => _penaltyType;

  List<Customer> get verifiedCustomers =>
      _customers.all().where((c) => c.isActive).toList();
  Customer? get customer =>
      _customerId == null ? null : _customers.byId(_customerId!);

  int get principal =>
      int.tryParse(principalController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  double get rate => double.tryParse(rateController.text.trim()) ?? 0;
  int get tenure => int.tryParse(tenureController.text.trim()) ?? 0;

  // Live preview
  int get emiAmount => Loan.emiFor(principal, rate, tenure);
  int get totalInterest => Loan.totalInterest(principal, rate, tenure);
  int get totalPayable => Loan.totalPayable(principal, rate, tenure);

  set customerId(String? v) {
    _customerId = v;
    notifyListeners();
  }

  set disbursementDate(DateTime? v) {
    _disbursementDate = v;
    notifyListeners();
  }

  set penaltyType(PenaltyType v) {
    _penaltyType = v;
    notifyListeners();
  }

  void refreshPreview() => notifyListeners();

  String? validate() {
    if (_customerId == null) return 'Please select a customer';
    if (principal <= 0) return 'Enter the principal amount';
    if (rate <= 0) return 'Enter the interest rate';
    if (tenure <= 0) return 'Enter the tenure in months';
    if (_disbursementDate == null) return 'Pick the disbursement date';
    return null;
  }

  bool submit() {
    final user = _auth.currentUser!;
    _loans.create(
      actorRole: user.role,
      actorId: user.id,
      customerId: _customerId!,
      principal: principal,
      rate: rate,
      tenureMonths: tenure,
      disbursementDate: _disbursementDate!,
      penaltyType: _penaltyType,
      penaltyValue: num.tryParse(penaltyValueController.text.trim()) ?? 0,
    );
    return !user.isSuperAdmin;
  }

  @override
  void dispose() {
    principalController.dispose();
    rateController.dispose();
    tenureController.dispose();
    penaltyValueController.dispose();
    super.dispose();
  }
}
