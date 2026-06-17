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
  Loan create({
    required Role actorRole,
    required String actorId,
    required String customerId,
    required int principal,
    required double rate,
    required int tenureMonths,
    required DateTime disbursementDate,
    required PenaltyType penaltyType,
    required num penaltyValue,
  });
  void recordEmiPayment(String loanId, String emiId, int amount);
  void foreclose(String loanId, {int charge});
  void waivePenalty(String loanId, String emiId);
  void confirm(String id, String byUserId);
  void reject(String id, String reason, String byUserId);
  void delete(String id);
}

class MockLoanService extends LoanService {
  MockLoanService() {
    _seed();
  }

  final List<Loan> _loans = [];

  /// Builds a flat-rate EMI schedule; the final EMI absorbs rounding.
  static List<Emi> buildSchedule({
    required int principal,
    required double rate,
    required int tenureMonths,
    required DateTime firstDue,
    int paidUpTo = 0,
  }) {
    final total = Loan.totalPayable(principal, rate, tenureMonths);
    final emi = Loan.emiFor(principal, rate, tenureMonths);
    return List.generate(tenureMonths, (i) {
      final due = DateTime(firstDue.year, firstDue.month + i, firstDue.day);
      // Last EMI = remainder so the schedule sums exactly to total payable.
      final amount = i == tenureMonths - 1 ? total - emi * (tenureMonths - 1) : emi;
      return Emi(
        id: IdGen.nextId('emi'),
        sequenceNumber: i + 1,
        dueDate: due,
        amountDue: amount,
        amountPaid: i < paidUpTo ? amount : 0,
        paidDate: i < paidUpTo ? due : null,
      );
    });
  }

  void _seed() {
    // Active loan, 4 of 12 EMIs paid.
    _loans.add(Loan(
      id: IdGen.nextId('loan'),
      customerId: 'c_001',
      principal: 50000,
      rate: 12,
      tenureMonths: 12,
      disbursementDate: DateTime(2026, 1, 5),
      firstEmiDueDate: DateTime(2026, 2, 5),
      emiAmount: Loan.emiFor(50000, 12, 12),
      emis: buildSchedule(
        principal: 50000,
        rate: 12,
        tenureMonths: 12,
        firstDue: DateTime(2026, 2, 5),
        paidUpTo: 4,
      ),
      penaltyType: PenaltyType.flatPerDay,
      penaltyValue: 50,
      loanStatus: 'active',
      createdBy: 'u_super',
      createdAt: DateTime(2026, 1, 5),
      status: EntityStatus.active,
    ));

    // Overdue loan — first EMI just lapsed.
    final overdueEmis = buildSchedule(
      principal: 30000,
      rate: 10,
      tenureMonths: 6,
      firstDue: DateTime(2026, 6, 1),
    );
    overdueEmis.first.penalty = 50; // 1 day late at ₹50/day
    _loans.add(Loan(
      id: IdGen.nextId('loan'),
      customerId: 'c_001',
      principal: 30000,
      rate: 10,
      tenureMonths: 6,
      disbursementDate: DateTime(2026, 5, 1),
      firstEmiDueDate: DateTime(2026, 6, 1),
      emiAmount: Loan.emiFor(30000, 10, 6),
      emis: overdueEmis,
      penaltyType: PenaltyType.flatPerDay,
      penaltyValue: 50,
      loanStatus: 'overdue',
      createdBy: 'u_admin_ravi',
      createdAt: DateTime(2026, 5, 1),
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
    required int principal,
    required double rate,
    required int tenureMonths,
    required DateTime disbursementDate,
    required PenaltyType penaltyType,
    required num penaltyValue,
  }) {
    final firstDue = DateTime(
        disbursementDate.year, disbursementDate.month + 1, disbursementDate.day);
    final loan = Loan(
      id: IdGen.nextId('loan'),
      customerId: customerId,
      principal: principal,
      rate: rate,
      tenureMonths: tenureMonths,
      disbursementDate: disbursementDate,
      firstEmiDueDate: firstDue,
      emiAmount: Loan.emiFor(principal, rate, tenureMonths),
      emis: buildSchedule(
        principal: principal,
        rate: rate,
        tenureMonths: tenureMonths,
        firstDue: firstDue,
      ),
      penaltyType: penaltyType,
      penaltyValue: penaltyValue,
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
  void recordEmiPayment(String loanId, String emiId, int amount) {
    final loan = byId(loanId);
    final emi =
        loan?.emis.where((e) => e.id == emiId).cast<Emi?>().firstOrNull;
    if (loan == null || emi == null) return;
    // Allocate to penalty first, then to the EMI (spec 7.4 / 8.5).
    var left = amount;
    if (emi.penalty > 0) {
      final toPenalty = left.clamp(0, emi.penalty);
      emi.penalty -= toPenalty;
      left -= toPenalty;
    }
    emi.amountPaid = (emi.amountPaid + left).clamp(0, emi.amountDue);
    if (emi.isPaid) emi.paidDate = DateTime.now();
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
  void foreclose(String loanId, {int charge = 0}) {
    final loan = byId(loanId);
    if (loan == null) return;
    for (final e in loan.emis) {
      if (!e.isPaid) {
        e.amountPaid = e.amountDue;
        e.paidDate = DateTime.now();
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
}
