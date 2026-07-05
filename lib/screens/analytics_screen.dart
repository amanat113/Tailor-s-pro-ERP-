import 'package:flutter/material.dart';

import '../data/firestore_paths.dart';
import '../models/order_status.dart';
import '../models/tailor_order.dart';
import '../widgets/ui.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _filter = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w900))),
      body: StreamBuilder(
        stream: FirestorePaths.orders().snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final allOrders = docs.map(TailorOrder.fromDoc).toList();
          final orders = allOrders.where(_inFilter).toList();
          final totalClothes = orders.fold<int>(0, (sum, order) => sum + order.clothQty);
          final stitched = orders.fold<int>(0, (sum, order) => sum + order.readyQty + order.deliveredQty);
          final delivered = orders.fold<int>(0, (sum, order) => sum + order.deliveredQty);
          final pendingOrders = orders.where((order) => order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled).length;
          final revenue = orders.fold<num>(0, (sum, order) => sum + order.advancePaid);
          final due = orders.fold<num>(0, (sum, order) => sum + order.dueAmount);
          return ListView(
            padding: const EdgeInsets.all(18),
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _filter,
                decoration: const InputDecoration(labelText: 'Filter', prefixIcon: Icon(Icons.date_range_rounded)),
                items: const <String>['Today', 'This Month', 'This Year', 'All Time'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => _filter = value ?? 'This Month'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _metric('Orders', '${orders.length}', Icons.receipt_long_rounded),
                  _metric('Clothes Received', '$totalClothes', Icons.checkroom_rounded),
                  _metric('Stitched/Ready', '$stitched', Icons.task_alt_rounded),
                  _metric('Delivered', '$delivered', Icons.local_shipping_rounded),
                  _metric('Active Pending', '$pendingOrders', Icons.pending_actions_rounded),
                  _metric('Revenue', '₹$revenue', Icons.payments_rounded),
                  _metric('Due', '₹$due', Icons.warning_rounded),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  bool _inFilter(TailorOrder order) {
    final now = DateTime.now();
    final created = order.createdAt;
    switch (_filter) {
      case 'Today':
        return created.year == now.year && created.month == now.month && created.day == now.day;
      case 'This Month':
        return created.year == now.year && created.month == now.month;
      case 'This Year':
        return created.year == now.year;
      default:
        return true;
    }
  }

  Widget _metric(String label, String value, IconData icon) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 24,
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, color: AppColors.navy),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
