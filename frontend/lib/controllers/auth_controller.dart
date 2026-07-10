import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/enums.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';

/// Holds the current signed-in user and exposes role helpers used by the
/// role-gate everywhere. Backed by the FastAPI `/auth/login` endpoint
/// (email + password).
class AuthController extends ChangeNotifier {
  AuthController({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  AppUser? _current;
  AppUser? get currentUser => _current;
  bool get isSignedIn => _current != null;
  bool get isSuperAdmin => _current?.isSuperAdmin ?? false;

  /// Numeric backend id of the signed-in user (for created_by / actor params).
  int get currentUserId => int.tryParse(_current?.id ?? '') ?? 0;

  /// Signs in with email + password against the backend. Returns true on success.
  ///
  /// The backend responds with `{access_token, token_type, user}`. We store the
  /// token on [ApiClient] so every later request carries it as a Bearer header,
  /// and the backend derives the acting user + role from it.
  Future<bool> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return false;
    try {
      final json = await _api.post('/auth/login', body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      }) as Map<String, dynamic>;
      ApiClient.authToken = json['access_token'] as String?;
      _current = _userFromJson(json['user'] as Map<String, dynamic>);
      notifyListeners();
      // Register this device for push now that we're authenticated.
      unawaited(PushService.registerToken());
      return true;
    } on ApiException {
      return false;
    }
  }

  void signOut() {
    _current = null;
    notifyListeners();
    // Unregister this device (needs the token to still be set), then clear it.
    unawaited(
      PushService.unregister().whenComplete(() => ApiClient.authToken = null),
    );
  }

  AppUser _userFromJson(Map<String, dynamic> j) {
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
      status: AccountStatus.active,
      createdAt: DateTime.tryParse((j['created_at'] as String?) ?? '') ??
          DateTime.now(),
      createdBy: j['created_by']?.toString(),
    );
  }
}
