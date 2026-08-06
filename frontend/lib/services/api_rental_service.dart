import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';
import '../models/installment.dart';
import '../models/rental_agreement.dart';
import '../models/sale_payment.dart';
import 'api_client.dart';
import 'gate.dart';

/// Real rental service backed by the FastAPI backend (module = rental). Mirrors
/// [ApiSaleService]: an in-memory cache keeps the synchronous getters +
/// reactivity working. All mutations call the API.
class RentalAgreementService extends ChangeNotifier {
  RentalAgreementService({ApiClient? client, AuthController? auth})
      : _api = client ?? ApiClient(),
        _auth = auth;

  final ApiClient _api;
  final AuthController? _auth;
  final List<RentalAgreement> _cache = [];
  bool _loading = false;

  bool get loading => _loading;
  List<RentalAgreement> all() => List.unmodifiable(_cache);

  RentalAgreement? byId(String id) =>
      _cache.where((r) => r.id == id).cast<RentalAgreement?>().firstOrNull;

  /// The current (non-cancelled, non-seized) rental for a vehicle, if any.
  RentalAgreement? forVehicle(String vehicleId) => _cache
      .where((r) =>
          r.vehicleId == vehicleId &&
          r.rentalStatus != 'cancelled' &&
          r.rentalStatus != 'seized')
      .cast<RentalAgreement?>()
      .firstOrNull;

  List<RentalAgreement> forCustomer(String customerId) =>
      _cache.where((r) => r.customerId == customerId).toList();

  Future<void> refresh() async {
    final userId = _auth?.currentUserId ?? 0;
    if (userId == 0) {
      _cache.clear();
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.get('/rentals', query: {'module': 'rental'});
      _cache
        ..clear()
        ..addAll((data as List).map((j) => _fromJson(j as Map<String, dynamic>)));
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _replace(RentalAgreement rental) {
    final i = _cache.indexWhere((r) => r.id == rental.id);
    if (i != -1) {
      _cache[i] = rental;
    } else {
      _cache.insert(0, rental);
    }
    notifyListeners();
  }

  Future<RentalAgreement> create({
    required String vehicleId,
    required String customerId,
    String? rentalType, // 'weekly' | 'daily' (recurring rent)
    int? periodAmount, // rent per period
    int? totalAmount, // legacy balance model only
    int advance = 0,
    DateTime? startDate,
    String? remarks,
    int oldBalance = 0,
    DateTime? oldBalanceDate,
  }) async {
    final body = <String, dynamic>{
      'vehicle_id': int.parse(vehicleId),
      'customer_id': int.parse(customerId),
      if (rentalType != null) 'rental_type': rentalType,
      if (periodAmount != null) 'period_amount': periodAmount,
      if (totalAmount != null) 'total_amount': totalAmount,
      'advance_amount': advance,
      if (startDate != null) 'start_date': _dateStr(startDate),
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (oldBalance > 0) 'old_balance': oldBalance,
      if (oldBalanceDate != null) 'old_balance_date': _dateStr(oldBalanceDate),
    };
    final j = await _api.post('/rentals', body: body);
    final rental = _fromJson(j as Map<String, dynamic>);
    _cache.insert(0, rental);
    notifyListeners();
    return rental;
  }

  // ── Approval (create) ──────────────────────────────────────────────────────
  void confirm(String id, String byUserId) {
    final numId = int.tryParse(id) ?? 0;
    final r = byId(id);
    if (r != null) {
      Gate.confirm(r, byUserId: byUserId);
      notifyListeners();
    }
    unawaited(_api
        .post('/rentals/$numId/confirm')
        .then((_) => refresh())
        .catchError((_) => null));
  }

  void reject(String id, String reason, String byUserId) {
    final numId = int.tryParse(id) ?? 0;
    final r = byId(id);
    if (r != null) {
      Gate.reject(r, reason: reason, byUserId: byUserId);
      r.rentalStatus = 'cancelled';
      notifyListeners();
    }
    unawaited(_api
        .post('/rentals/$numId/reject', query: {'reason': reason})
        .then((_) => refresh())
        .catchError((_) => null));
  }

  // ── Edit ────────────────────────────────────────────────────────────────
  Future<bool> editRental(
    String id, {
    String? rentalType,
    int? periodAmount,
    int? totalAmount,
    int advance = 0,
    DateTime? startDate,
    String? remarks,
    int oldBalance = 0,
    DateTime? oldBalanceDate,
  }) async {
    final numId = int.tryParse(id) ?? 0;
    final body = <String, dynamic>{
      if (rentalType != null) 'rental_type': rentalType,
      if (periodAmount != null) 'period_amount': periodAmount,
      if (totalAmount != null) 'total_amount': totalAmount,
      'advance_amount': advance,
      'start_date': startDate == null ? null : _dateStr(startDate),
      'remarks': (remarks != null && remarks.isNotEmpty) ? remarks : null,
      'old_balance': oldBalance > 0 ? oldBalance : null,
      'old_balance_date': oldBalanceDate == null ? null : _dateStr(oldBalanceDate),
    };
    final j = await _api.post('/rentals/$numId/edit', body: body);
    final rental = _fromJson(j as Map<String, dynamic>);
    _replace(rental);
    return rental.isEditPending;
  }

  Future<void> approveEdit(String id) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(
        await _api.post('/rentals/$numId/edit/approve') as Map<String, dynamic>));
  }

  Future<void> rejectEdit(String id, String reason) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(await _api.post('/rentals/$numId/edit/reject',
        query: {'reason': reason}) as Map<String, dynamic>));
  }

  // ── Reminders / collections ─────────────────────────────────────────────
  Future<void> addReminder(String id,
      {required DateTime dueDate, required int amount}) async {
    final j = await _api.post('/rentals/$id/reminders',
        body: {'due_date': _dateStr(dueDate), 'amount': amount});
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  Future<void> takeCall(String installmentId) async {
    final j = await _api.post('/rentals/installments/$installmentId/take');
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  Future<void> cancelReminder(String installmentId, String reason) async {
    final j = await _api.post('/rentals/installments/$installmentId/cancel',
        query: {'reason': reason});
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  Future<void> submitPayment(String installmentId,
      {required int amount,
      Uint8List? screenshot,
      String? filename,
      String? mimeType,
      DateTime? paidOn}) async {
    final j = await _api.postMultipart(
      '/rentals/installments/$installmentId/pay',
      fields: {
        'amount': '$amount',
        if (paidOn != null) 'paid_on': _dateStr(paidOn),
      },
      fileField: screenshot == null ? null : 'screenshot',
      filename: filename,
      bytes: screenshot,
      mimeType: mimeType,
    );
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  Future<void> submitManualPayment(String rentalId,
      {required int amount,
      Uint8List? screenshot,
      String? filename,
      String? mimeType,
      DateTime? paidOn}) async {
    final j = await _api.postMultipart(
      '/rentals/$rentalId/pay',
      fields: {
        'amount': '$amount',
        if (paidOn != null) 'paid_on': _dateStr(paidOn),
      },
      fileField: screenshot == null ? null : 'screenshot',
      filename: filename,
      bytes: screenshot,
      mimeType: mimeType,
    );
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  Future<void> approvePayment(String paymentId) async {
    _replace(_fromJson(await _api.post('/rentals/payments/$paymentId/approve')
        as Map<String, dynamic>));
  }

  Future<void> declinePayment(String paymentId, String reason) async {
    _replace(_fromJson(await _api.post('/rentals/payments/$paymentId/decline',
        query: {'reason': reason}) as Map<String, dynamic>));
  }

  String screenshotUrl(int docId) =>
      _api.absoluteUrl('/rentals/payments/documents/$docId');

  Future<Uint8List> screenshotBytes(int docId) =>
      _api.getBytes('/rentals/payments/documents/$docId');

  // ── Completion / seize ───────────────────────────────────────────────────
  Future<void> complete(String id) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(
        await _api.post('/rentals/$numId/complete') as Map<String, dynamic>));
  }

  Future<void> seize(String id, String reason) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(await _api.post('/rentals/$numId/seize',
        query: {'reason': reason}) as Map<String, dynamic>));
  }

  Future<void> approveSeize(String id) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(
        await _api.post('/rentals/$numId/seize/approve') as Map<String, dynamic>));
  }

  Future<void> rejectSeize(String id, String reason) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(await _api.post('/rentals/$numId/seize/reject',
        query: {'reason': reason}) as Map<String, dynamic>));
  }

  Future<void> cancelSeize(String id, String remarks) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(await _api.post('/rentals/$numId/seize/cancel',
        query: {'remarks': remarks}) as Map<String, dynamic>));
  }

  Future<void> confirmSeize(String id, String remarks) async {
    final numId = int.tryParse(id) ?? 0;
    _replace(_fromJson(await _api.post('/rentals/$numId/seize/confirm',
        query: {'remarks': remarks}) as Map<String, dynamic>));
  }

  void delete(String id) {
    final numId = int.tryParse(id) ?? 0;
    unawaited(_api.delete('/rentals/$numId').catchError((_) => null));
    _cache.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // ── Parsing ──────────────────────────────────────────────────────────────
  RentalAgreement _fromJson(Map<String, dynamic> j) {
    final installments = (j['installments'] as List? ?? [])
        .map((i) => _installmentFromJson(i as Map<String, dynamic>))
        .toList();
    final payments = (j['payments'] as List? ?? [])
        .map((p) => _paymentFromJson(p as Map<String, dynamic>))
        .toList();
    return RentalAgreement(
      id: (j['id'] as int).toString(),
      vehicleId: (j['vehicle_id'] as int).toString(),
      customerId: (j['customer_id'] as int).toString(),
      rentalType: j['rental_type'] as String?,
      periodAmount: (j['period_amount'] as num?)?.round() ?? 0,
      totalAmount: (j['total_amount'] as num?)?.round() ?? 0,
      advance: (j['advance_amount'] as num?)?.round() ?? 0,
      remainingAmount: (j['remaining_amount'] as num?)?.round() ?? 0,
      startDate: _parseDate(j['start_date'] as String?),
      invoiceNo: j['invoice_no'] as String?,
      remarks: j['remarks'] as String?,
      oldBalance: (j['old_balance'] as num?)?.round() ?? 0,
      oldBalanceDate: _parseDate(j['old_balance_date'] as String?),
      installments: installments,
      payments: payments,
      rentalStatus: (j['rental_status'] as String?) ?? 'active',
      completedAt: j['completed_at'] == null
          ? null
          : DateTime.tryParse(j['completed_at'] as String),
      createdBy: (j['created_by'] as int? ?? 0).toString(),
      createdAt: _parseUtc(j['created_at'] as String?),
      status: EntityStatus.fromWire((j['status'] as String?) ?? 'active'),
      confirmedBy: (j['confirmed_by'] as int?)?.toString(),
      confirmedAt: j['confirmed_at'] == null
          ? null
          : DateTime.tryParse(j['confirmed_at'] as String),
      rejectionReason: j['rejection_reason'] as String?,
      seizedAt: j['seized_at'] == null
          ? null
          : DateTime.tryParse(j['seized_at'] as String),
      seizedBy: (j['seized_by'] as int?)?.toString(),
      seizeReason: j['seize_reason'] as String?,
      seizeStage: j['seize_stage'] as String?,
      seizeConfirmedAt: j['seize_confirmed_at'] == null
          ? null
          : DateTime.tryParse(j['seize_confirmed_at'] as String),
      seizeConfirmRemarks: j['seize_confirm_remarks'] as String?,
      seizeCancelRemarks: j['seize_cancel_remarks'] as String?,
      pendingEdit: (j['pending_edit'] as Map?)?.cast<String, dynamic>(),
      editStage: j['edit_stage'] as String?,
      editRequestedBy: (j['edit_requested_by'] as int?)?.toString(),
    );
  }

  Installment _installmentFromJson(Map<String, dynamic> j) => Installment(
        id: (j['id'] as int).toString(),
        monthNumber: j['number'] as int,
        dueDate:
            DateTime.tryParse((j['due_date'] as String?) ?? '') ?? DateTime.now(),
        amount: (j['amount'] as num).round(),
        paidDate: j['paid_date'] == null
            ? null
            : DateTime.tryParse(j['paid_date'] as String),
        status: (j['status'] as String?) ?? 'pending',
        takenBy: (j['taken_by'] as int?)?.toString(),
        createdBy: (j['created_by'] as int?)?.toString(),
        cancelReason: j['cancel_reason'] as String?,
      );

  SalePayment _paymentFromJson(Map<String, dynamic> j) => SalePayment(
        id: (j['id'] as int).toString(),
        installmentId: (j['installment_id'] as int?)?.toString(),
        amount: (j['amount'] as num).round(),
        status: (j['status'] as String?) ?? 'active',
        documentIds:
            ((j['document_ids'] as List?) ?? []).map((e) => e as int).toList(),
        rejectionReason: j['rejection_reason'] as String?,
        paidAt: _parseUtc(j['paid_at'] as String?),
        kind: j['kind'] as String?,
      );

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? s) =>
      s == null ? null : DateTime.tryParse(s);

  static DateTime _parseUtc(String? s) {
    if (s == null || s.isEmpty) return DateTime.now().toUtc();
    final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
    return DateTime.parse(hasZone ? s : '${s}Z');
  }
}
