import 'dart:async';
import 'dart:typed_data';

import '../models/emi.dart';
import '../models/enums.dart';
import '../models/loan.dart';
import '../utils/id_gen.dart';
import 'api_client.dart';
import 'gate.dart';
import 'loan_service.dart';

/// Real [LoanService] backed by the FastAPI `/loans` endpoints (module = loan),
/// with an in-memory cache so the synchronous getters + reactivity keep working.
/// Loans, EMIs and payments (with screenshots) persist to the database.
class ApiLoanService extends LoanService {
  ApiLoanService({ApiClient? client, this.module = 'loan'})
      : _api = client ?? ApiClient();

  final String module;
  final ApiClient _api;
  final List<Loan> _loans = [];

  Future<void> refresh() async {
    try {
      final data = await _api.get('/loans', query: {'module': module});
      final fresh = (data as List)
          .map((j) => _fromJson(j as Map<String, dynamic>))
          .toList();
      _loans
        ..clear()
        ..addAll(fresh);
    } catch (_) {
      // keep the existing cache on any error
    }
    notifyListeners();
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
    // Optimistic loan for instant UI; the background POST + refresh reconciles
    // it with the server's authoritative copy (real ids, schedule, status).
    final optimistic = Loan(
      id: IdGen.nextId('ltmp'),
      customerId: customerId,
      vehicleId: vehicleId,
      principal: principal,
      tenureMonths: tenureMonths,
      disbursementDate: disbursementDate,
      firstEmiDueDate: firstDue,
      emiAmount: emiAmount,
      emis: MockLoanService.buildSchedule(
        emiAmount: emiAmount,
        tenureMonths: tenureMonths,
        firstDue: firstDue,
      ),
      loanStatus: 'active',
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: Gate.initialStatus(actorRole),
    );
    _loans.insert(0, optimistic);
    notifyListeners();

    final body = <String, dynamic>{
      'module_code': module,
      'customer_id': int.tryParse(customerId),
      'vehicle_id': vehicleId == null ? null : int.tryParse(vehicleId),
      'principal': principal,
      'emi_amount': emiAmount,
      'tenure_months': tenureMonths,
      'loan_date': _dateStr(disbursementDate),
    }..removeWhere((_, v) => v == null);
    unawaited(_api
        .post('/loans', body: body)
        .then((_) => refresh())
        .catchError((_) => null));
    return optimistic;
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

    // Optimistic local update (mirrors the server logic).
    emi.penalty = penalty;
    emi.amountPaid = (emi.amountPaid + amount).clamp(0, emi.totalDue);
    emi.receivedDate = receivedDate ?? DateTime.now();
    if (remarks != null && remarks.isNotEmpty) emi.remarks = remarks;
    if (screenshotName != null && screenshotName.isNotEmpty) {
      emi.screenshotName = screenshotName;
    }
    if (emi.isPaid) emi.paidDate = emi.receivedDate;
    if (loan.emis.every((e) => e.isPaid)) loan.loanStatus = 'closed';
    notifyListeners();

    final fields = <String, String>{
      'amount': '$amount',
      'penalty': '$penalty',
      if (receivedDate != null) 'received_date': _dateStr(receivedDate),
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };
    unawaited(_api
        .postMultipart(
          '/loans/$loanId/emis/$emiId/pay',
          fields: fields,
          fileField: screenshotBytes != null ? 'file' : null,
          filename: screenshotName,
          bytes: screenshotBytes,
          mimeType: screenshotMime,
        )
        .then((_) => refresh())
        .catchError((_) => null));
  }

  @override
  void foreclose(String loanId, {int charge = 0}) {
    final loan = byId(loanId);
    if (loan == null) return;
    // Settle every unpaid EMI's remaining balance via the pay endpoint so the
    // closure persists; each call refreshes the cache.
    for (final e in loan.emis.where((e) => !e.isPaid)) {
      recordEmiPayment(loanId, e.id, e.remaining, penalty: e.penalty);
    }
  }

  @override
  void waivePenalty(String loanId, String emiId) {
    // Waiving = record the month with penalty 0 (no extra amount paid).
    recordEmiPayment(loanId, emiId, 0, penalty: 0);
  }

  @override
  void confirm(String id, String byUserId) {
    final l = byId(id);
    if (l == null) return;
    Gate.confirm(l, byUserId: byUserId);
    notifyListeners();
    unawaited(_api
        .post('/loans/$id/confirm')
        .then((_) => refresh())
        .catchError((_) => null));
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final l = byId(id);
    if (l == null) return;
    Gate.reject(l, reason: reason, byUserId: byUserId);
    l.loanStatus = 'rejected';
    notifyListeners();
    unawaited(_api
        .post('/loans/$id/reject', query: {'reason': reason})
        .then((_) => refresh())
        .catchError((_) => null));
  }

  @override
  void delete(String id) {
    _loans.removeWhere((l) => l.id == id);
    notifyListeners();
    unawaited(_api.delete('/loans/$id').catchError((_) => null));
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
    unawaited(_api
        .post('/loans/$loanId/seize', query: {'reason': reason})
        .then((_) => refresh())
        .catchError((_) => null));
  }

  @override
  void confirmSeize(String loanId, String byUserId) {
    final l = byId(loanId);
    if (l == null) return;
    l.seizeStage = 'seized';
    l.loanStatus = 'seized';
    notifyListeners();
    unawaited(_api
        .post('/loans/$loanId/seize/confirm')
        .then((_) => refresh())
        .catchError((_) => null));
  }

  @override
  void cancelSeize(String loanId, String byUserId, {String? remarks}) {
    final l = byId(loanId);
    if (l == null) return;
    l.seizeStage = null;
    if (l.loanStatus == 'seized') l.loanStatus = 'active';
    notifyListeners();
    unawaited(_api
        .post('/loans/$loanId/seize/cancel',
            query: {if (remarks != null) 'remarks': remarks})
        .then((_) => refresh())
        .catchError((_) => null));
  }

  @override
  Future<Uint8List> paymentDocBytes(int docId) =>
      _api.getBytes('/loans/payment-documents/$docId');

  @override
  String paymentDocUrl(int docId) =>
      _api.absoluteUrl('/loans/payment-documents/$docId');

  @override
  void deletePaymentDoc(String loanId, int docId) {
    final loan = byId(loanId);
    final emi = loan?.emis
        .where((e) => e.screenshotDocId == docId)
        .cast<Emi?>()
        .firstOrNull;
    if (emi != null) {
      emi.screenshotDocId = null;
      emi.screenshotName = null;
      notifyListeners();
    }
    unawaited(_api
        .delete('/loans/payment-documents/$docId')
        .then((_) => refresh())
        .catchError((_) => null));
  }

  // ── JSON mapping ────────────────────────────────────────────────────────────
  static String _dateStr(DateTime d) => d.toIso8601String().split('T').first;

  static DateTime? _date(dynamic s) =>
      (s is String && s.isNotEmpty) ? DateTime.tryParse(s) : null;

  static int _int(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.round() ?? 0);

  Loan _fromJson(Map<String, dynamic> j) {
    final emis = (j['emis'] as List?)
            ?.map((e) => _emiFromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    // Mark EMIs whose payments carry a screenshot (proof is on the payment row).
    for (final p in (j['payments'] as List? ?? [])) {
      final pm = p as Map<String, dynamic>;
      final ids = (pm['document_ids'] as List?) ?? [];
      if (ids.isEmpty || pm['emi_id'] == null) continue;
      final emiId = pm['emi_id'].toString();
      for (final e in emis) {
        if (e.id == emiId) {
          e.screenshotDocId = (ids.first as num).toInt();
          e.screenshotName = 'Screenshot attached';
        }
      }
    }
    return Loan(
      id: j['id'].toString(),
      customerId: j['customer_id'].toString(),
      vehicleId: j['vehicle_id']?.toString(),
      principal: _int(j['principal']),
      tenureMonths: (j['tenure_months'] as num?)?.toInt() ?? emis.length,
      emiAmount: _int(j['emi_amount']),
      disbursementDate: _date(j['loan_date']) ?? DateTime.now(),
      firstEmiDueDate: _date(j['first_due_date']) ?? DateTime.now(),
      emis: emis,
      loanStatus: (j['loan_status'] as String?) ?? 'active',
      seizeStage: j['seize_stage'] as String?,
      seizeReason: j['seize_reason'] as String?,
      seizedAt: _date(j['seized_at']),
      createdBy: j['created_by']?.toString() ?? '',
      createdAt: _date(j['created_at']) ?? DateTime.now(),
      status: EntityStatus.fromWire((j['status'] as String?) ?? 'active'),
      confirmedBy: j['confirmed_by']?.toString(),
      confirmedAt: _date(j['confirmed_at']),
      rejectionReason: j['rejection_reason'] as String?,
    );
  }

  Emi _emiFromJson(Map<String, dynamic> j) {
    return Emi(
      id: j['id'].toString(),
      sequenceNumber: (j['sequence_number'] as num).toInt(),
      dueDate: _date(j['due_date']) ?? DateTime.now(),
      amountDue: _int(j['amount']),
      amountPaid: _int(j['amount_paid']),
      penalty: _int(j['penalty']),
      paidDate: _date(j['paid_date']),
      receivedDate: _date(j['received_date']),
      remarks: j['remarks'] as String?,
    );
  }
}
