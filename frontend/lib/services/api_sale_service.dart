import 'dart:async';
import 'dart:typed_data';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';
import '../models/installment.dart';
import '../models/reminder_log.dart';
import '../models/sale.dart';
import '../models/sale_payment.dart';
import 'api_client.dart';
import 'gate.dart';
import 'sale_service.dart';

class ApiSaleService extends SaleService {
  ApiSaleService({ApiClient? client, AuthController? auth})
      : _api = client ?? ApiClient(),
        _auth = auth;

  final ApiClient _api;
  final AuthController? _auth;
  final List<Sale> _cache = [];

  @override
  List<Sale> all() => List.unmodifiable(_cache);

  @override
  Sale? byId(String id) =>
      _cache.where((s) => s.id == id).cast<Sale?>().firstOrNull;

  @override
  Sale? forVehicle(String vehicleId) => _cache
      .where((s) =>
          s.vehicleId == vehicleId &&
          s.saleStatus != 'cancelled' &&
          s.saleStatus != 'seized')
      .cast<Sale?>()
      .firstOrNull;

  @override
  List<Sale> seizedForVehicle(String vehicleId) => _cache
      .where((s) => s.vehicleId == vehicleId && s.saleStatus == 'seized')
      .toList();

  @override
  List<Sale> forCustomer(String customerId) =>
      _cache.where((s) => s.customerId == customerId).toList();

  @override
  Future<void> refresh() async {
    final userId = _auth?.currentUserId ?? 0;
    if (userId == 0) {
      _cache.clear();
      notifyListeners();
      return;
    }
    try {
      final data = await _api.get('/sales');
      _cache
        ..clear()
        ..addAll((data as List)
            .map((j) => _fromJson(j as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {}
  }

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
    // deposit_type (full cash / down payment) is DERIVED on the server.
    final body = <String, dynamic>{
      'vehicle_id': int.parse(vehicleId),
      'customer_id': int.parse(customerId),
      'sale_date': _dateStr(saleDate),
      'vehicle_amount': vehicleAmount,
      'additional_fitting': additionalFitting,
      'dl_charges': dlCharges,
      'document_charges': documentCharges,
      'other_expenses': otherExpenses,
      'amount_received': downPayment,
      'remaining_amount': remainingAmount,
      if (hpAmount != null) 'hp_amount': hpAmount,
      'customer_whatsapp': customerWhatsapp,
      if (financerId != null) 'financer_id': financerId,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };
    // created_by + actor_role are derived from the Bearer token server-side.
    final j = await _api.post('/sales', body: body);
    final sale = _fromJson(j as Map<String, dynamic>);
    _cache.insert(0, sale);
    notifyListeners();
    return sale;
  }

  @override
  Future<void> markPaid(String saleId, String installmentId) async {
    final instId = int.tryParse(installmentId) ?? 0;
    // recorded_by comes from the Bearer token server-side.
    await _api.post('/sales/installments/$instId/pay');
    final sale = byId(saleId);
    if (sale != null) {
      final idx =
          sale.installments.indexWhere((i) => i.id == installmentId);
      if (idx != -1) {
        sale.installments[idx].paidDate = DateTime.now();
        if (sale.installments.every((i) => i.isPaid)) {
          sale.saleStatus = 'closed';
        }
      }
      notifyListeners();
    }
  }

  @override
  Future<void> payOff(String saleId) async {
    final id = int.tryParse(saleId) ?? 0;
    // recorded_by comes from the Bearer token server-side.
    await _api.post('/sales/$id/payoff');
    final sale = byId(saleId);
    if (sale != null) {
      final now = DateTime.now();
      for (final inst in sale.installments) {
        inst.paidDate ??= now;
      }
      sale.saleStatus = 'closed';
      sale.closedAt = now;
      notifyListeners();
    }
  }

  @override
  Future<List<ReminderLog>> remindersForSale(String saleId) async {
    final id = int.tryParse(saleId) ?? 0;
    try {
      final data = await _api.get('/sales/$id/reminders');
      return (data as List)
          .map((j) => ReminderLog.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Reminders / collections ─────────────────────────────────────────────
  void _replace(Sale sale) {
    final idx = _cache.indexWhere((s) => s.id == sale.id);
    if (idx != -1) {
      _cache[idx] = sale;
    } else {
      _cache.insert(0, sale);
    }
    notifyListeners();
  }

  @override
  Future<void> addReminder(String saleId,
      {required DateTime dueDate, required int amount}) async {
    final j = await _api.post('/sales/$saleId/reminders',
        body: {'due_date': _dateStr(dueDate), 'amount': amount});
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  @override
  Future<void> takeCall(String saleId, String installmentId) async {
    final id = int.tryParse(installmentId) ?? 0;
    final j = await _api.post('/sales/installments/$id/take');
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  @override
  Future<void> cancelReminder(
      String saleId, String installmentId, String reason) async {
    final id = int.tryParse(installmentId) ?? 0;
    final j = await _api.post('/sales/installments/$id/cancel',
        query: {'reason': reason});
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  @override
  Future<void> submitPayment(String saleId, String installmentId,
      {required int amount,
      required Uint8List screenshot,
      required String filename,
      String? mimeType}) async {
    final id = int.tryParse(installmentId) ?? 0;
    final j = await _api.postMultipart(
      '/sales/installments/$id/pay',
      fields: {'amount': '$amount'},
      fileField: 'screenshot',
      filename: filename,
      bytes: screenshot,
      mimeType: mimeType,
    );
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  @override
  Future<void> approvePayment(String saleId, String paymentId) async {
    final id = int.tryParse(paymentId) ?? 0;
    final j = await _api.post('/sales/payments/$id/approve');
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  @override
  Future<void> declinePayment(
      String saleId, String paymentId, String reason) async {
    final id = int.tryParse(paymentId) ?? 0;
    final j = await _api.post('/sales/payments/$id/decline',
        query: {'reason': reason});
    _replace(_fromJson(j as Map<String, dynamic>));
  }

  @override
  String screenshotUrl(int docId) =>
      _api.absoluteUrl('/sales/payments/documents/$docId');

  @override
  Future<Uint8List> screenshotBytes(int docId) =>
      _api.getBytes('/sales/payments/documents/$docId');

  @override
  Future<void> cancel(String saleId, String reason, String byUserId) async {
    final numId = int.tryParse(saleId) ?? 0;
    // by_user_id comes from the Bearer token server-side.
    final j = await _api.post('/sales/$numId/cancel', query: {'reason': reason});
    final updated = _fromJson(j as Map<String, dynamic>);
    final idx = _cache.indexWhere((s) => s.id == saleId);
    if (idx != -1) {
      _cache[idx] = updated;
    }
    notifyListeners();
  }

  @override
  Future<void> seize(String saleId, String reason, String byUserId) async {
    final numId = int.tryParse(saleId) ?? 0;
    // by_user_id comes from the Bearer token server-side.
    final j = await _api.post('/sales/$numId/seize', query: {'reason': reason});
    final updated = _fromJson(j as Map<String, dynamic>);
    final idx = _cache.indexWhere((s) => s.id == saleId);
    if (idx != -1) {
      _cache[idx] = updated;
    }
    notifyListeners();
  }

  @override
  void confirm(String id, String byUserId) {
    final numId = int.tryParse(id) ?? 0;
    // by_user_id comes from the Bearer token server-side.
    unawaited(_api
        .post('/sales/$numId/confirm')
        .catchError((_) => null));
    final sale = byId(id);
    if (sale != null) {
      Gate.confirm(sale, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final numId = int.tryParse(id) ?? 0;
    // reason stays a query param; by_user_id comes from the Bearer token.
    unawaited(_api.post('/sales/$numId/reject',
        query: {'reason': reason})
        .catchError((_) => null));
    final sale = byId(id);
    if (sale != null) {
      Gate.reject(sale, reason: reason, byUserId: byUserId);
      sale.saleStatus = 'rejected';
      notifyListeners();
    }
  }

  @override
  void delete(String id) {
    final numId = int.tryParse(id) ?? 0;
    // DELETE endpoint takes no actor params
    unawaited(_api.delete('/sales/$numId').catchError((_) => null));
    _cache.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Sale _fromJson(Map<String, dynamic> j) {
    final depositType =
        DepositType.fromWire((j['deposit_type'] as String?) ?? 'full_cash');
    final rawInstallments = j['installments'] as List? ?? [];
    final installments = rawInstallments
        .map((i) => _installmentFromJson(i as Map<String, dynamic>))
        .toList();
    final payments = (j['payments'] as List? ?? [])
        .map((p) => _paymentFromJson(p as Map<String, dynamic>))
        .toList();
    return Sale(
      id: (j['id'] as int).toString(),
      vehicleId: (j['vehicle_id'] as int).toString(),
      customerId: (j['customer_id'] as int).toString(),
      mode: depositType.paymentMode,
      salePrice: (j['sale_price'] as num?)?.round(),
      advance: (j['amount_received'] as num?)?.round() ?? 0,
      monthly: (j['monthly_amount'] as num?)?.round() ?? 0,
      dueDate: _parseDate(j['first_due_date'] as String?),
      saleDate: _parseDate(j['sale_date'] as String?),
      vehicleAmount: (j['vehicle_amount'] as num?)?.round() ?? 0,
      additionalFitting: (j['additional_fitting'] as num?)?.round() ?? 0,
      dlCharges: (j['dl_charges'] as num?)?.round() ?? 0,
      documentCharges: (j['document_charges'] as num?)?.round() ?? 0,
      otherExpenses: (j['other_expenses'] as num?)?.round() ?? 0,
      hpAmount: (j['hp_amount'] as num?)?.round(),
      remainingAmount: (j['remaining_amount'] as num?)?.round() ?? 0,
      customerWhatsapp: (j['customer_whatsapp'] as String?) ?? '',
      financerId: j['financer_id'] as int?,
      financerName: j['financer_name'] as String?,
      invoiceNo: j['invoice_no'] as String?,
      closedAt: j['closed_at'] == null
          ? null
          : DateTime.tryParse(j['closed_at'] as String),
      installments: installments,
      payments: payments,
      saleStatus: (j['sale_status'] as String?) ?? 'active',
      createdBy: (j['created_by'] as int? ?? 0).toString(),
      createdAt: _parseUtc(j['created_at'] as String?),
      // SaleOut uses "status" (not "entity_status") for the gated entity status
      status: EntityStatus.fromWire((j['status'] as String?) ?? 'active'),
      unsellReason: j['unsell_reason'] as String?,
      seizedAt: j['seized_at'] == null
          ? null
          : DateTime.tryParse(j['seized_at'] as String),
      seizeReason: j['seize_reason'] as String?,
      remarks: j['remarks'] as String?,
    );
  }

  Installment _installmentFromJson(Map<String, dynamic> j) {
    return Installment(
      id: (j['id'] as int).toString(),
      monthNumber: j['month_number'] as int,
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
  }

  SalePayment _paymentFromJson(Map<String, dynamic> j) {
    return SalePayment(
      id: (j['id'] as int).toString(),
      installmentId: (j['installment_id'] as int?)?.toString(),
      amount: (j['amount'] as num).round(),
      status: (j['status'] as String?) ?? 'active',
      documentIds:
          ((j['document_ids'] as List?) ?? []).map((e) => e as int).toList(),
      rejectionReason: j['rejection_reason'] as String?,
    );
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? s) =>
      s == null ? null : DateTime.tryParse(s);

  /// Parses a backend timestamp as a UTC instant. The API sends naive UTC
  /// (no timezone suffix), so append 'Z' when none is present — otherwise
  /// DateTime would read it as device-local time and elapsed-time math (e.g. the
  /// 2-hour unsell window) would be off by the device's UTC offset.
  static DateTime _parseUtc(String? s) {
    if (s == null || s.isEmpty) return DateTime.now().toUtc();
    final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
    return DateTime.parse(hasZone ? s : '${s}Z');
  }
}
