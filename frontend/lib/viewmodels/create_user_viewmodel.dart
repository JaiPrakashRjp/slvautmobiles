import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../services/user_service.dart';

/// Backs the create-admin form (spec 6.2.2).
enum PasswordStrength { none, weak, average, strong }

class CreateUserViewModel extends ChangeNotifier {
  CreateUserViewModel(this._users) {
    passwordController.addListener(_onPasswordChanged);
  }

  final UserService _users;

  final nameController     = TextEditingController();
  final phoneController    = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  PasswordStrength _passwordStrength = PasswordStrength.none;
  PasswordStrength get passwordStrength => _passwordStrength;

  final Set<AppModule> _modules = {};

  // Auto sale + Auto rental + Loan management are grantable.
  static const grantable = [
    AppModule.autoSale,
    AppModule.rentals,
    AppModule.loans,
  ];
  Set<AppModule> get modules => _modules;

  void toggleModule(AppModule m) {
    _modules.contains(m) ? _modules.remove(m) : _modules.add(m);
    notifyListeners();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void _onPasswordChanged() {
    _passwordStrength = _assess(passwordController.text);
    notifyListeners();
  }

  static PasswordStrength _assess(String pw) {
    if (pw.isEmpty) return PasswordStrength.none;
    if (pw.length < 6) return PasswordStrength.weak;
    final hasUpper   = pw.contains(RegExp(r'[A-Z]'));
    final hasLower   = pw.contains(RegExp(r'[a-z]'));
    final hasDigit   = pw.contains(RegExp(r'[0-9]'));
    final hasSpecial = pw.contains(RegExp(r'[^A-Za-z0-9]'));
    final score = [hasUpper, hasLower, hasDigit, hasSpecial].where((b) => b).length;
    if (pw.length >= 8 && score >= 3) return PasswordStrength.strong;
    if (pw.length >= 6 && score >= 2) return PasswordStrength.average;
    return PasswordStrength.weak;
  }

  String? validate({required String? Function(String?) phoneValidator}) {
    if (nameController.text.trim().isEmpty) return 'Name is required';
    final phoneErr = phoneValidator(phoneController.text);
    if (phoneErr != null) return phoneErr;
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return 'A valid email is required';
    if (passwordController.text.length < 6) return 'Password must be at least 6 characters';
    if (_modules.isEmpty) return 'Grant at least one module';
    return null;
  }

  Future<void> submit() {
    return _users.create(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
      password: passwordController.text,
      moduleAccess: _modules.toList(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
