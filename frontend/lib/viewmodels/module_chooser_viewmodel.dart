import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';

/// One selectable tile on the module chooser.
class ModuleTile {
  const ModuleTile({
    required this.module,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final AppModule module;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Exposes the modules the signed-in user may open.
class ModuleChooserViewModel extends ChangeNotifier {
  ModuleChooserViewModel(this._auth);

  final AuthController _auth;

  static const _all = <ModuleTile>[
    ModuleTile(
      module: AppModule.autoSale,
      title: 'Auto sale system',
      subtitle: 'Sell and track three-wheelers',
      icon: Icons.electric_rickshaw,
    ),
    ModuleTile(
      module: AppModule.loans,
      title: 'Loan management',
      subtitle: 'Track loans and EMIs',
      icon: Icons.account_balance_wallet_outlined,
    ),
    ModuleTile(
      module: AppModule.rentals,
      title: 'Auto rental collection',
      subtitle: 'Manage rentals and weekly collection',
      icon: Icons.vpn_key_outlined,
    ),
    ModuleTile(
      module: AppModule.users,
      title: 'User management',
      subtitle: 'Create staff and assign access',
      icon: Icons.group_outlined,
    ),
  ];

  String get greetingName => _auth.currentUser?.name ?? '';

  List<ModuleTile> get tiles =>
      _all.where((t) => _auth.currentUser?.canAccess(t.module) ?? false).toList();
}
