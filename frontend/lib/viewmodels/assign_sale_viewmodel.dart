import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/enums.dart';
import '../models/financer.dart';
import '../models/vehicle.dart';
import '../services/customer_service.dart';
import '../services/sale_financer_service.dart';
import '../services/sale_service.dart';
import '../services/vehicle_service.dart';

/// Backs the assign-sale (sell vehicle) screen.
///
/// The user enters a price breakdown (vehicle + additional fitting + DL +
/// document + other expenses) which sums to the **Total**, plus a **Down
/// payment**. Full-cash vs down-payment is DERIVED on the server: when the down
/// payment covers the whole total it is full cash; otherwise it is a
/// down-payment / loan sale and the user also enters an HP amount (super admin
/// only) and a typed Remaining amount.
class AssignSaleViewModel extends ChangeNotifier {
  AssignSaleViewModel({
    required this.customerId,
    required CustomerService customers,
    required VehicleService vehicles,
    required SaleService sales,
    required SaleFinancerService financers,
    required AuthController auth,
    String? initialVehicleId,
  })  : _customers = customers,
        _vehicles = vehicles,
        _sales = sales,
        _financers = financers,
        _auth = auth,
        _vehicleId = initialVehicleId,
        vehicleLocked = initialVehicleId != null {
    final phone = customers.byId(customerId)?.phone ?? '';
    if (phone.isNotEmpty) whatsappController.text = phone;
    // Recompute total + loan-field visibility live as amounts change.
    for (final ctl in _amountControllers) {
      ctl.addListener(notifyListeners);
    }
    _financers.refresh().then((_) => notifyListeners());
  }

  final String customerId;
  final CustomerService _customers;
  final VehicleService _vehicles;
  final SaleService _sales;
  final SaleFinancerService _financers;
  final AuthController _auth;

  final vehicleAmountController = TextEditingController();
  final additionalFittingController = TextEditingController();
  final dlChargesController = TextEditingController();
  final documentChargesController = TextEditingController();
  final otherExpensesController = TextEditingController();
  final downPaymentController = TextEditingController();
  final hpAmountController = TextEditingController();
  final remainingController = TextEditingController();
  final whatsappController = TextEditingController();
  final remarksController = TextEditingController();

  late final List<TextEditingController> _amountControllers = [
    vehicleAmountController,
    additionalFittingController,
    dlChargesController,
    documentChargesController,
    otherExpensesController,
    downPaymentController,
  ];

  String? _vehicleId;
  int? _financerId;
  DateTime? _saleDate;
  bool _loading = false;

  final bool vehicleLocked;

  String? get vehicleId => _vehicleId;
  int? get financerId => _financerId;
  DateTime? get saleDate => _saleDate;
  bool get loading => _loading;

  Customer? get customer => _customers.byId(customerId);
  List<Vehicle> get availableVehicles => _vehicles.available();
  Vehicle? get selectedVehicle =>
      _vehicleId == null ? null : _vehicles.byId(_vehicleId!);
  List<Financer> get financers => _financers.all();
  Financer? get selectedFinancer =>
      _financerId == null ? null : _financers.byId(_financerId!);

  /// Only a super admin may enter the HP (loan) amount.
  bool get isSuperAdmin => _auth.currentUser?.isSuperAdmin ?? false;

  int _parse(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  int get vehicleAmount => _parse(vehicleAmountController);
  int get additionalFitting => _parse(additionalFittingController);
  int get dlCharges => _parse(dlChargesController);
  int get documentCharges => _parse(documentChargesController);
  int get otherExpenses => _parse(otherExpensesController);
  int get downPayment => _parse(downPaymentController);
  int get hpAmount => _parse(hpAmountController);
  int get remainingTyped => _parse(remainingController);

  /// Total = sum of the five price components.
  int get total =>
      vehicleAmount +
      additionalFitting +
      dlCharges +
      documentCharges +
      otherExpenses;

  /// Full cash when the down payment covers the whole total.
  bool get isFullCash => total > 0 && downPayment >= total;

  /// Loan case — show HP / remaining fields.
  bool get showLoanFields => total > 0 && downPayment < total;

  set vehicleId(String? v) {
    _vehicleId = v;
    notifyListeners();
  }

  set financerId(int? v) {
    _financerId = v;
    notifyListeners();
  }

  set saleDate(DateTime? v) {
    _saleDate = v;
    notifyListeners();
  }

  String? validate() {
    if (_vehicleId == null) return 'Please select a vehicle';
    if (_saleDate == null) return 'Select the sale date';
    if (total <= 0) return 'Enter the amounts — total must be greater than 0';
    if (downPaymentController.text.trim().isEmpty) {
      return 'Enter the down payment amount';
    }
    if (downPayment > total) {
      return 'Down payment cannot exceed the total (₹$total)';
    }
    return null;
  }

  /// Returns true if the created sale is pending (admin) confirmation.
  Future<bool> submit() async {
    _loading = true;
    notifyListeners();
    try {
      final user = _auth.currentUser!;
      await _sales.create(
        actorRole: user.role,
        actorId: user.id,
        vehicleId: _vehicleId!,
        customerId: customerId,
        saleDate: _saleDate!,
        customerWhatsapp: whatsappController.text.trim(),
        vehicleAmount: vehicleAmount,
        additionalFitting: additionalFitting,
        dlCharges: dlCharges,
        documentCharges: documentCharges,
        otherExpenses: otherExpenses,
        downPayment: downPayment,
        remainingAmount: showLoanFields ? remainingTyped : 0,
        hpAmount:
            (showLoanFields && isSuperAdmin && hpAmount > 0) ? hpAmount : null,
        remarks: remarksController.text.trim().isEmpty
            ? null
            : remarksController.text.trim(),
        financerId: _financerId,
      );
      await _vehicles.update(_vehicleId!, saleStatus: SaleStatus.sold);
      return !user.isSuperAdmin;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final ctl in _amountControllers) {
      ctl.removeListener(notifyListeners);
    }
    vehicleAmountController.dispose();
    additionalFittingController.dispose();
    dlChargesController.dispose();
    documentChargesController.dispose();
    otherExpensesController.dispose();
    downPaymentController.dispose();
    hpAmountController.dispose();
    remainingController.dispose();
    whatsappController.dispose();
    remarksController.dispose();
    super.dispose();
  }
}
