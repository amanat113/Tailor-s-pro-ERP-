import 'package:flutter/material.dart';

import '../core/validators.dart';
import '../data/order_repository.dart';
import '../models/tailor_order.dart';
import '../services/notification_service.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({required this.orderRepository, super.key});

  final OrderRepository orderRepository;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final TextEditingController _slip = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '1');
  final TextEditingController _paid = TextEditingController();
  final NotificationService _notify = const NotificationService();
  TailorOrder? _order;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _slip.dispose();
    _qty.dispose();
    _paid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: <Widget>[
          const Text('Delivery', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Partial delivery with payment ledger', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          MessageBanner(error: _error, info: _info),
          AppCard(
            child: Column(
              children: <Widget>[
                AppTextField(controller: _slip, label: 'Search Slip Number', icon: Icons.search_rounded),
                PrimaryButton(label: 'Search Order', loading: _loading, icon: Icons.manage_search_rounded, onPressed: _search),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (order == null) const EmptyState(title: 'Search delivery order', message: 'Only ready clothes can be delivered.', icon: Icons.local_shipping_rounded),
          if (order != null) _deliveryCard(order),
        ],
      ),
    );
  }

  Widget _deliveryCard(TailorOrder order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(order.slipNo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.navy)),
          Text('${order.customerName} • ${order.mobile}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const Divider(height: 24),
          _row('Total Bill', '₹${order.totalBill}'),
          _row('Advance/Paid', '₹${order.advancePaid}'),
          _row('Remaining Due', '₹${order.dueAmount}'),
          _row('Ready Clothes', '${order.readyQty}'),
          _row('Delivered Clothes', '${order.deliveredQty}/${order.clothQty}'),
          const SizedBox(height: 14),
          AppTextField(controller: _qty, label: 'Deliver Quantity Now', icon: Icons.format_list_numbered_rounded, keyboardType: TextInputType.number),
          AppTextField(controller: _paid, label: 'Payment Received Now', icon: Icons.payments_rounded, keyboardType: TextInputType.number),
          PrimaryButton(label: 'Confirm Delivery', loading: _loading, icon: Icons.verified_rounded, onPressed: _confirm),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
        Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final order = await widget.orderRepository.findBySlip(_slip.text.trim());
      if (order == null) throw StateError('No order found for this slip.');
      setState(() => _order = order);
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final order = _order;
    if (order == null) return;
    final qty = Validators.parseQty(_qty.text);
    final paid = Validators.parseMoney(_paid.text);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery?'),
        content: Text('Deliver $qty clothes for ${order.customerName}?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await widget.orderRepository.deliverReadyItems(order: order, qty: qty, paidNow: paid);
      final fresh = await widget.orderRepository.findBySlip(order.slipNo);
      setState(() {
        _order = fresh;
        _info = 'Delivery saved successfully.';
        _error = null;
      });
      if (fresh != null && fresh.allDelivered) await _notify.openWhatsApp(mobile: fresh.mobile, message: _notify.deliveryConfirmed(fresh));
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      setState(() => _loading = false);
    }
  }
}
