import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/enums.dart';
import '../utils/id_gen.dart';

/// Manages staff (Admin) accounts. Super Admin only (enforced in the UI).
abstract class UserService extends ChangeNotifier {
  /// Loads users from the backing store (no-op for the in-memory mock).
  Future<void> refresh() async {}

  List<AppUser> admins();
  AppUser? byId(String id);
  Future<AppUser> create({
    required String name,
    required String phone,
    String? email,
    required String password,
    Role role = Role.admin,
    required List<AppModule> moduleAccess,
  });
  void update(AppUser user);
  void setModuleAccess(String id, List<AppModule> modules);
  void verify(String id);
  void suspend(String id);
  void delete(String id);
  String generateTempPassword();
}

class MockUserService extends UserService {
  MockUserService() {
    _seed();
  }

  final List<AppUser> _admins = [];

  void _seed() {
    _admins.addAll([
      AppUser(
        id: 'u_admin_ravi',
        name: 'Ravi',
        phone: '+919900000002',
        role: Role.admin,
        moduleAccess: const [AppModule.autoSale, AppModule.rentals],
        status: AccountStatus.active,
        createdAt: DateTime(2026, 2, 1),
        createdBy: 'u_super',
      ),
      AppUser(
        id: 'u_admin_vijay',
        name: 'Vijay',
        phone: '+919900000003',
        role: Role.admin,
        moduleAccess: const [AppModule.loans],
        status: AccountStatus.pendingVerification,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'u_super',
      ),
    ]);
  }

  @override
  List<AppUser> admins() => List.unmodifiable(_admins);

  @override
  AppUser? byId(String id) =>
      _admins.where((u) => u.id == id).cast<AppUser?>().firstOrNull;

  @override
  Future<AppUser> create({
    required String name,
    required String phone,
    String? email,
    required String password,
    Role role = Role.admin,
    required List<AppModule> moduleAccess,
  }) async {
    final user = AppUser(
      id: IdGen.nextId('u'),
      name: name,
      phone: phone,
      email: email,
      role: role,
      moduleAccess: moduleAccess,
      // New admins must change password + complete profile, then SA verifies.
      status: AccountStatus.pendingProfile,
      createdAt: DateTime.now(),
      createdBy: 'u_super',
    );
    _admins.insert(0, user);
    notifyListeners();
    return user;
  }

  @override
  void update(AppUser user) {
    final i = _admins.indexWhere((u) => u.id == user.id);
    if (i != -1) _admins[i] = user;
    notifyListeners();
  }

  @override
  void setModuleAccess(String id, List<AppModule> modules) {
    byId(id)?.moduleAccess = modules;
    notifyListeners();
  }

  @override
  void verify(String id) {
    byId(id)?.status = AccountStatus.active;
    notifyListeners();
  }

  @override
  void suspend(String id) {
    byId(id)?.status = AccountStatus.suspended;
    notifyListeners();
  }

  @override
  void delete(String id) {
    _admins.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  @override
  String generateTempPassword() {
    // Deterministic-ish 8-char temp password (mock; real flow SMSes it).
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final seed = _admins.length + DateTime.now().second;
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(chars[(seed * (i + 3) + i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}
