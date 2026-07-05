import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/domain/app_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order_status.dart';
import '../../orders/domain/tailor_order.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final OrderRepository _orderRepository;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _orderRepository = OrderRepository(firebaseStatus: widget.controller.repository.firebaseStatus);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.state.session;
    final role = session?.role ?? AppRole.select;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        role: role,
        isCloudEnabled: _orderRepository.isCloudEnabled,
        onLogout: widget.controller.logout,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF8F4ED), Color(0xFFF5F8FA), Color(0xFFEFE7DB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<TailorOrder>>(
            stream: _orderRepository.watchOrders(),
            builder: (context, snapshot) {
              final orders = snapshot.data ?? const <TailorOrder>[];
              final stats = _statsFrom(orders);
              final filteredOrders = _filterOrders(orders, _query).take(12).toList();

              return Stack(
                children: <Widget>[
                  RefreshIndicator(
                    color: AppTheme.navy,
                    onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 250)),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _Header(
                                  role: role,
                                  isCloudEnabled: _orderRepository.isCloudEnabled,
                                ),
                                const SizedBox(height: 18),
                                _SearchBox(controller: _searchController),
                                const SizedBox(height: 16),
                                _MetricsGrid(stats: stats),
                                const SizedBox(height: 22),
                                _RecentOrdersHeader(count: filteredOrders.length),
                                const SizedBox(height: 10),
                                if (!_orderRepository.isCloudEnabled)
                                  const _CloudRequiredCard()
                                else if (snapshot.hasError)
                                  _ErrorCard(message: '${snapshot.error}')
                                else if (filteredOrders.isEmpty)
                                  _EmptyOrdersCard(onCreate: _openCreateOrderSheet)
                                else
                                  ...filteredOrders.map(
                                    (order) => _RecentOrderCard(
                                      order: order,
                                      onCall: () => _confirmCall(order),
                                      onEdit: () => _openEditOrderSheet(order),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _FloatingIslandNav(
                      onHome: () {},
                      onProgress: () => _showNotInstalled('Progress'),
                      onCreate: _openCreateOrderSheet,
                      onDelivery: () => _showNotInstalled('Delivery'),
                      onMore: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<TailorOrder> _filterOrders(List<TailorOrder> orders, String query) {
    if (query.isEmpty) return orders;
    return orders.where((order) {
      return order.slipNumber.toLowerCase().contains(query) ||
          order.mobile.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query);
    }).toList();
  }

  OrderDashboardStats _statsFrom(List<TailorOrder> orders) {
    final active = orders.where((order) => order.status.isActive).toList();
    return OrderDashboardStats(
      totalOrders: orders.length,
      activeOrders: active.length,
      totalActiveClothes: active.fold<int>(0, (sum, order) => sum + order.activeClothes),
      pendingClothes: active.fold<int>(0, (sum, order) => sum + order.pendingQty),
      totalDue: orders.fold<double>(0, (sum, order) => sum + order.dueAmount),
      totalRevenue: orders.fold<double>(0, (sum, order) => sum + (order.totalBill - order.dueAmount)),
    );
  }

  Future<void> _confirmCall(TailorOrder order) async {
    final shouldCall = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Customer?'),
        content: Text('Call ${order.customerName} at ${order.mobile}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Call')),
        ],
      ),
    );
    if (shouldCall != true) return;
    final uri = Uri(scheme: 'tel', path: order.mobile);
    if (!await launchUrl(uri)) {
      _showError('Phone dialer could not be opened.');
    }
  }

  Future<void> _openCreateOrderSheet() async {
    if (!_orderRepository.isCloudEnabled) {
      _showError('Firebase is not configured. Real orders need Cloud Firestore.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateOrderSheet(repository: _orderRepository),
    );
  }

  Future<void> _openEditOrderSheet(TailorOrder order) async {
    if (!_orderRepository.isCloudEnabled) {
      _showError('Firebase is not configured.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditOrderSheet(order: order, repository: _orderRepository),
    );
  }

  void _showNotInstalled(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$moduleName real workflow will be added in the next build phase.')),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.role, required this.isCloudEnabled});

  final AppRole role;
  final bool isCloudEnabled;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Builder(
          builder: (context) => _RoundIconButton(
            icon: Icons.menu_rounded,
            onTap: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                "Tailor's ERP",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink),
              ),
              const SizedBox(height: 4),
              Text(
                '${role.label} • $date',
                style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        _CloudBadge(isCloudEnabled: isCloudEnabled),
      ],
    );
  }
}

class _CloudBadge extends StatelessWidget {
  const _CloudBadge({required this.isCloudEnabled});

  final bool isCloudEnabled;

  @override
  Widget build(BuildContext context) {
    final color = isCloudEnabled ? const Color(0xFF2F7D6D) : const Color(0xFFB42318);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(isCloudEnabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            isCloudEnabled ? 'Cloud' : 'Setup',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Search slip, customer, or mobile',
          prefixIcon: Icon(Icons.search_rounded),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.stats});

  final OrderDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.85,
      children: <Widget>[
        _MetricCard(title: 'Total Orders', value: '${stats.totalOrders}', icon: Icons.receipt_long_rounded),
        _MetricCard(title: 'Active Orders', value: '${stats.activeOrders}', icon: Icons.pending_actions_rounded),
        _MetricCard(title: 'Total Clothes', value: '${stats.totalActiveClothes}', icon: Icons.checkroom_rounded),
        _MetricCard(title: 'Pending Clothes', value: '${stats.pendingClothes}', icon: Icons.cut_rounded),
      ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E5D2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.bronze, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersHeader extends StatelessWidget {
  const _RecentOrdersHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text('Recent Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink)),
        ),
        Text('$count shown', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.onCall, required this.onEdit});

  final TailorOrder order;
  final VoidCallback onCall;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 9)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E5D2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.description_rounded, color: AppTheme.bronze),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.slipNumber.isEmpty ? 'No Slip' : order.slipNumber,
                  style: const TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  order.customerName.isEmpty ? 'Unnamed Customer' : order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.ink),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Icon(Icons.phone_rounded, size: 15, color: AppTheme.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.mobile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _StatusBadge(status: order.status),
              const SizedBox(height: 8),
              Text('${order.activeClothes} item${order.activeClothes == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                order.dueAmount <= 0 ? 'Paid' : '₹${order.dueAmount.toStringAsFixed(0)} due',
                style: TextStyle(
                  color: order.dueAmount <= 0 ? const Color(0xFF2F7D6D) : const Color(0xFFB42318),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _MiniAction(icon: Icons.phone_rounded, onTap: onCall),
                  const SizedBox(width: 8),
                  _MiniAction(icon: Icons.edit_rounded, onTap: onEdit),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => const Color(0xFFC69A5B),
      OrderStatus.cutting => const Color(0xFF2563EB),
      OrderStatus.stitching => const Color(0xFF7C3AED),
      OrderStatus.ready => const Color(0xFF2F7D6D),
      OrderStatus.delivered => const Color(0xFF475467),
      OrderStatus.cancelled => const Color(0xFFB42318),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3EC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Icon(icon, size: 20, color: AppTheme.navy),
      ),
    );
  }
}

class _FloatingIslandNav extends StatelessWidget {
  const _FloatingIslandNav({
    required this.onHome,
    required this.onProgress,
    required this.onCreate,
    required this.onDelivery,
    required this.onMore,
  });

  final VoidCallback onHome;
  final VoidCallback onProgress;
  final VoidCallback onCreate;
  final VoidCallback onDelivery;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x24000000), blurRadius: 30, offset: Offset(0, 16)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _NavItem(icon: Icons.home_rounded, label: 'Home', selected: true, onTap: onHome),
          _NavItem(icon: Icons.bar_chart_rounded, label: 'Progress', selected: false, onTap: onProgress),
          Transform.translate(
            offset: const Offset(0, -16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkWell(
                  onTap: onCreate,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: <Color>[AppTheme.navy, AppTheme.bronze]),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Color(0x332A1B04), blurRadius: 20, offset: Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 2),
                const Text('New', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          _NavItem(icon: Icons.local_shipping_rounded, label: 'Delivery', selected: false, onTap: onDelivery),
          _NavItem(icon: Icons.grid_view_rounded, label: 'More', selected: false, onTap: onMore),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.bronze : AppTheme.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 62,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Icon(icon, color: AppTheme.ink),
      ),
    );
  }
}

class _CloudRequiredCard extends StatelessWidget {
  const _CloudRequiredCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.cloud_off_rounded,
      title: 'Firebase setup required',
      message: 'Real OTP, real orders, and cloud sync need Firebase configuration. Demo data is disabled.',
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  const _EmptyOrdersCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.receipt_long_rounded, size: 42, color: AppTheme.bronze),
          const SizedBox(height: 12),
          const Text('No real orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Create your first order. It will save to Cloud Firestore and appear here instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Order'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(icon: Icons.error_outline_rounded, title: 'Unable to load orders', message: message);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppTheme.bronze),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 5),
                Text(message, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.role, required this.isCloudEnabled, required this.onLogout});

  final AppRole role;
  final bool isCloudEnabled;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text("Tailor's ERP", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${role.label} • ${isCloudEnabled ? 'Cloud connected' : 'Firebase setup required'}',
                      style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerTile(icon: Icons.dashboard_rounded, title: 'Dashboard', onTap: () => Navigator.pop(context)),
            _DrawerTile(icon: Icons.add_business_rounded, title: 'New Order', onTap: () => Navigator.pop(context)),
            _DrawerTile(icon: Icons.cut_rounded, title: 'Progress', onTap: () => Navigator.pop(context)),
            _DrawerTile(icon: Icons.local_shipping_rounded, title: 'Delivery', onTap: () => Navigator.pop(context)),
            _DrawerTile(icon: Icons.groups_rounded, title: 'Staff Ledger', onTap: () => Navigator.pop(context)),
            _DrawerTile(icon: Icons.settings_rounded, title: 'Settings', onTap: () => Navigator.pop(context)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 14,
      leading: Icon(icon, color: AppTheme.bronze),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      onTap: onTap,
    );
  }
}

class _CreateOrderSheet extends StatefulWidget {
  const _CreateOrderSheet({required this.repository});

  final OrderRepository repository;

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _slip = TextEditingController();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _bill = TextEditingController(text: '0');
  final _advance = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _slip.dispose();
    _name.dispose();
    _mobile.dispose();
    _qty.dispose();
    _bill.dispose();
    _advance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OrderSheetFrame(
      title: 'New Order',
      saving: _saving,
      submitLabel: 'Save Real Order',
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            _Input(controller: _slip, label: 'Slip Number', icon: Icons.confirmation_number_rounded),
            _Input(controller: _name, label: 'Customer Name', icon: Icons.person_rounded),
            _Input(controller: _mobile, label: 'Mobile Number', icon: Icons.phone_android_rounded, keyboard: TextInputType.phone),
            _Input(controller: _qty, label: 'Cloth Quantity', icon: Icons.checkroom_rounded, keyboard: TextInputType.number),
            _Input(controller: _bill, label: 'Total Bill', icon: Icons.currency_rupee_rounded, keyboard: TextInputType.number),
            _Input(controller: _advance, label: 'Advance Paid', icon: Icons.payments_rounded, keyboard: TextInputType.number),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createOrder(
        CreateOrderInput(
          slipNumber: _slip.text,
          customerName: _name.text,
          mobile: _mobile.text,
          clothQty: int.tryParse(_qty.text.trim()) ?? 0,
          totalBill: double.tryParse(_bill.text.trim()) ?? 0,
          advancePaid: double.tryParse(_advance.text.trim()) ?? 0,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EditOrderSheet extends StatefulWidget {
  const _EditOrderSheet({required this.order, required this.repository});

  final TailorOrder order;
  final OrderRepository repository;

  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _qty;
  late final TextEditingController _bill;
  late final TextEditingController _advance;
  late OrderStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.order.customerName);
    _mobile = TextEditingController(text: widget.order.mobile);
    _qty = TextEditingController(text: '${widget.order.clothQty}');
    _bill = TextEditingController(text: widget.order.totalBill.toStringAsFixed(0));
    _advance = TextEditingController(text: widget.order.advancePaid.toStringAsFixed(0));
    _status = widget.order.status;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _qty.dispose();
    _bill.dispose();
    _advance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OrderSheetFrame(
      title: 'Edit ${widget.order.slipNumber}',
      saving: _saving,
      submitLabel: 'Update Order',
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            _Input(controller: _name, label: 'Customer Name', icon: Icons.person_rounded),
            _Input(controller: _mobile, label: 'Mobile Number', icon: Icons.phone_android_rounded, keyboard: TextInputType.phone),
            _Input(controller: _qty, label: 'Cloth Quantity', icon: Icons.checkroom_rounded, keyboard: TextInputType.number),
            _Input(controller: _bill, label: 'Total Bill', icon: Icons.currency_rupee_rounded, keyboard: TextInputType.number),
            _Input(controller: _advance, label: 'Advance Paid', icon: Icons.payments_rounded, keyboard: TextInputType.number),
            const SizedBox(height: 8),
            DropdownButtonFormField<OrderStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag_rounded)),
              items: OrderStatus.values
                  .map((status) => DropdownMenuItem<OrderStatus>(value: status, child: Text(status.label)))
                  .toList(),
              onChanged: (status) => setState(() => _status = status ?? _status),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateOrder(
        UpdateOrderInput(
          id: widget.order.id,
          customerName: _name.text,
          mobile: _mobile.text,
          clothQty: int.tryParse(_qty.text.trim()) ?? 0,
          totalBill: double.tryParse(_bill.text.trim()) ?? 0,
          advancePaid: double.tryParse(_advance.text.trim()) ?? 0,
          status: _status,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OrderSheetFrame extends StatelessWidget {
  const _OrderSheetFrame({
    required this.title,
    required this.child,
    required this.saving,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final Widget child;
  final bool saving;
  final String submitLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F4ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Container(
                width: 54,
                height: 5,
                decoration: BoxDecoration(color: const Color(0xFFD0C7B9), borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: saving ? null : onSubmit,
                icon: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label, required this.icon, this.keyboard});

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}
