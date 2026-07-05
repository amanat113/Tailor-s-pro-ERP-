import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/order_repository.dart';
import '../data/settings_repository.dart';
import '../data/staff_repository.dart';
import '../models/app_role.dart';
import '../widgets/ui.dart';
import 'analytics_screen.dart';
import 'delivery_screen.dart';
import 'home_screen.dart';
import 'new_order_screen.dart';
import 'processing_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final OrderRepository _orders = OrderRepository();
  final SettingsRepository _settings = SettingsRepository();
  final StaffRepository _staff = StaffRepository();

  @override
  Widget build(BuildContext context) {
    final role = widget.controller.state.session?.role ?? AppRole.staff;
    final pageIndex = widget.controller.state.pageIndex;
    final pages = <Widget>[
      HomeScreen(controller: widget.controller, orderRepository: _orders),
      ProcessingScreen(orderRepository: _orders),
      NewOrderScreen(orderRepository: _orders, settingsRepository: _settings),
      DeliveryScreen(orderRepository: _orders),
      _MorePage(controller: widget.controller, role: role, settingsRepository: _settings, staffRepository: _staff),
    ];
    return Scaffold(
      extendBody: true,
      drawer: _AppDrawer(controller: widget.controller, role: role),
      appBar: AppBar(
        title: const Text("Tailor's ERP", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          IconButton(onPressed: () => widget.controller.logout(), icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: pages[pageIndex],
      bottomNavigationBar: _FloatingNav(
        index: pageIndex,
        onChanged: widget.controller.changePage,
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.controller, required this.role});

  final AppController controller;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.checkroom_rounded, size: 52, color: AppColors.bronze),
                  SizedBox(height: 10),
                  Text("Tailor's ERP", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('Professional shop management', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            _tile(context, Icons.home_rounded, 'Home', 0),
            _tile(context, Icons.handyman_rounded, 'Progress', 1),
            if (role.canManageOrders) _tile(context, Icons.add_shopping_cart_rounded, 'New Order', 2),
            _tile(context, Icons.local_shipping_rounded, 'Delivery', 3),
            _tile(context, Icons.dashboard_customize_rounded, 'More', 4),
            const Spacer(),
            ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Logout'), onTap: () => controller.logout()),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon, color: AppColors.navy),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      onTap: () {
        Navigator.pop(context);
        controller.changePage(index);
      },
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      const _NavItem(Icons.home_rounded, 'Home'),
      const _NavItem(Icons.bar_chart_rounded, 'Progress'),
      const _NavItem(Icons.add_rounded, 'New'),
      const _NavItem(Icons.local_shipping_rounded, 'Delivery'),
      const _NavItem(Icons.grid_view_rounded, 'More'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(38),
            boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12))],
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List<Widget>.generate(items.length, (i) {
              final selected = i == index;
              final center = i == 2;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(36),
                  onTap: () => onChanged(i),
                  child: center
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(color: AppColors.bronze, shape: BoxShape.circle),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(items[i].icon, color: selected ? AppColors.navy : AppColors.muted),
                            const SizedBox(height: 2),
                            Text(items[i].label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? AppColors.navy : AppColors.muted)),
                          ],
                        ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _MorePage extends StatelessWidget {
  const _MorePage({required this.controller, required this.role, required this.settingsRepository, required this.staffRepository});

  final AppController controller;
  final AppRole role;
  final SettingsRepository settingsRepository;
  final StaffRepository staffRepository;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: <Widget>[
          const Text('More', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _moreTile(context, Icons.groups_rounded, 'Staff Ledger', 'Daily work and payment records', () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffScreen(staffRepository: staffRepository, ownerMode: role.canManageStaff)))),
          _moreTile(context, Icons.analytics_rounded, 'Analytics', 'Revenue, due and delivery reports', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen()))),
          if (role.canOpenSettings) _moreTile(context, Icons.settings_rounded, 'Settings', 'Shop setup, measurements and backup', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settingsRepository: settingsRepository)))),
          _moreTile(context, Icons.logout_rounded, 'Logout', 'Close current secure session', () => controller.logout()),
        ],
      ),
    );
  }

  Widget _moreTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          minVerticalPadding: 18,
          leading: CircleAvatar(backgroundColor: AppColors.paper, foregroundColor: AppColors.navy, child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
