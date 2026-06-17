import 'package:flutter/foundation.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/reminder_log.dart';
import '../models/sale.dart';
import '../models/vehicle.dart';
import '../services/customer_service.dart';
import '../services/sale_service.dart';
import '../services/vehicle_service.dart';

class SaleDetailViewModel extends ChangeNotifier {
  SaleDetailViewModel({
    required String saleId,
    required SaleService sales,
    required CustomerService customers,
    required VehicleService vehicles,
    required AuthController auth,
  })  : _saleId = saleId,
        _sales = sales,
        _customers = customers,
        _vehicles = vehicles,
        _auth = auth;

  final String _saleId;
  final SaleService _sales;
  final CustomerService _customers;
  final VehicleService _vehicles;
  final AuthController _auth;

  List<ReminderLog> _reminders = [];
  bool _loadingReminders = false;
  bool _paying = false;
  bool _payingOff = false;

  Sale? get sale => _sales.byId(_saleId);
  Customer? get customer =>
      sale == null ? null : _customers.byId(sale!.customerId);
  Vehicle? get vehicle =>
      sale == null ? null : _vehicles.byId(sale!.vehicleId);

  List<ReminderLog> get reminders => _reminders;
  bool get loadingReminders => _loadingReminders;
  bool get paying => _paying;
  bool get payingOff => _payingOff;

  bool get canModify {
    final s = sale;
    if (s == null || !s.isActive) return false;
    return _auth.isSuperAdmin || s.createdBy == (_auth.currentUser?.id ?? '');
  }

  bool get hasUnpaid =>
      sale?.installments.any((i) => !i.isPaid) ?? false;

  bool get isClosed => sale?.saleStatus == 'closed';

  Future<void> loadReminders() async {
    _loadingReminders = true;
    notifyListeners();
    try {
      _reminders = await _sales.remindersForSale(_saleId);
    } catch (_) {
      _reminders = [];
    } finally {
      _loadingReminders = false;
      notifyListeners();
    }
  }

  Future<void> markPaid(String installmentId) async {
    _paying = true;
    notifyListeners();
    try {
      await _sales.markPaid(_saleId, installmentId);
    } finally {
      _paying = false;
      notifyListeners();
    }
  }

  Future<void> payOff() async {
    _payingOff = true;
    notifyListeners();
    try {
      await _sales.payOff(_saleId);
    } finally {
      _payingOff = false;
      notifyListeners();
    }
  }
}
