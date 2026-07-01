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

  // ── Reminders / collections ─────────────────────────────────────────────
  bool _busy = false;
  bool get busy => _busy;

  bool get isSuperAdmin => _auth.isSuperAdmin;
  String get currentUserId => _auth.currentUser?.id ?? '';

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> addReminder(DateTime dueDate, int amount) =>
      _run(() => _sales.addReminder(_saleId, dueDate: dueDate, amount: amount));

  Future<void> takeCall(String installmentId) =>
      _run(() => _sales.takeCall(_saleId, installmentId));

  Future<void> cancelReminder(String installmentId, String reason) =>
      _run(() => _sales.cancelReminder(_saleId, installmentId, reason));

  Future<void> submitPayment(String installmentId, int amount,
          Uint8List screenshot, String filename, String? mimeType) =>
      _run(() => _sales.submitPayment(_saleId, installmentId,
          amount: amount,
          screenshot: screenshot,
          filename: filename,
          mimeType: mimeType));

  Future<void> approvePayment(String paymentId) =>
      _run(() => _sales.approvePayment(_saleId, paymentId));

  Future<void> declinePayment(String paymentId, String reason) =>
      _run(() => _sales.declinePayment(_saleId, paymentId, reason));

  String screenshotUrl(int docId) => _sales.screenshotUrl(docId);
}
