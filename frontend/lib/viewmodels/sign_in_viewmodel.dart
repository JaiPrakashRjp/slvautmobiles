import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';

/// Drives the sign-in screen: holds field state, loading, and error.
class SignInViewModel extends ChangeNotifier {
  SignInViewModel(this._auth);

  final AuthController _auth;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  bool get obscure => _obscure;
  bool get loading => _loading;
  String? get error => _error;

  void toggleObscure() {
    _obscure = !_obscure;
    notifyListeners();
  }

  /// Attempts sign-in. Returns true on success so the screen can navigate.
  Future<bool> submit() async {
    _error = null;
    _loading = true;
    notifyListeners();

    final ok = await _auth.signIn(
      emailController.text,
      passwordController.text,
    );

    _loading = false;
    if (!ok) _error = 'Wrong email or password';
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
