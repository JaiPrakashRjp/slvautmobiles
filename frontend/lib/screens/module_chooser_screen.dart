import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';
import '../services/api_notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import '../utils/responsive.dart';
import '../viewmodels/module_chooser_viewmodel.dart';
import '../widgets/app_card.dart';
import 'auto_sale/auto_sale_home_screen.dart';
import 'loan/loan_home_screen.dart';
import 'notifications_screen.dart';
import 'rental/rental_home_screen.dart';
import 'sign_in_screen.dart';
import 'users/users_home_screen.dart';

/// Module chooser — matches mockup 02-module-chooser.png.
class ModuleChooserScreen extends StatelessWidget {
  const ModuleChooserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ModuleChooserViewModel(context.read<AuthController>()),
      child: const _ModuleChooserView(),
    );
  }
}

class _ModuleChooserView extends StatelessWidget {
  const _ModuleChooserView();

  void _open(BuildContext context, AppModule module) {
    // Each module home is wired here as it is built (Phases 2–5).
    // Until then, surface a friendly placeholder.
    final route = _routeFor(module);
    if (route != null) {
      Navigator.of(context).push(route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${module.label} — coming in a later phase')),
      );
    }
  }

  /// Returns the route for a module, or null if not built yet.
  /// (Filled in incrementally as modules land.)
  Route<dynamic>? _routeFor(AppModule module) {
    switch (module) {
      case AppModule.autoSale:
        return MaterialPageRoute(builder: (_) => const AutoSaleHomeScreen());
      case AppModule.rentals:
        return MaterialPageRoute(builder: (_) => const RentalHomeScreen());
      case AppModule.loans:
        return MaterialPageRoute(builder: (_) => const LoanHomeScreen());
      case AppModule.users:
        return MaterialPageRoute(builder: (_) => const UsersHomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<ModuleChooserViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Choose module'),
        actions: [
          const _NotificationsBell(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthController>().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SignInScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.screenHPadding,
              vertical: AppSpacing.xl,
            ),
            children: [
              if (vm.greetingName.isNotEmpty) ...[
                Text(
                  'Welcome, ${vm.greetingName}',
                  style: AppTextStyles.body.copyWith(color: c.textSub),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              for (var i = 0; i < vm.tiles.length; i++) ...[
                _ModuleCard(
                  tile: vm.tiles[i],
                  selected: i == 0,
                  onTap: () => _open(context, vm.tiles[i].module),
                ),
                if (i != vm.tiles.length - 1)
                  const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// App-bar bell with an unread-count badge. Opens the notifications list.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = context.watch<NotificationFeed>().unreadCount;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.tile,
    required this.onTap,
    this.selected = false,
  });

  final ModuleTile tile;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(tile.icon, size: 40, color: c.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            tile.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(color: c.textMain),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tile.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: c.textSub),
          ),
        ],
      ),
    );
  }
}
