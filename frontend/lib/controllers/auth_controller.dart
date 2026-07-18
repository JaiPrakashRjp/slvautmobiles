import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/enums.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';

/// Holds the current signed-in user and exposes role helpers used by the
/// role-gate everywhere. Backed by the FastAPI `/auth/login` endpoint
/// (email + password).
///
/// The session is persisted for 24 hours: a successful login is saved to disk
/// so it survives an app restart, and [restore] brings it back on startup while
/// it is still within the 24-hour window. After that (or on [signOut]) it is
/// cleared and the user must log in again.
class AuthController extends ChangeNotifier {
  AuthController({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kLoginAt = 'auth_login_at';
  static const _sessionDuration = Duration(hours: 24);

  AppUser? _current;
  AppUser? get currentUser => _current;
  bool get isSignedIn => _current != null;
  bool get isSuperAdmin => _current?.isSuperAdmin ?? false;

  /// Numeric backend id of the signed-in user (for created_by / actor params).
  int get currentUserId => int.tryParse(_current?.id ?? '') ?? 0;

  /// Restore a saved session on app startup, if the login is under 24 hours old.
  /// Returns true when a valid session was restored.
  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final userJson = prefs.getString(_kUser);
    final loginAtMs = prefs.getInt(_kLoginAt);
    if (token == null || userJson == null || loginAtMs == null) return false;

    final loginAt = DateTime.fromMillisecondsSinceEpoch(loginAtMs);
    if (DateTime.now().difference(loginAt) >= _sessionDuration) {
      // Session older than 24 hours — expired.
      await _clear();
      return false;
    }
    try {
      ApiClient.authToken = token;
      _current = _userFromJson(jsonDecode(userJson) as Map<String, dynamic>);
      notifyListeners();
      unawaited(PushService.registerToken());
      return true;
    } catch (_) {
      await _clear();
      return false;
    }
  }

  /// Signs in with email + password against the backend. Returns true on success.
  ///
  /// The backend responds with `{access_token, token_type, user}`. We store the
  /// token on [ApiClient] so every later request carries it as a Bearer header,
  /// and persist it (with the user + login time) for the 24-hour session.
  Future<bool> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return false;
    try {
      final json = await _api.post('/auth/login', body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      }) as Map<String, dynamic>;
      final token = json['access_token'] as String?;
      final user = json['user'] as Map<String, dynamic>;
      ApiClient.authToken = token;
      _current = _userFromJson(user);
      notifyListeners();
      // Persist the session for 24 hours (survives app restart).
      final prefs = await SharedPreferences.getInstance();
      if (token != null) await prefs.setString(_kToken, token);
      await prefs.setString(_kUser, jsonEncode(user));
      await prefs.setInt(_kLoginAt, DateTime.now().millisecondsSinceEpoch);
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
    unawaited(_clear());
    // Unregister this device (needs the token to still be set), then clear it.
    unawaited(
      PushService.unregister().whenComplete(() => ApiClient.authToken = null),
    );
  }

  /// Clear the persisted session + in-memory token.
  Future<void> _clear() async {
    ApiClient.authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    await prefs.remove(_kLoginAt);
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
