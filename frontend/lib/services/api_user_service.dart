import 'dart:async';

import '../models/app_user.dart';
import '../models/enums.dart';
import 'api_client.dart';
import 'user_service.dart';

/// Real [UserService] backed by the FastAPI backend (/users, /roles).
///
/// Keeps an in-memory cache so the synchronous getters (`admins()`, `byId()`)
/// and ChangeNotifier reactivity keep working; mutations update the cache and
/// fire the backend call.
class ApiUserService extends UserService {
  ApiUserService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  final List<AppUser> _users = [];

  @override
  Future<void> refresh() async {
    final data = await _api.get('/users');
    _users
      ..clear()
      ..addAll((data as List).map((j) => _fromJson(j as Map<String, dynamic>)));
    notifyListeners();
  }

  /// The users-management list shows staff admins, not the super admin(s).
  @override
  List<AppUser> admins() =>
      List.unmodifiable(_users.where((u) => u.role == Role.admin));

  @override
  AppUser? byId(String id) =>
      _users.where((u) => u.id == id).cast<AppUser?>().firstOrNull;

  @override
  Future<AppUser> create({
    required String name,
    required String phone,
    String? email,
    required String password,
    Role role = Role.admin,
    required List<AppModule> moduleAccess,
  }) async {
    final parts = name.trim().split(RegExp(r'\s+'));
    final firstName = parts.isEmpty ? name : parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    // created_by is derived from the Bearer token server-side.
    final json = await _api.post(
      '/users',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'role': role.wire,
        'password': password,
        'module_codes': moduleAccess.map((m) => m.backendCode).toList(),
      },
    );
    final user = _fromJson(json as Map<String, dynamic>);
    _users.insert(0, user);
    notifyListeners();
    return user;
  }

  @override
  void update(AppUser user) {
    final i = _users.indexWhere((u) => u.id == user.id);
    if (i != -1) _users[i] = user;
    notifyListeners();
    unawaited(_api.patch('/users/${user.id}', body: {
      'first_name': user.name.split(RegExp(r'\s+')).first,
      'phone': user.phone,
      if (user.email != null) 'email': user.email,
    }).catchError((_) => null));
  }

  @override
  void setModuleAccess(String id, List<AppModule> modules) {
    byId(id)?.moduleAccess = modules;
    notifyListeners();
    // by_user_id is derived from the Bearer token server-side.
    unawaited(_api.put(
      '/users/$id/modules',
      body: {'module_codes': modules.map((m) => m.backendCode).toList()},
    ).catchError((_) => null));
  }

  @override
  void verify(String id) {
    byId(id)?.status = AccountStatus.active;
    notifyListeners();
    unawaited(_api.post('/users/$id/activate').catchError((_) => null));
  }

  @override
  void suspend(String id) {
    byId(id)?.status = AccountStatus.suspended;
    notifyListeners();
    unawaited(_api.post('/users/$id/suspend').catchError((_) => null));
  }

  @override
  void delete(String id) {
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
    unawaited(_api.delete('/users/$id').catchError((_) => null));
  }

  @override
  String generateTempPassword() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final seed = _users.length + DateTime.now().second;
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(chars[(seed * (i + 3) + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  // ── JSON mapping ────────────────────────────────────────────────────────────
  AppUser _fromJson(Map<String, dynamic> j) {
    final first = (j['first_name'] as String?) ?? '';
    final last = (j['last_name'] as String?) ?? '';
    final modules = (j['module_codes'] as List?)
            ?.map((c) => AppModule.fromBackendCode(c as String))
            .toList() ??
        <AppModule>[];
    return AppUser(
      id: j['id'].toString(),
      name: last.isEmpty ? first : '$first $last',
      phone: (j['phone'] as String?) ?? '',
      email: j['email'] as String?,
      role: Role.fromWire((j['role'] as String?) ?? 'admin'),
      moduleAccess: modules,
      status: _status(
        (j['account_status'] as String?) ?? 'active',
        (j['status'] as String?) ?? 'active',
      ),
      createdAt: DateTime.tryParse((j['created_at'] as String?) ?? '') ??
          DateTime.now(),
      createdBy: j['created_by']?.toString(),
    );
  }

  static AccountStatus _status(String account, String entity) {
    if (account == 'suspended') return AccountStatus.suspended;
    if (entity != 'active') return AccountStatus.pendingVerification;
    return AccountStatus.active;
  }
}
