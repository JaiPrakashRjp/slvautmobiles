import 'package:flutter/foundation.dart';

import '../models/emi.dart';
import '../models/enums.dart';
import '../models/loan.dart';
import '../utils/id_gen.dart';
import 'gate.dart';

abstract class LoanService extends ChangeNotifier {
  List<Loan> all();
  Loan? byId(String id);
  List<Loan> forCustomer(String customerId);

  /// Books a loan against a customer (and optionally a vehicle). No interest:
  /// each month owes the typed [emiAmount], repeated for [tenureMonths].
  Loan create({
    required Role actorRole,
    required String actorId,
    required String customerId,
    String? vehicleId,
    required int principal,
    required int tenureMonths,
    required int emiAmount,
    required DateTime disbursementDate,
  });

  /// Records a (possibly partial) payment against one EMI. [penalty] is the late
  /// penalty for the month, [amount] is what is being paid now; [receivedDate],
  /// [remarks] and [screenshotName] capture the proof/notes. Auto-closes the
  /// loan once every EMI is fully cleared.
  void recordEmiPayment(
    String loanId,
    String emiId,
    int amount, {
    int penalty = 0,
    DateTime? receivedDate,
    String? remarks,
    String? screenshotName,
    Uint8List? screenshotBytes,
    String? screenshotMime,
  });

  /// Full edit within the 5-hour grace window: replaces every detail and
  /// REBUILDS the EMI schedule, discarding any recorded payments (the caller
  /// warns first). The server rejects it once the window has passed.
  void edit(
    String loanId, {
    required String customerId,
    String? vehicleId,
    required int principal,
    required int tenureMonths,
    required int emiAmount,
    required DateTime disbursementDate,
    String? remarks,
  });

  void foreclose(String loanId, {int charge});
  void waivePenalty(String loanId, String emiId);
  void confirm(String id, String byUserId);
  void reject(String id, String reason, String byUserId);
  void delete(String id);

  // ── Seizure (repossession) ─────────────────────────────────────────────────
  /// Requests seizing the loan vehicle. A super admin's request seizes at once;
  /// an admin's waits pending a super admin's confirm/cancel.
  void requestSeize(String loanId, String reason,
      {required bool superAdmin, required String byUserId});
  void confirmSeize(String loanId, String byUserId);

  /// Cancels a seize — the vehicle goes back to the customer, loan continues.
  void cancelSeize(String loanId, String byUserId, {String? remarks});

  // ── Payment screenshots ─────────────────────────────────────────────────────
  /// Raw bytes of a stored payment screenshot, for in-app preview.
  Future<Uint8List> paymentDocBytes(int docId);

  /// Absolute URL of a stored payment screenshot.
  String paymentDocUrl(int docId);

  /// Deletes a stored payment screenshot by its backend id.
  void deletePaymentDoc(String loanId, int docId);
}

class MockLoanService extends LoanService {
  MockLoanService() {
    _seed();
  }

  final List<Loan> _loans = [];

  /// Builds a flat, no-interest EMI schedule: [tenureMonths] rows each owing
  /// [emiAmount], due one month apart starting at [firstDue].
  static List<Emi> buildSchedule({
    required int emiAmount,
    required int tenureMonths,
    required DateTime firstDue,
    int paidUpTo = 0,
  }) {
    return List.generate(tenureMonths, (i) {
      final due = DateTime(firstDue.year, firstDue.month + i, firstDue.day);
      return Emi(
        id: IdGen.nextId('emi'),
        sequenceNumber: i + 1,
        dueDate: due,
        amountDue: emiAmount,
        amountPaid: i < paidUpTo ? emiAmount : 0,
        paidDate: i < paidUpTo ? due : null,
        receivedDate: i < paidUpTo ? due : null,
      );
    });
  }

  void _seed() {
    // Active loan, 2 of 20 EMIs paid — ₹7,000/month.
    _loans.add(Loan(
      id: IdGen.nextId('loan'),
      customerId: 'c_001',
      principal: 140000,
      tenureMonths: 20,
      disbursementDate: DateTime(2026, 6, 5),
      firstEmiDueDate: DateTime(2026, 7, 5),
      emiAmount: 7000,
      emis: buildSchedule(
        emiAmount: 7000,
        tenureMonths: 20,
        firstDue: DateTime(2026, 7, 5),
        paidUpTo: 1,
      ),
      loanStatus: 'active',
      createdBy: 'u_super',
      createdAt: DateTime(2026, 6, 5),
      status: EntityStatus.active,
    ));
  }

  @override
  List<Loan> all() => List.unmodifiable(_loans);

  @override
  Loan? byId(String id) =>
      _loans.where((l) => l.id == id).cast<Loan?>().firstOrNull;

  @override
  List<Loan> forCustomer(String customerId) =>
      _loans.where((l) => l.customerId == customerId).toList();

  @override
  Loan create({
    required Role actorRole,
    required String actorId,
    required String customerId,
    String? vehicleId,
    required int principal,
    required int tenureMonths,
    required int emiAmount,
    required DateTime disbursementDate,
  }) {
    final firstDue = DateTime(
        disbursementDate.year, disbursementDate.month + 1, disbursementDate.day);
    final loan = Loan(
      id: IdGen.nextId('loan'),
      customerId: customerId,
      vehicleId: vehicleId,
      principal: principal,
      tenureMonths: tenureMonths,
      disbursementDate: disbursementDate,
      firstEmiDueDate: firstDue,
      emiAmount: emiAmount,
      emis: buildSchedule(
        emiAmount: emiAmount,
        tenureMonths: tenureMonths,
        firstDue: firstDue,
      ),
      loanStatus: 'active',
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: Gate.initialStatus(actorRole),
    );
    _loans.insert(0, loan);
    notifyListeners();
    return loan;
  }

  @override
  void recordEmiPayment(
    String loanId,
    String emiId,
    int amount, {
    int penalty = 0,
    DateTime? receivedDate,
    String? remarks,
    String? screenshotName,
    Uint8List? screenshotBytes,
    String? screenshotMime,
  }) {
    final loan = byId(loanId);
    final emi = loan?.emis.where((e) => e.id == emiId).cast<Emi?>().firstOrNull;
    if (loan == null || emi == null) return;

    emi.penalty = penalty;
    emi.amountPaid = (emi.amountPaid + amount).clamp(0, emi.totalDue);
    emi.receivedDate = receivedDate ?? DateTime.now();
    if (remarks != null && remarks.isNotEmpty) emi.remarks = remarks;
    if (screenshotName != null && screenshotName.isNotEmpty) {
      emi.screenshotName = screenshotName;
    }
    if (emi.isPaid) emi.paidDate = emi.receivedDate;

    if (loan.emis.every((e) => e.isPaid)) {
      loan.loanStatus = 'closed';
    } else if (loan.emis.any((e) =>
        !e.isPaid && e.statusAt(DateTime.now()) == ScheduleStatus.overdue)) {
      loan.loanStatus = 'overdue';
    } else {
      loan.loanStatus = 'active';
    }
    notifyListeners();
  }

  @override
  void edit(
    String loanId, {
    required String customerId,
    String? vehicleId,
    required int principal,
    required int tenureMonths,
    required int emiAmount,
    required DateTime disbursementDate,
    String? remarks,
  }) {
    final i = _loans.indexWhere((l) => l.id == loanId);
    if (i < 0) return;
    final old = _loans[i];
    final firstDue = DateTime(
        disbursementDate.year, disbursementDate.month + 1, disbursementDate.day);
    _loans[i] = Loan(
      id: old.id,
      customerId: customerId,
      vehicleId: vehicleId,
      principal: principal,
      tenureMonths: tenureMonths,
      disbursementDate: disbursementDate,
      firstEmiDueDate: firstDue,
      emiAmount: emiAmount,
      emis: buildSchedule(
        emiAmount: emiAmount, tenureMonths: tenureMonths, firstDue: firstDue),
      loanStatus: 'active',
      createdBy: old.createdBy,
      createdAt: old.createdAt,
      status: old.status,
      confirmedBy: old.confirmedBy,
      confirmedAt: old.confirmedAt,
    );
    notifyListeners();
  }

  @override
  void foreclose(String loanId, {int charge = 0}) {
    final loan = byId(loanId);
    if (loan == null) return;
    for (final e in loan.emis) {
      if (!e.isPaid) {
        e.amountPaid = e.totalDue;
        e.paidDate = DateTime.now();
        e.receivedDate = DateTime.now();
      }
    }
    loan.loanStatus = 'foreclosed';
    notifyListeners();
  }

  @override
  void waivePenalty(String loanId, String emiId) {
    final loan = byId(loanId);
    final emi =
        loan?.emis.where((e) => e.id == emiId).cast<Emi?>().firstOrNull;
    if (emi != null) {
      emi.penalty = 0;
      notifyListeners();
    }
  }

  @override
  void confirm(String id, String byUserId) {
    final l = byId(id);
    if (l != null) {
      Gate.confirm(l, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final l = byId(id);
    if (l != null) {
      Gate.reject(l, reason: reason, byUserId: byUserId);
      l.loanStatus = 'rejected';
      notifyListeners();
    }
  }

  @override
  void delete(String id) {
    _loans.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  @override
  void requestSeize(String loanId, String reason,
      {required bool superAdmin, required String byUserId}) {
    final l = byId(loanId);
    if (l == null) return;
    l.seizeReason = reason;
    l.seizedAt = DateTime.now();
    if (superAdmin) {
      l.seizeStage = 'seized';
      l.loanStatus = 'seized';
    } else {
      l.seizeStage = 'pending';
    }
    notifyListeners();
  }

  @override
  void confirmSeize(String loanId, String byUserId) {
    final l = byId(loanId);
    if (l == null) return;
    l.seizeStage = 'seized';
    l.loanStatus = 'seized';
    notifyListeners();
  }

  @override
  void cancelSeize(String loanId, String byUserId, {String? remarks}) {
    final l = byId(loanId);
    if (l == null) return;
    l.seizeStage = null;
    if (l.loanStatus == 'seized') l.loanStatus = 'active';
    notifyListeners();
  }

  @override
  Future<Uint8List> paymentDocBytes(int docId) async => Uint8List(0);

  @override
  String paymentDocUrl(int docId) => '';

  @override
  void deletePaymentDoc(String loanId, int docId) {}
}
