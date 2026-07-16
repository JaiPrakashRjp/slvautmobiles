import 'package:flutter/foundation.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/picked_doc.dart';
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

  /// Reminder calls are a shared pool: ANY signed-in staff (admin or super
  /// admin) can take/handle a due call — not just the sale's creator. The
  /// per-call lock (taken_by) then serialises who acts on it.
  bool get canHandleCalls =>
      (sale?.isActive ?? false) && _auth.currentUser != null;

  bool get hasUnpaid =>
      sale?.installments.any((i) => !i.isPaid) ?? false;

  bool get isClosed => sale?.saleStatus == 'closed';

  /// The sale has been confirmed as sold (fully paid + user-confirmed).
  bool get isSold => sale?.sold ?? false;

  /// Show the "confirm sold" prompt: balance cleared but not yet confirmed.
  bool get canConfirmSold =>
      canModify && !isSold && (sale?.remainingAmount ?? 1) <= 0;

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

  Future<void> addReminder(DateTime dueDate, int amount) => _run(() async {
        await _sales.addReminder(_saleId, dueDate: dueDate, amount: amount);
        // Re-pull the reminder log so the new entry shows immediately (the sale
        // itself is already updated by the service) — no re-login needed.
        await loadReminders();
      });

  Future<void> takeCall(String installmentId) => _run(() async {
        await _sales.takeCall(_saleId, installmentId);
        // Re-pull the reminder log so the updated state shows immediately.
        await loadReminders();
      });

  Future<void> cancelReminder(String installmentId, String reason) =>
      _run(() async {
        await _sales.cancelReminder(_saleId, installmentId, reason);
        // Re-pull the reminder log so the cancellation shows immediately.
        await loadReminders();
      });

  Future<void> submitPayment(String installmentId, int amount,
          Uint8List screenshot, String filename, String? mimeType,
          {DateTime? paidOn}) =>
      _run(() => _sales.submitPayment(_saleId, installmentId,
          amount: amount,
          screenshot: screenshot,
          filename: filename,
          mimeType: mimeType,
          paidOn: paidOn));

  Future<void> submitManualPayment(int amount, Uint8List screenshot,
          String filename, String? mimeType, {DateTime? paidOn}) =>
      _run(() => _sales.submitManualPayment(_saleId,
          amount: amount,
          screenshot: screenshot,
          filename: filename,
          mimeType: mimeType,
          paidOn: paidOn));

  Future<void> confirmSold() => _run(() => _sales.confirmSold(_saleId));

  Future<void> approvePayment(String paymentId) =>
      _run(() => _sales.approvePayment(_saleId, paymentId));

  Future<void> declinePayment(String paymentId, String reason) =>
      _run(() => _sales.declinePayment(_saleId, paymentId, reason));

  /// Super admin approves an admin's pending unsell (it then takes effect and
  /// frees the vehicle).
  Future<void> approveUnsell() => _run(() async {
        await _sales.approveUnsell(_saleId);
        await _vehicles.refresh();
      });

  /// Super admin rejects an admin's pending unsell (nothing changes).
  Future<void> rejectUnsell(String reason) =>
      _run(() => _sales.rejectUnsell(_saleId, reason));

  /// Super admin approves an admin's pending seize (it then takes effect and
  /// frees the vehicle).
  Future<void> approveSeize() => _run(() async {
        await _sales.approveSeize(_saleId);
        await _vehicles.refresh();
      });

  /// Super admin rejects an admin's pending seize (nothing changes).
  Future<void> rejectSeize(String reason) =>
      _run(() => _sales.rejectSeize(_saleId, reason));

  String screenshotUrl(int docId) => _sales.screenshotUrl(docId);
  Future<Uint8List> screenshotBytes(int docId) =>
      _sales.screenshotBytes(docId);

  // ── Vehicle papers (reg no + RC/permit/insurance, managed from the sale) ──
  /// Update the sale's vehicle: reg number and/or the RC/permit/insurance flags.
  Future<void> updateVehicle({
    String? regNo,
    bool? rc,
    bool? permit,
    bool? insurance,
  }) =>
      _run(() async {
        final v = vehicle;
        if (v == null) return;
        await _vehicles.update(v.id,
            regNo: regNo, rc: rc, permit: permit, insurance: insurance);
      });

  /// Upload an RC / permit / insurance document onto the sale's vehicle.
  Future<void> uploadVehicleDoc(String docTypeWire, PickedDoc doc) =>
      _run(() async {
        final v = vehicle;
        if (v == null) return;
        await _vehicles.uploadDocument(v.id, docTypeWire, doc);
      });

  /// Absolute URL of a vehicle document (to open/preview).
  String vehicleDocUrl(int docId) => _vehicles.documentUrl(docId);

  /// Raw bytes of a vehicle document (for the in-app preview + share sheet).
  Future<Uint8List> vehicleDocBytes(int docId) =>
      _vehicles.documentBytes(docId);
}
