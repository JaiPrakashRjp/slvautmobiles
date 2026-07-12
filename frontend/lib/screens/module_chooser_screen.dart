import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';
import '../models/search_result.dart';
import '../services/api_notification_service.dart';
import '../services/global_search_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import '../utils/responsive.dart';
import '../viewmodels/module_chooser_viewmodel.dart';
import '../widgets/app_card.dart';
import 'auto_sale/auto_sale_home_screen.dart';
import 'auto_sale/customer_detail_screen.dart';
import 'auto_sale/vehicle_detail_screen.dart';
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
              const _GlobalSearchBar(),
              const SizedBox(height: AppSpacing.lg),
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

/// Global search — find a customer or vehicle by name / phone / vehicle no.
/// Fires only after 4 characters (debounced), hitting the indexed backend.
class _GlobalSearchBar extends StatefulWidget {
  const _GlobalSearchBar();

  @override
  State<_GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<_GlobalSearchBar> {
  final _ctrl = TextEditingController();
  final _service = GlobalSearchService();
  Timer? _debounce;
  List<SearchResult> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < GlobalSearchService.minChars) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await _service.search(q);
        if (mounted) {
          setState(() {
            _results = r;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _results = [];
            _loading = false;
          });
        }
      }
    });
  }

  void _open(SearchResult r) {
    final route = r.kind == 'customer'
        ? MaterialPageRoute<void>(
            builder: (_) => CustomerDetailScreen(customerId: '${r.id}'))
        : MaterialPageRoute<void>(
            builder: (_) => VehicleDetailScreen(vehicleId: '${r.id}'));
    Navigator.of(context).push(route);
  }

  void _openVehicle(int id) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VehicleDetailScreen(vehicleId: '$id'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tooShort =
        _ctrl.text.trim().isNotEmpty &&
        _ctrl.text.trim().length < GlobalSearchService.minChars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search vehicle no, name or phone…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                    },
                  ),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
        if (tooShort)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Type at least 4 characters…',
                style: AppTextStyles.caption.copyWith(color: c.textSub)),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _results.length; i++) ...[
                  ListTile(
                    dense: true,
                    leading: Icon(
                      _results[i].kind == 'customer'
                          ? Icons.person_outline
                          : Icons.directions_car_outlined,
                      color: c.primary,
                    ),
                    title: Text(_results[i].label),
                    subtitle: _results[i].subtitle.isEmpty
                        ? null
                        : Text(_results[i].subtitle),
                    trailing: Text(
                      _results[i].kind == 'customer' ? 'Customer' : 'Vehicle',
                      style: AppTextStyles.caption.copyWith(color: c.textSub),
                    ),
                    onTap: () => _open(_results[i]),
                  ),
                  // A customer's vehicles listed beneath them (tap → vehicle).
                  for (final v in _results[i].vehicles)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 40, right: 16),
                      leading: Icon(Icons.directions_car_outlined,
                          color: c.textSub, size: 18),
                      title: Text(v.label,
                          style:
                              AppTextStyles.body.copyWith(color: c.textMain)),
                      subtitle:
                          v.subtitle.isEmpty ? null : Text(v.subtitle),
                      onTap: () => _openVehicle(v.id),
                    ),
                  if (i != _results.length - 1)
                    Divider(height: 1, color: c.borderColor),
                ],
              ],
            ),
          ),
        ] else if (!_loading &&
            _ctrl.text.trim().length >= GlobalSearchService.minChars) ...[
          const SizedBox(height: 8),
          Text('No matches.',
              style: AppTextStyles.body.copyWith(color: c.textSub)),
        ],
      ],
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
