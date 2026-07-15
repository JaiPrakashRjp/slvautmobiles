import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/installment.dart';
import '../models/reminder_log.dart';
import '../models/sale.dart';
import '../utils/id_gen.dart';
import 'gate.dart';
import 'vehicle_service.dart';

abstract class SaleService extends ChangeNotifier {
  List<Sale> all();
  Sale? byId(String id);
  Sale? forVehicle(String vehicleId);
  List<Sale> forCustomer(String customerId);

  Future<Sale> create({
    required Role actorRole,
    required String actorId,
    required String vehicleId,
    required String customerId,
    required DateTime saleDate,
    required String customerWhatsapp,
    int vehicleAmount,
    int additionalFitting,
    int dlCharges,
    int documentCharges,
    int otherExpenses,
    required int downPayment,
    int remainingAmount,
    int? hpAmount,
    String? remarks,
    int? financerId,
  });

  /// Mark one installment as paid. Updates local state + persists.
  Future<void> markPaid(String saleId, String installmentId);

  /// Settle all remaining installments and close the sale.
  Future<void> payOff(String saleId);

  /// Reload from backend (no-op for mock).
  Future<void> refresh();

  /// Returns the reminder-dispatch log for a sale.
  Future<List<ReminderLog>> remindersForSale(String saleId);

  // ── Reminders / collections ─────────────────────────────────────────────
  /// Schedule a collection reminder (date + amount) on a sale.
  Future<void> addReminder(String saleId,
      {required DateTime dueDate, required int amount});

  /// Claim a reminder's call (locks it to the current user).
  Future<void> takeCall(String saleId, String installmentId);

  /// Call made, no payment — defer (balance unchanged).
  Future<void> cancelReminder(String saleId, String installmentId, String reason);

  /// Record an installment payment with a proof screenshot and the date it was
  /// actually paid.
  Future<void> submitPayment(String saleId, String installmentId,
      {required int amount,
      required Uint8List screenshot,
      required String filename,
      String? mimeType,
      DateTime? paidOn});

  /// Record a standalone (manual) payment against the sale — not tied to any
  /// reminder/installment. Reduces the balance; admin-recorded ones wait for
  /// super-admin approval like installment payments.
  Future<void> submitManualPayment(String saleId,
      {required int amount,
      required Uint8List screenshot,
      required String filename,
      String? mimeType,
      DateTime? paidOn});

  /// Super-admin: approve a pending payment (balance reduces).
  Future<void> approvePayment(String saleId, String paymentId);

  /// Super-admin: decline a pending payment (fails, balance unchanged).
  Future<void> declinePayment(String saleId, String paymentId, String reason);

  /// Absolute URL to view a payment proof screenshot.
  String screenshotUrl(int docId);

  /// Raw bytes of a payment proof screenshot (for the in-app viewer).
  Future<Uint8List> screenshotBytes(int docId);

  /// Cancel a sale (unsell): a super admin's applies at once; an admin's is held
  /// pending until a super admin approves it. Gated by the 1-day window.
  Future<void> cancel(String saleId, String reason, String byUserId);

  /// Super admin: approve an admin's pending unsell (it now takes effect).
  Future<void> approveUnsell(String saleId);

  /// Super admin: reject an admin's pending unsell (nothing changes; stays sold).
  Future<void> rejectUnsell(String saleId, String reason);

  /// Seize (repossess) the vehicle: a super admin's seize applies at once; an
  /// admin's is held pending until a super admin approves it.
  Future<void> seize(String saleId, String reason, String byUserId);

  /// Confirm a fully-paid sale as sold (only when the balance is cleared).
  /// Sets `sold = true`, which hides the Seize option.
  Future<void> confirmSold(String saleId);

  /// Cancel an active seize (any time): the vehicle goes back to the same
  /// customer and the sale reactivates.
  Future<void> cancelSeize(String saleId, String remarks);

  /// Finalise an active seize: the vehicle becomes a plain free vehicle (badge
  /// cleared); the seized sale stays as history.
  Future<void> confirmSeize(String saleId, String remarks);

  /// Super admin: approve an admin's pending seize (it now takes effect).
  Future<void> approveSeize(String saleId);

  /// Super admin: reject an admin's pending seize (nothing changes).
  Future<void> rejectSeize(String saleId, String reason);

  /// Seized sales for a vehicle (its repossession history), newest first.
  List<Sale> seizedForVehicle(String vehicleId);

  void confirm(String id, String byUserId);
  void reject(String id, String reason, String byUserId);
  void delete(String id);
}

class MockSaleService extends SaleService {
  MockSaleService(this._vehicles) {
    _seed();
  }

  final VehicleService _vehicles;
  final List<Sale> _sales = [];

  static List<Installment> buildSchedule({
    required int monthly,
    required int count,
    required DateTime firstDue,
    int paidUpTo = 0,
  }) {
    return List.generate(count, (i) {
      final due = DateTime(firstDue.year, firstDue.month + i, firstDue.day);
      return Installment(
        id: IdGen.nextId('inst'),
        monthNumber: i + 1,
        dueDate: due,
        amount: monthly,
        paidDate: i < paidUpTo ? due : null,
        reminderSent: i < paidUpTo,
      );
    });
  }

  void _seed() {
    _sales.add(
      Sale(
        id: IdGen.nextId('sale'),
        vehicleId: 'v_001',
        customerId: 'c_001',
        mode: PaymentMode.installments,
        salePrice: 185000,
        advance: 5000,
        monthly: 2000,
        dueDate: DateTime(2026, 3, 28),
        saleDate: DateTime(2026, 3, 2),
        customerWhatsapp: '9876543210',
        installments: buildSchedule(
          monthly: 2000,
          count: 4,
          firstDue: DateTime(2026, 3, 28),
          paidUpTo: 3,
        ),
        saleStatus: 'active',
        createdBy: 'u_super',
        createdAt: DateTime(2026, 3, 2),
        status: EntityStatus.active,
      ),
    );
    _sales.add(
      Sale(
        id: IdGen.nextId('sale'),
        vehicleId: 'v_004_sold',
        customerId: 'c_001',
        mode: PaymentMode.full,
        salePrice: 172000,
        advance: 172000,
        saleDate: DateTime(2026, 2, 18),
        customerWhatsapp: '9876543210',
        saleStatus: 'closed',
        createdBy: 'u_super',
        createdAt: DateTime(2026, 2, 18),
        status: EntityStatus.active,
      ),
    );
  }

  @override
  List<Sale> all() => List.unmodifiable(_sales);

  @override
  Sale? byId(String id) =>
      _sales.where((s) => s.id == id).cast<Sale?>().firstOrNull;

  @override
  Sale? forVehicle(String vehicleId) => _sales
      .where((s) =>
          s.vehicleId == vehicleId &&
          s.saleStatus != 'cancelled' &&
          s.saleStatus != 'seized')
      .cast<Sale?>()
      .firstOrNull;

  @override
  List<Sale> forCustomer(String customerId) =>
      _sales.where((s) => s.customerId == customerId).toList();

  @override
  Future<Sale> create({
    required Role actorRole,
    required String actorId,
    required String vehicleId,
    required String customerId,
    required DateTime saleDate,
    required String customerWhatsapp,
    int vehicleAmount = 0,
    int additionalFitting = 0,
    int dlCharges = 0,
    int documentCharges = 0,
    int otherExpenses = 0,
    required int downPayment,
    int remainingAmount = 0,
    int? hpAmount,
    String? remarks,
    int? financerId,
  }) async {
    final total = vehicleAmount +
        additionalFitting +
        dlCharges +
        documentCharges +
        otherExpenses;
    final isFullCash = downPayment >= total;
    final mode = isFullCash ? PaymentMode.full : PaymentMode.installments;

    final sale = Sale(
      id: IdGen.nextId('sale'),
      vehicleId: vehicleId,
      customerId: customerId,
      mode: mode,
      salePrice: total,
      advance: downPayment,
      vehicleAmount: vehicleAmount,
      additionalFitting: additionalFitting,
      dlCharges: dlCharges,
      documentCharges: documentCharges,
      otherExpenses: otherExpenses,
      hpAmount: hpAmount,
      remainingAmount: isFullCash ? 0 : remainingAmount,
      saleDate: saleDate,
      customerWhatsapp: customerWhatsapp,
      financerId: financerId,
      saleStatus: 'active',
      remarks: remarks,
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: Gate.initialStatus(actorRole),
    );
    _sales.insert(0, sale);

    _vehicles.assignTo(
      vehicleId,
      customerId,
      isFullCash ? InventoryStatus.sold : InventoryStatus.reserved,
    );

    notifyListeners();
    return sale;
  }

  @override
  Future<void> markPaid(String saleId, String installmentId) async {
    final sale = byId(saleId);
    final inst = sale?.installments
        .where((i) => i.id == installmentId)
        .cast<Installment?>()
        .firstOrNull;
    if (inst != null) {
      inst.paidDate = DateTime.now();
      if (sale!.installments.every((i) => i.isPaid)) {
        sale.saleStatus = 'closed';
        _vehicles.assignTo(sale.vehicleId, sale.customerId, InventoryStatus.sold);
      }
      notifyListeners();
    }
  }

  @override
  Future<void> payOff(String saleId) async {
    final sale = byId(saleId);
    if (sale == null) return;
    final now = DateTime.now();
    for (final inst in sale.installments) {
      inst.paidDate ??= now;
    }
    sale.saleStatus = 'closed';
    sale.closedAt = now;
    _vehicles.assignTo(sale.vehicleId, sale.customerId, InventoryStatus.sold);
    notifyListeners();
  }

  @override
  Future<void> refresh() async {} // no-op for mock

  @override
  Future<List<ReminderLog>> remindersForSale(String saleId) async => [];

  Installment? _inst(String saleId, String installmentId) => byId(saleId)
      ?.installments
      .where((i) => i.id == installmentId)
      .cast<Installment?>()
      .firstOrNull;

  @override
  Future<void> addReminder(String saleId,
      {required DateTime dueDate, required int amount}) async {
    final s = byId(saleId);
    if (s == null) return;
    final next =
        s.installments.fold<int>(0, (m, i) => i.monthNumber > m ? i.monthNumber : m) + 1;
    s.installments.add(Installment(
      id: IdGen.nextId('inst'),
      monthNumber: next,
      dueDate: dueDate,
      amount: amount,
      status: 'pending',
    ));
    notifyListeners();
  }

  @override
  Future<void> takeCall(String saleId, String installmentId) async {
    final inst = _inst(saleId, installmentId);
    if (inst != null) {
      inst.status = 'in_progress';
      notifyListeners();
    }
  }

  @override
  Future<void> cancelReminder(
      String saleId, String installmentId, String reason) async {
    final inst = _inst(saleId, installmentId);
    if (inst != null) {
      inst.status = 'cancelled';
      inst.cancelReason = reason;
      notifyListeners();
    }
  }

  @override
  Future<void> submitPayment(String saleId, String installmentId,
      {required int amount,
      required Uint8List screenshot,
      required String filename,
      String? mimeType,
      DateTime? paidOn}) async {
    final inst = _inst(saleId, installmentId);
    if (inst != null) {
      inst.status = 'paid';
      inst.paidDate = paidOn ?? DateTime.now();
      notifyListeners();
    }
  }

  @override
  Future<void> submitManualPayment(String saleId,
      {required int amount,
      required Uint8List screenshot,
      required String filename,
      String? mimeType,
      DateTime? paidOn}) async {
    final s = byId(saleId);
    if (s != null) {
      s.remainingAmount =
          (s.remainingAmount - amount).clamp(0, 1 << 31).toInt();
      notifyListeners();
    }
  }

  @override
  Future<void> approvePayment(String saleId, String paymentId) async =>
      notifyListeners();

  @override
  Future<void> declinePayment(
          String saleId, String paymentId, String reason) async =>
      notifyListeners();

  @override
  String screenshotUrl(int docId) => '';

  @override
  Future<Uint8List> screenshotBytes(int docId) async => Uint8List(0);

  @override
  Future<void> cancel(String saleId, String reason, String byUserId) async {
    final s = byId(saleId);
    if (s == null) return;
    s.saleStatus = 'cancelled';
    s.unsellReason = reason;
    s.unsellStage = null;
    _vehicles.release(s.vehicleId);
    notifyListeners();
  }

  @override
  Future<void> approveUnsell(String saleId) async {
    final s = byId(saleId);
    if (s == null) return;
    s.saleStatus = 'cancelled';
    s.unsellStage = null;
    _vehicles.release(s.vehicleId);
    notifyListeners();
  }

  @override
  Future<void> rejectUnsell(String saleId, String reason) async {
    final s = byId(saleId);
    if (s == null) return;
    s.unsellStage = null;
    s.unsellReason = reason;
    notifyListeners();
  }

  @override
  Future<void> seize(String saleId, String reason, String byUserId) async {
    final s = byId(saleId);
    if (s == null) return;
    s.saleStatus = 'seized';
    s.seizeStage = 'seized';
    s.seizeReason = reason;
    s.seizedAt = DateTime.now();
    _vehicles.release(s.vehicleId);
    _vehicles.byId(s.vehicleId)?.isSeized = true;
    notifyListeners();
  }

  @override
  Future<void> confirmSold(String saleId) async {
    final s = byId(saleId);
    if (s != null) {
      s.sold = true;
      notifyListeners();
    }
  }

  @override
  Future<void> cancelSeize(String saleId, String remarks) async {
    final s = byId(saleId);
    if (s == null) return;
    s.saleStatus = 'active';
    s.seizeStage = null;
    s.seizeCancelRemarks = remarks;
    s.seizedAt = null;
    s.seizeReason = null;
    _vehicles.assignTo(s.vehicleId, s.customerId, InventoryStatus.sold);
    _vehicles.byId(s.vehicleId)?.isSeized = false;
    notifyListeners();
  }

  @override
  Future<void> confirmSeize(String saleId, String remarks) async {
    final s = byId(saleId);
    if (s == null) return;
    s.seizeStage = 'confirmed';
    s.seizeConfirmRemarks = remarks;
    s.seizeConfirmedAt = DateTime.now();
    _vehicles.byId(s.vehicleId)?.isSeized = false;
    notifyListeners();
  }

  @override
  Future<void> approveSeize(String saleId) async {
    final s = byId(saleId);
    if (s == null) return;
    s.saleStatus = 'seized';
    s.seizeStage = 'seized';
    _vehicles.release(s.vehicleId);
    _vehicles.byId(s.vehicleId)?.isSeized = true;
    notifyListeners();
  }

  @override
  Future<void> rejectSeize(String saleId, String reason) async {
    final s = byId(saleId);
    if (s == null) return;
    s.seizeStage = null;
    s.seizeCancelRemarks = reason;
    s.seizedAt = null;
    s.seizeReason = null;
    notifyListeners();
  }

  @override
  List<Sale> seizedForVehicle(String vehicleId) => _sales
      .where((s) => s.vehicleId == vehicleId && s.saleStatus == 'seized')
      .toList();

  @override
  void confirm(String id, String byUserId) {
    final s = byId(id);
    if (s != null) {
      Gate.confirm(s, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final s = byId(id);
    if (s != null) {
      Gate.reject(s, reason: reason, byUserId: byUserId);
      s.saleStatus = 'rejected';
      _vehicles.release(s.vehicleId);
      notifyListeners();
    }
  }

  @override
  void delete(String id) {
    final s = byId(id);
    if (s != null) {
      _vehicles.release(s.vehicleId);
      _sales.removeWhere((x) => x.id == id);
      notifyListeners();
    }
  }
}
