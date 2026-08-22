import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'loan_customers_screen.dart';
import 'loan_vehicles_screen.dart';

/// Loan management shell — IndexedStack over the Vehicles and Customers tabs,
/// matching the Auto Sale module. A loan is started from a vehicle (or a
/// customer's detail); there's no separate loans list. Phone: bottom nav.
/// Tablet: side navigation rail.
class LoanHomeScreen extends StatefulWidget {
  const LoanHomeScreen({super.key});

  @override
  State<LoanHomeScreen> createState() => _LoanHomeScreenState();
}

class _LoanHomeScreenState extends State<LoanHomeScreen> {
  int _index = 0;

  static const _items = [
    BottomNavItem(icon: Icons.electric_rickshaw, label: 'Vehicles'),
    BottomNavItem(icon: Icons.people_outline, label: 'Customers'),
  ];

  final _pages = const [LoanVehiclesScreen(), LoanCustomersScreen()];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = IndexedStack(index: _index, children: _pages);

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
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: body,
      bottomNavigationBar: BottomNavBar(
        items: _items,
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
