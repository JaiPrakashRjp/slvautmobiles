import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'loan_customers_screen.dart';
import 'loan_vehicles_screen.dart';

/// Loan management shell — Vehicles and Customers tabs, matching Auto Sale.
/// On phone the two tabs live in a swipeable [PageView] (slide left/right or tap
/// the footer to switch, with a sliding animation); on tablet a side rail.
/// A loan is started from a vehicle (or a customer's detail); no loans list.
class LoanHomeScreen extends StatefulWidget {
  const LoanHomeScreen({super.key});

  @override
  State<LoanHomeScreen> createState() => _LoanHomeScreenState();
}

class _LoanHomeScreenState extends State<LoanHomeScreen> {
  int _index = 0;
  final _controller = PageController();

  static const _items = [
    BottomNavItem(icon: Icons.electric_rickshaw, label: 'Vehicles'),
    BottomNavItem(icon: Icons.people_outline, label: 'Customers'),
  ];

  static const _pages = [LoanVehiclesScreen(), LoanCustomersScreen()];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToTab(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (context.isTablet) {
      return Scaffold(
        backgroundColor: c.bgCanvas,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: c.primary,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: IconThemeData(color: c.accent),
                unselectedIconTheme: IconThemeData(color: c.onPrimary),
                selectedLabelTextStyle: TextStyle(color: c.accent),
                unselectedLabelTextStyle: TextStyle(color: c.onPrimary),
                destinations: [
                  for (final it in _items)
                    NavigationRailDestination(
                      icon: Icon(it.icon),
                      label: Text(it.label),
                    ),
                ],
              ),
              Expanded(child: IndexedStack(index: _index, children: _pages)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        children: const [
          _KeepAlive(child: LoanVehiclesScreen()),
          _KeepAlive(child: LoanCustomersScreen()),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        items: _items,
        index: _index,
        onChanged: _goToTab,
      ),
    );
  }
}

/// Keeps a swiped-away page's state (search, selected tab, scroll) alive.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
