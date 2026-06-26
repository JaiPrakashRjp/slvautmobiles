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
    required DepositType depositType,
    required DateTime saleDate,
    required String customerWhatsapp,
    required int totalSalePrice,
    required int amountReceived,
    int monthly,
    int installmentCount,
    DateTime? firstDueDate,
    String? remarks,
  });

  /// Mark one installment as paid. Updates local state + persists.
  Future<void> markPaid(String saleId, String installmentId);

  /// Settle all remaining installments and close the sale.
  Future<void> payOff(String saleId);

  /// Reload from backend (no-op for mock).
  Future<void> refresh();

  /// Returns the reminder-dispatch log for a sale.
  Future<List<ReminderLog>> remindersForSale(String saleId);

  /// Cancel a sale (unsell): saves the reason, resets vehicle to not-sold.
  Future<void> cancel(String saleId, String reason, String byUserId);

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
      .where((s) => s.vehicleId == vehicleId && s.saleStatus != 'cancelled')
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
    required DepositType depositType,
    required DateTime saleDate,
    required String customerWhatsapp,
    required int totalSalePrice,
    required int amountReceived,
    int monthly = 0,
    int installmentCount = 0,
    DateTime? firstDueDate,
    String? remarks,
  }) async {
    final mode = depositType.paymentMode;
    final installments = mode == PaymentMode.installments && installmentCount > 0
        ? buildSchedule(
            monthly: monthly,
            count: installmentCount,
            firstDue: firstDueDate ?? DateTime.now(),
          )
        : <Installment>[];

    final sale = Sale(
      id: IdGen.nextId('sale'),
      vehicleId: vehicleId,
      customerId: customerId,
      mode: mode,
      salePrice: totalSalePrice,
      advance: amountReceived,
      monthly: monthly,
      dueDate: firstDueDate,
      saleDate: saleDate,
      customerWhatsapp: customerWhatsapp,
      installments: installments,
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
      mode == PaymentMode.full ? InventoryStatus.sold : InventoryStatus.reserved,
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

  @override
  Future<void> cancel(String saleId, String reason, String byUserId) async {
    final s = byId(saleId);
    if (s == null) return;
    s.saleStatus = 'cancelled';
    s.unsellReason = reason;
    _vehicles.release(s.vehicleId);
    notifyListeners();
  }

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
