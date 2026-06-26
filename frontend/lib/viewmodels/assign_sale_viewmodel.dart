import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/enums.dart';
import '../models/vehicle.dart';
import '../services/customer_service.dart';
import '../services/sale_service.dart';
import '../services/vehicle_service.dart';

/// Backs the assign-sale screen.
class AssignSaleViewModel extends ChangeNotifier {
  AssignSaleViewModel({
    required this.customerId,
    required CustomerService customers,
    required VehicleService vehicles,
    required SaleService sales,
    required AuthController auth,
    String? initialVehicleId,
  })  : _customers = customers,
        _vehicles = vehicles,
        _sales = sales,
        _auth = auth,
        _vehicleId = initialVehicleId,
        vehicleLocked = initialVehicleId != null {
    // Pre-fill customer WhatsApp from the customer's phone
    final phone = customers.byId(customerId)?.phone ?? '';
    if (phone.isNotEmpty) whatsappController.text = phone;
  }

  final String customerId;
  final CustomerService _customers;
  final VehicleService _vehicles;
  final SaleService _sales;
  final AuthController _auth;

  final totalSalePriceController = TextEditingController();
  final advanceController = TextEditingController();
  final monthlyController = TextEditingController();
  final monthsController = TextEditingController(text: '12');
  final whatsappController = TextEditingController();
  final remarksController = TextEditingController();

  DepositType _depositType = DepositType.fullCash;
  String? _vehicleId;
  DateTime? _saleDate;
  DateTime? _firstDueDate;
  bool _loading = false;

  final bool vehicleLocked;

  DepositType get depositType => _depositType;
  String? get vehicleId => _vehicleId;
  DateTime? get saleDate => _saleDate;
  DateTime? get firstDueDate => _firstDueDate;
  bool get loading => _loading;

  Customer? get customer => _customers.byId(customerId);
  List<Vehicle> get availableVehicles => _vehicles.available();
  Vehicle? get selectedVehicle =>
      _vehicleId == null ? null : _vehicles.byId(_vehicleId!);

  int get _totalPrice =>
      int.tryParse(totalSalePriceController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get _advance =>
      int.tryParse(advanceController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  /// Read-only computed remaining for down payment.
  int get remaining => (_totalPrice - _advance).clamp(0, 999999999);

  set depositType(DepositType v) {
    _depositType = v;
    notifyListeners();
  }

  set vehicleId(String? v) {
    _vehicleId = v;
    notifyListeners();
  }

  set saleDate(DateTime? v) {
    _saleDate = v;
    notifyListeners();
  }

  set firstDueDate(DateTime? v) {
    _firstDueDate = v;
    notifyListeners();
  }

  int _parseInt(TextEditingController ctl) =>
      int.tryParse(ctl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  String? validate() {
    if (_vehicleId == null) return 'Please select a vehicle';
    if (_saleDate == null) return 'Select the sale date';
    if (whatsappController.text.trim().isEmpty) {
      return 'Enter the customer WhatsApp number';
    }
    if (_parseInt(totalSalePriceController) <= 0) {
      return 'Enter the total sale price';
    }
    if (_depositType == DepositType.downPayment) {
      if (_parseInt(advanceController) <= 0) return 'Enter the advance amount';
      if (_parseInt(monthlyController) <= 0) return 'Enter the monthly amount';
      if ((int.tryParse(monthsController.text.trim()) ?? 0) <= 0) {
        return 'Enter the number of months';
      }
      if (_firstDueDate == null) return 'Pick the first installment due date';
    }
    return null;
  }

  /// Returns true if the created sale is pending (admin) confirmation.
  Future<bool> submit() async {
    _loading = true;
    notifyListeners();
    try {
      final user = _auth.currentUser!;
      final isDown = _depositType == DepositType.downPayment;
      await _sales.create(
        actorRole: user.role,
        actorId: user.id,
        vehicleId: _vehicleId!,
        customerId: customerId,
        depositType: _depositType,
        saleDate: _saleDate!,
        customerWhatsapp: whatsappController.text.trim(),
        totalSalePrice: _parseInt(totalSalePriceController),
        amountReceived: isDown
            ? _parseInt(advanceController)
            : _parseInt(totalSalePriceController),
        monthly: isDown ? _parseInt(monthlyController) : 0,
        installmentCount: isDown
            ? (int.tryParse(monthsController.text.trim()) ?? 0)
            : 0,
        firstDueDate: isDown ? _firstDueDate : null,
        remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
      );
      // Keep local vehicle cache in sync
      await _vehicles.update(_vehicleId!, saleStatus: SaleStatus.sold);
      return !user.isSuperAdmin;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    totalSalePriceController.dispose();
    advanceController.dispose();
    monthlyController.dispose();
    monthsController.dispose();
    whatsappController.dispose();
    remarksController.dispose();
    super.dispose();
  }
}
