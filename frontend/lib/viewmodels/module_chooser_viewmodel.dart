import 'package:flutter/material.dart';

import '../config/app_config.dart';
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
    // Auto rental — shown on dev only until it's launched on prod (gated below).
    // Loan management stays hidden (not built yet).
    ModuleTile(
      module: AppModule.rentals,
      title: 'Auto rental collection',
      subtitle: 'Rent vehicles and collect rent',
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

  List<ModuleTile> get tiles => _all.where((t) {
        if (!(_auth.currentUser?.canAccess(t.module) ?? false)) return false;
        // Rental is dev-only until launched on prod.
        if (t.module == AppModule.rentals && !AppConfig.isDev) return false;
        return true;
      }).toList();
}
