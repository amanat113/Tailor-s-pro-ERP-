import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/app_role.dart';
import '../../auth/presentation/auth_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.state.session;
    final role = session?.role ?? AppRole.select;
    final time = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0B1B31), Color(0xFF06101F), Color(0xFF020617)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 112,
                pinned: true,
                backgroundColor: const Color(0xEE07111F),
                title: const Text("Tailor's ERP", style: TextStyle(fontWeight: FontWeight.w900)),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: () => controller.logout(),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 58, 18, 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Logged in as ${role.label}\n$time',
                            style: const TextStyle(color: Color(0xFFB9C6D8), height: 1.35),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: controller.repository.isFirebaseEnabled
                                ? const Color(0x3322C55E)
                                : const Color(0x33F59E0B),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: controller.repository.isFirebaseEnabled
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          child: Text(
                            controller.repository.isFirebaseEnabled ? 'Cloud' : 'Offline',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(18),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      _SearchCard(),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.12,
                        children: const <Widget>[
                          _MetricCard(title: 'Total Orders', value: '0', icon: Icons.receipt_long_rounded),
                          _MetricCard(title: 'Active Orders', value: '0', icon: Icons.pending_actions_rounded),
                          _MetricCard(title: 'Total Clothes', value: '0', icon: Icons.checkroom_rounded),
                          _MetricCard(title: 'Pending Clothes', value: '0', icon: Icons.cut_rounded),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ModuleGrid(role: role),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC13243A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A3D5C)),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search by slip number or mobile number',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC13243A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A3D5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF38BDF8), size: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              Text(title, style: const TextStyle(color: Color(0xFFB9C6D8), fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final modules = <_ModuleInfo>[
      if (role == AppRole.owner || role == AppRole.manager)
        const _ModuleInfo('New Order', Icons.add_shopping_cart_rounded, 'Create order'),
      const _ModuleInfo('Processing', Icons.design_services_rounded, 'Cutting & stitching'),
      const _ModuleInfo('Delivery', Icons.local_shipping_rounded, 'Partial delivery'),
      if (role == AppRole.owner)
        const _ModuleInfo('Staff Ledger', Icons.groups_rounded, 'Daily work payment'),
      if (role == AppRole.owner || role == AppRole.manager)
        const _ModuleInfo('Analytics', Icons.analytics_rounded, 'Reports'),
      if (role == AppRole.owner)
        const _ModuleInfo('Settings', Icons.settings_rounded, 'Shop setup'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Modules', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...modules.map(
          (module) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xCC13243A),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF2A3D5C)),
            ),
            child: ListTile(
              minVerticalPadding: 14,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x2238BDF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(module.icon, color: const Color(0xFF38BDF8)),
              ),
              title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(module.subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${module.title} will be activated in the next phase.')),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleInfo {
  const _ModuleInfo(this.title, this.icon, this.subtitle);

  final String title;
  final IconData icon;
  final String subtitle;
}
