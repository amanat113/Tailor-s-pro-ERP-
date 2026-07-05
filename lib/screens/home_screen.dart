import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../data/order_repository.dart';
import '../models/order_status.dart';
import '../models/tailor_order.dart';
import '../services/notification_service.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, required this.orderRepository, super.key});

  final AppController controller;
  final OrderRepository orderRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();
  final NotificationService _notification = const NotificationService();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TailorOrder>>(
      stream: widget.orderRepository.watchOrders(limit: 150),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? <TailorOrder>[];
        final query = _search.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? orders.take(8).toList()
            : orders.where((order) => order.slipNo.toLowerCase().contains(query) || order.mobile.contains(query)).toList();
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
              children: <Widget>[
                const Text('Dashboard', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM yyyy, EEEE').format(DateTime.now()), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _MetricsGrid(orders: orders),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Search by Slip No or Mobile', prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('Recent Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    TextButton(onPressed: () {}, child: const Text('Live')),
                  ],
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                if (orders.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                  const EmptyState(title: 'No orders yet', message: 'Tap the + button below to create the first real order.', icon: Icons.receipt_long_rounded),
                for (final order in filtered) _OrderCard(order: order, onCall: () => _confirmCall(order), onEdit: () => widget.controller.changePage(2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCall(TailorOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Customer?'),
        content: Text('${order.customerName}\n${order.mobile}'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Call')),
        ],
      ),
    );
    if (confirm == true) await _notification.callCustomer(order.mobile);
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.orders});

  final List<TailorOrder> orders;

  @override
  Widget build(BuildContext context) {
    final active = orders.where((order) => order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled).toList();
    final totalClothes = active.fold<int>(0, (sum, order) => sum + order.clothQty);
    final pendingClothes = active.fold<int>(0, (sum, order) => sum + order.pendingQty);
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.65,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: <Widget>[
        _MetricCard(icon: Icons.receipt_long_rounded, value: '${orders.length}', label: 'Total Orders'),
        _MetricCard(icon: Icons.pending_actions_rounded, value: '${active.length}', label: 'Active Orders'),
        _MetricCard(icon: Icons.checkroom_rounded, value: '$totalClothes', label: 'Total Clothes'),
        _MetricCard(icon: Icons.content_cut_rounded, value: '$pendingClothes', label: 'Pending Clothes'),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onCall, required this.onEdit});

  final TailorOrder order;
  final VoidCallback onCall;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      OrderStatus.pending => AppColors.bronze,
      OrderStatus.cutting => AppColors.blue,
      OrderStatus.ready => AppColors.green,
      OrderStatus.delivered => AppColors.muted,
      OrderStatus.cancelled => AppColors.red,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.receipt_rounded, color: AppColors.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(order.slipNo, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
                  Text(order.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('${order.mobile} • ${order.activeQty}/${order.clothQty} active', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Due ₹${order.dueAmount}', style: TextStyle(color: order.dueAmount > 0 ? AppColors.red : AppColors.green, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: statusColor)),
                  child: Text(order.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(onPressed: onCall, icon: const Icon(Icons.phone_rounded, color: AppColors.navy)),
                    IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, color: AppColors.bronze)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
