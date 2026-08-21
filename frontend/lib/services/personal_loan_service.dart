import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/personal_loan.dart';
import '../models/personal_loan_emi.dart';
import 'api_client.dart';

/// Personal loans, backed by the FastAPI `/personal-loans` endpoints. Persists
/// loans + monthly EMIs; each EMI is marked paid one at a time.
class PersonalLoanService extends ChangeNotifier {
  PersonalLoanService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  final List<PersonalLoan> _loans = [];
  bool _loading = false;

  bool get loading => _loading;

  List<PersonalLoan> all() => List.unmodifiable(_loans);

  PersonalLoan? byId(String id) =>
      _loans.where((l) => l.id == id).cast<PersonalLoan?>().firstOrNull;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.get('/personal-loans');
      final fresh = (data as List)
          .map((j) => _fromJson(j as Map<String, dynamic>))
          .toList();
      _loans
        ..clear()
        ..addAll(fresh);
    } catch (_) {
      // keep cache
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Creates a personal loan (persists + builds the EMI schedule server-side).
  Future<PersonalLoan> create({
    required String vehicleNumber,
    int? financerId,
    required int loanAmount,
    required int emiAmount,
    required int tenureMonths,
    required DateTime loanDate,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'vehicle_number': vehicleNumber,
      'financer_id': financerId,
      'loan_amount': loanAmount,
      'emi_amount': emiAmount,
      'tenure_months': tenureMonths,
      'loan_date': _dateStr(loanDate),
      'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
    }..removeWhere((_, v) => v == null);
    final json = await _api.post('/personal-loans', body: body);
    final loan = _fromJson(json as Map<String, dynamic>);
    _loans.insert(0, loan);
    notifyListeners();
    return loan;
  }

  /// Marks one EMI paid. Optimistic, then persisted + reconciled by refresh.
  void markEmiPaid(String loanId, String emiId) {
    final loan = byId(loanId);
    final emi =
        loan?.emis.where((e) => e.id == emiId).cast<PersonalLoanEmi?>().firstOrNull;
    if (loan == null || emi == null) return;
    emi.status = 'paid';
    emi.paidDate = DateTime.now();
    if (loan.emis.every((e) => e.isPaid)) loan.loanStatus = 'closed';
    notifyListeners();
    unawaited(_api
        .post('/personal-loans/$loanId/emis/$emiId/pay')
        .then((_) => refresh())
        .catchError((_) => null));
  }

  void delete(String id) {
    _loans.removeWhere((l) => l.id == id);
    notifyListeners();
    unawaited(_api.delete('/personal-loans/$id').catchError((_) => null));
  }

  // ── JSON mapping ────────────────────────────────────────────────────────────
  static String _dateStr(DateTime d) => d.toIso8601String().split('T').first;

  static DateTime? _date(dynamic s) =>
      (s is String && s.isNotEmpty) ? DateTime.tryParse(s) : null;

  static int _int(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.round() ?? 0);

  PersonalLoan _fromJson(Map<String, dynamic> j) {
    return PersonalLoan(
      id: j['id'].toString(),
      vehicleNumber: (j['vehicle_number'] as String?) ?? '',
      financerId: (j['financer_id'] as num?)?.toInt(),
      financerName: j['financer_name'] as String?,
      loanAmount: _int(j['loan_amount']),
      emiAmount: _int(j['emi_amount']),
      tenureMonths: (j['tenure_months'] as num?)?.toInt() ?? 0,
      loanDate: _date(j['loan_date']) ?? DateTime.now(),
      firstDueDate: _date(j['first_due_date']) ?? DateTime.now(),
      phone: j['phone'] as String?,
      loanStatus: (j['loan_status'] as String?) ?? 'active',
      emis: (j['emis'] as List?)
              ?.map((e) => _emiFromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  PersonalLoanEmi _emiFromJson(Map<String, dynamic> j) {
    return PersonalLoanEmi(
      id: j['id'].toString(),
      sequenceNumber: (j['sequence_number'] as num).toInt(),
      dueDate: _date(j['due_date']) ?? DateTime.now(),
      amount: _int(j['amount']),
      status: (j['status'] as String?) == 'paid' ? 'paid' : 'pending',
      paidDate: _date(j['paid_date']),
    );
  }
}
