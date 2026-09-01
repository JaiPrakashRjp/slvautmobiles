import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/loan.dart';
import '../models/vehicle.dart';
import '../services/customer_service.dart';
import '../services/loan_service.dart';
import '../services/vehicle_service.dart';

/// Backs the new-loan form. No interest: the operator types the EMI amount, the
/// tenure (months) and the loan amount; the schedule is EMI × tenure, one EMI a
/// month from the loan date. The loan is booked against a loan customer and a
/// loan vehicle.
class NewLoanViewModel extends ChangeNotifier {
  NewLoanViewModel(this._loans, this._customers, this._vehicles, this._auth,
      {String? initialCustomerId, String? initialVehicleId, Loan? editLoan})
      : _customerId = editLoan?.customerId ?? initialCustomerId,
        _vehicleId = editLoan?.vehicleId ?? initialVehicleId,
        _editLoanId = editLoan?.id,
        _editHasPayments =
            editLoan?.emis.any((e) => e.amountPaid > 0) ?? false,
        _loanDate = editLoan?.disbursementDate {
    if (editLoan != null) {
      principalController.text = '${editLoan.principal}';
      tenureController.text = '${editLoan.tenureMonths}';
      emiController.text = '${editLoan.emiAmount}';
    }
  }

  final LoanService _loans;
  final CustomerService _customers;
  final VehicleService _vehicles;
  final AuthController _auth;

  final principalController = TextEditingController(); // loan amount
  final tenureController = TextEditingController();
  final emiController = TextEditingController();

  String? _customerId;
  String? _vehicleId;
  DateTime? _loanDate;

  /// Non-null when editing an existing loan (within its 5-hour window) rather
  /// than booking a new one.
  final String? _editLoanId;

  /// True when the loan being edited already has recorded payments — the screen
  /// warns that saving wipes them.
  final bool _editHasPayments;

  bool get isEdit => _editLoanId != null;
  bool get editHasPayments => _editHasPayments;

  String? get customerId => _customerId;
  String? get vehicleId => _vehicleId;
  DateTime? get loanDate => _loanDate;

  List<Customer> get verifiedCustomers =>
      _customers.all().where((c) => c.isActive).toList();
  Customer? get customer =>
      _customerId == null ? null : _customers.byId(_customerId!);

  /// Vehicle ids currently tied up in a live loan (active/overdue/pending — not
  /// seized, closed or rejected). These are blocked from a new loan until a
  /// confirm-seize frees the vehicle.
  Set<String> get _onLoanVehicleIds => {
        for (final l in _loans.all())
          if (l.id != _editLoanId && // the edited loan's own vehicle stays selectable
              l.vehicleId != null &&
              !l.isSeized &&
              !l.isClosed &&
              l.loanStatus != 'rejected')
            l.vehicleId!,
      };

  /// Active (verified) loan vehicles that aren't already on a live loan.
  List<Vehicle> get availableVehicles => _vehicles
      .all()
      .where((v) => v.isActive && !_onLoanVehicleIds.contains(v.id))
      .toList();
  Vehicle? get vehicle =>
      _vehicleId == null ? null : _vehicles.byId(_vehicleId!);

  int get principal =>
      int.tryParse(principalController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get tenure => int.tryParse(tenureController.text.trim()) ?? 0;
  int get emiAmount =>
      int.tryParse(emiController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  /// Total repayable across the schedule (no interest) = EMI × tenure.
  int get totalPayable => emiAmount * tenure;

  set customerId(String? v) {
    _customerId = v;
    notifyListeners();
  }

  set vehicleId(String? v) {
    _vehicleId = v;
    notifyListeners();
  }

  set loanDate(DateTime? v) {
    _loanDate = v;
    notifyListeners();
  }

  void refreshPreview() => notifyListeners();

  String? validate() {
    if (_customerId == null) return 'Please select a customer';
    if (_vehicleId == null) return 'Please select the loan vehicle';
    if (_loanDate == null) return 'Pick the loan date';
    if (principal <= 0) return 'Enter the loan amount';
    if (tenure <= 0) return 'Enter the tenure in months';
    if (emiAmount <= 0) return 'Enter the EMI amount';
    return null;
  }

  /// Persists the form. Returns true when the action leaves the loan pending a
  /// Super Admin's confirmation (only possible for a brand-new admin loan; an
  /// edit keeps the loan's existing approval state).
  bool submit() {
    final user = _auth.currentUser!;
    final editId = _editLoanId;
    if (editId != null) {
      _loans.edit(
        editId,
        customerId: _customerId!,
        vehicleId: _vehicleId,
        principal: principal,
        tenureMonths: tenure,
        emiAmount: emiAmount,
        disbursementDate: _loanDate!,
      );
      return false;
    }
    _loans.create(
      actorRole: user.role,
      actorId: user.id,
      customerId: _customerId!,
      vehicleId: _vehicleId,
      principal: principal,
      tenureMonths: tenure,
      emiAmount: emiAmount,
      disbursementDate: _loanDate!,
    );
    return !user.isSuperAdmin;
  }

  @override
  void dispose() {
    principalController.dispose();
    tenureController.dispose();
    emiController.dispose();
    super.dispose();
  }
}
