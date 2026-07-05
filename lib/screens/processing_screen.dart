import 'package:flutter/material.dart';

import '../data/order_repository.dart';
import '../models/order_status.dart';
import '../models/tailor_order.dart';
import '../services/notification_service.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({required this.orderRepository, super.key});

  final OrderRepository orderRepository;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final TextEditingController _slip = TextEditingController();
  final NotificationService _notify = const NotificationService();
  TailorOrder? _order;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _slip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: <Widget>[
          const Text('Processing', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Cutting and stitching item tracking', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
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
          if (_order == null) const EmptyState(title: 'Search an order', message: 'Enter slip number to update cutting and ready status.', icon: Icons.content_cut_rounded),
          if (_order != null) _orderDetails(_order!),
        ],
      ),
    );
  }

  Widget _orderDetails(TailorOrder order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(order.slipNo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.navy)),
          Text('${order.customerName} • ${order.mobile}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Status: ${order.status.label}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const Divider(height: 24),
          for (var i = 0; i < order.itemStatuses.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  CircleAvatar(radius: 16, backgroundColor: AppColors.paper, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900))),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Cloth ${i + 1}: ${order.itemStatuses[i].label}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  PopupMenuButton<ClothStatus>(
                    onSelected: (status) => _update(i, status),
                    itemBuilder: (_) => <PopupMenuEntry<ClothStatus>>[
                      const PopupMenuItem(value: ClothStatus.pending, child: Text('Pending')),
                      const PopupMenuItem(value: ClothStatus.cutting, child: Text('Cutting Complete')),
                      const PopupMenuItem(value: ClothStatus.ready, child: Text('Ready')),
                    ],
                    child: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
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

  Future<void> _update(int index, ClothStatus status) async {
    final current = _order;
    if (current == null || current.status == OrderStatus.delivered) return;
    try {
      final trigger = await widget.orderRepository.updateClothStatus(order: current, index: index, status: status);
      final fresh = await widget.orderRepository.findBySlip(current.slipNo);
      setState(() {
        _order = fresh;
        _info = 'Item updated.';
        _error = null;
      });
      if (fresh != null && trigger == 'cutting') {
        await _notify.openWhatsApp(mobile: fresh.mobile, message: _notify.cuttingComplete(fresh));
      }
      if (fresh != null && trigger == 'ready') {
        await _notify.openWhatsApp(mobile: fresh.mobile, message: _notify.orderReady(fresh));
      }
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }
}
