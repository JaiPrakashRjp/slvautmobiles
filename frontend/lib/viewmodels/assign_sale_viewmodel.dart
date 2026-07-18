import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/enums.dart';
import '../models/financer.dart';
import '../models/picked_doc.dart';
import '../models/sale.dart';
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
    Sale? existingSale,
  })  : _customers = customers,
        _vehicles = vehicles,
        _sales = sales,
        _financers = financers,
        _auth = auth,
        _existingSale = existingSale,
        _vehicleId = existingSale?.vehicleId ?? initialVehicleId,
        // Vehicle is fixed both when pre-selected and when editing a sale.
        vehicleLocked = existingSale != null || initialVehicleId != null {
    final phone = customers.byId(customerId)?.phone ?? '';
    if (phone.isNotEmpty) whatsappController.text = phone;
    // Prefill the reg number from the (pre-)selected vehicle, if any.
    final preVehicle = _vehicleId == null ? null : vehicles.byId(_vehicleId!);
    if (preVehicle != null) regNoController.text = preVehicle.regNo;
    // Editing an existing sale → prefill every field from it (overrides the
    // customer-phone default above).
    if (existingSale != null) _prefillFrom(existingSale);
    // Recompute total + loan-field visibility live as amounts change.
    for (final ctl in _amountControllers) {
      ctl.addListener(notifyListeners);
    }
    _financers.refresh().then((_) => notifyListeners());
  }

  /// Prefill all controllers/fields from an existing sale for the edit flow.
  void _prefillFrom(Sale s) {
    String amt(int v) => v == 0 ? '' : '$v';
    vehicleAmountController.text = amt(s.vehicleAmount);
    additionalFittingController.text = amt(s.additionalFitting);
    dlChargesController.text = amt(s.dlCharges);
    documentChargesController.text = amt(s.documentCharges);
    otherExpensesController.text = amt(s.otherExpenses);
    downPaymentController.text = amt(s.advance);
    hpAmountController.text = amt(s.hpAmount ?? 0);
    whatsappController.text = s.customerWhatsapp;
    remarksController.text = s.remarks ?? '';
    _financerId = s.financerId;
    _saleDate = s.saleDate;
  }

  final String customerId;
  final CustomerService _customers;
  final VehicleService _vehicles;
  final SaleService _sales;
  final SaleFinancerService _financers;
  final AuthController _auth;

  /// Non-null when editing an existing sale (vs creating a new one).
  final Sale? _existingSale;
  bool get isEditing => _existingSale != null;

  final vehicleAmountController = TextEditingController();
  final additionalFittingController = TextEditingController();
  final dlChargesController = TextEditingController();
  final documentChargesController = TextEditingController();
  final otherExpensesController = TextEditingController();
  final downPaymentController = TextEditingController();
  final hpAmountController = TextEditingController();
  final whatsappController = TextEditingController();
  final remarksController = TextEditingController();
  // Vehicle reg number — captured at sell time, written onto the vehicle.
  final regNoController = TextEditingController();

  late final List<TextEditingController> _amountControllers = [
    vehicleAmountController,
    additionalFittingController,
    dlChargesController,
    documentChargesController,
    otherExpensesController,
    downPaymentController,
    // HP changes the derived remaining, so recompute live too.
    hpAmountController,
  ];

  String? _vehicleId;
  int? _financerId;
  DateTime? _saleDate;
  bool _loading = false;

  // Vehicle papers captured at sell time → written onto the vehicle on submit.
  bool _rc = false;
  bool _permit = false;
  bool _insurance = false;
  PickedDoc? _rcDoc;
  PickedDoc? _permitDoc;
  PickedDoc? _insuranceDoc;

  bool get rc => _rc;
  bool get permit => _permit;
  bool get insurance => _insurance;
  PickedDoc? get rcDoc => _rcDoc;
  PickedDoc? get permitDoc => _permitDoc;
  PickedDoc? get insuranceDoc => _insuranceDoc;

  set rc(bool v) {
    _rc = v;
    notifyListeners();
  }

  set permit(bool v) {
    _permit = v;
    notifyListeners();
  }

  set insurance(bool v) {
    _insurance = v;
    notifyListeners();
  }

  /// Attach a picked document for one of the papers ('rc' | 'permit' |
  /// 'insurance'); ticks the matching flag on.
  void setPaperDoc(String wire, PickedDoc? doc) {
    switch (wire) {
      case 'rc':
        _rcDoc = doc;
        if (doc != null) _rc = true;
      case 'permit':
        _permitDoc = doc;
        if (doc != null) _permit = true;
      case 'insurance':
        _insuranceDoc = doc;
        if (doc != null) _insurance = true;
    }
    notifyListeners();
  }

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

  /// HP (loan) amount actually applied — any positive entry counts (available
  /// to every role, admins included).
  int get hpEffective => hpAmount > 0 ? hpAmount : 0;

  /// Amount the customer repays in installments, derived (not typed):
  /// Remaining = Total − HP − Down payment.
  int get remaining =>
      (total - hpEffective - downPayment).clamp(0, 1 << 31);

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
    // Reflect the newly-selected vehicle's reg number in the editable field.
    final veh = v == null ? null : _vehicles.byId(v);
    regNoController.text = veh?.regNo ?? '';
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

  /// Returns true if the created/edited sale is pending (admin) confirmation.
  Future<bool> submit() async {
    _loading = true;
    notifyListeners();
    try {
      final user = _auth.currentUser!;
      // ── Edit an existing sale ─────────────────────────────────────────────
      // Vehicle/customer are fixed; only the sale terms change. Super admin →
      // applies at once; admin → held pending until a super admin approves.
      if (_existingSale != null) {
        return await _sales.editSale(
          _existingSale.id,
          saleDate: _saleDate!,
          customerWhatsapp: whatsappController.text.trim(),
          vehicleAmount: vehicleAmount,
          additionalFitting: additionalFitting,
          dlCharges: dlCharges,
          documentCharges: documentCharges,
          otherExpenses: otherExpenses,
          downPayment: downPayment,
          remainingAmount: showLoanFields ? remaining : 0,
          hpAmount: (showLoanFields && hpEffective > 0) ? hpEffective : null,
          remarks: remarksController.text.trim().isEmpty
              ? null
              : remarksController.text.trim(),
          financerId: _financerId,
        );
      }
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
        remainingAmount: showLoanFields ? remaining : 0,
        hpAmount: (showLoanFields && hpEffective > 0) ? hpEffective : null,
        remarks: remarksController.text.trim().isEmpty
            ? null
            : remarksController.text.trim(),
        financerId: _financerId,
      );
      // Write the captured vehicle papers (reg no + flags). Only mark the
      // vehicle SOLD when the sale is active (super admin); an admin's sale is
      // pending approval, so the vehicle stays "not sold" (with a Pending badge)
      // until the super admin approves — it moves to Sold on approval.
      final isSuper = user.isSuperAdmin;
      final regNo = regNoController.text.trim();
      await _vehicles.update(_vehicleId!,
          saleStatus: isSuper ? SaleStatus.sold : null,
          regNo: regNo.isEmpty ? null : regNo,
          rc: _rc,
          permit: _permit,
          insurance: _insurance);
      if (!isSuper) {
        // Reserve the vehicle so it can't be re-sold while the sale is pending;
        // it stays in the "Not sold" tab until approved.
        _vehicles.assignTo(
            _vehicleId!, customerId, InventoryStatus.reserved);
      }
      // Upload any attached papers onto the vehicle's documents.
      final papers = <String, PickedDoc?>{
        'rc': _rcDoc,
        'permit': _permitDoc,
        'insurance': _insuranceDoc,
      };
      for (final e in papers.entries) {
        if (e.value != null) {
          await _vehicles.uploadDocument(_vehicleId!, e.key, e.value!);
        }
      }
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
    whatsappController.dispose();
    remarksController.dispose();
    regNoController.dispose();
    super.dispose();
  }
}
