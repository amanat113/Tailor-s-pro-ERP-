import 'package:flutter/material.dart';

import '../core/validators.dart';
import '../data/order_repository.dart';
import '../data/settings_repository.dart';
import '../models/order_status.dart';
import '../models/shop_settings.dart';
import '../models/tailor_order.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({required this.orderRepository, required this.settingsRepository, super.key});

  final OrderRepository orderRepository;
  final SettingsRepository settingsRepository;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _slip = TextEditingController();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _bill = TextEditingController();
  final _advance = TextEditingController();
  final _design = TextEditingController();
  final Map<String, TextEditingController> _measurements = <String, TextEditingController>{};
  final NotificationService _notify = const NotificationService();
  final PdfService _pdf = const PdfService();
  bool _saving = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[_slip, _name, _mobile, _qty, _bill, _advance, _design, ..._measurements.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  num get _due => (Validators.parseMoney(_bill.text) - Validators.parseMoney(_advance.text)).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopSettings>(
      stream: widget.settingsRepository.watchSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data ?? ShopSettings.defaults();
        for (final label in settings.measurements) {
          _measurements.putIfAbsent(label, () => TextEditingController());
        }
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
            children: <Widget>[
              const Text('New Order', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Create customer order and digital slip', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              MessageBanner(error: _error, info: _info),
              AppCard(
                child: Column(
                  children: <Widget>[
                    AppTextField(controller: _slip, label: 'Manual Slip Number', icon: Icons.numbers_rounded),
                    AppTextField(controller: _name, label: 'Customer Name', icon: Icons.person_rounded),
                    AppTextField(controller: _mobile, label: 'Mobile Number', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                    AppTextField(controller: _qty, label: 'Cloth Quantity', icon: Icons.checkroom_rounded, keyboardType: TextInputType.number),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerLeft, child: Text('Measurements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    const SizedBox(height: 8),
                    for (final label in settings.measurements) AppTextField(controller: _measurements[label]!, label: label, icon: Icons.straighten_rounded),
                    AppTextField(controller: _bill, label: 'Total Bill', icon: Icons.payments_rounded, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                    AppTextField(controller: _advance, label: 'Advance Payment', icon: Icons.price_check_rounded, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                    AppTextField(controller: _design, label: 'Design Reference URL', icon: Icons.link_rounded),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(18)),
                      child: Text('Due Amount: ₹$_due', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.red)),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(label: 'Save Order', loading: _saving, icon: Icons.save_rounded, onPressed: () => _save(settings)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(ShopSettings settings) async {
    setState(() {
      _saving = true;
      _error = null;
      _info = null;
    });
    try {
      if (_slip.text.trim().isEmpty) throw StateError('Slip number is required.');
      if (_name.text.trim().isEmpty) throw StateError('Customer name is required.');
      if (!Validators.isValidIndianMobile(_mobile.text)) throw StateError('Enter a valid mobile number.');
      final qty = Validators.parseQty(_qty.text);
      if (qty <= 0) throw StateError('Cloth quantity must be greater than zero.');
      final total = Validators.parseMoney(_bill.text);
      final advance = Validators.parseMoney(_advance.text);
      if (total < advance) throw StateError('Advance cannot be greater than total bill.');
      final now = DateTime.now();
      final order = TailorOrder(
        id: '',
        slipNo: _slip.text.trim(),
        customerName: _name.text.trim(),
        mobile: Validators.normalizeIndianMobile(_mobile.text),
        clothQty: qty,
        measurements: _measurements.map((key, value) => MapEntry(key, value.text.trim())),
        totalBill: total,
        advancePaid: advance,
        dueAmount: total - advance,
        designUrl: _design.text.trim(),
        itemStatuses: List<ClothStatus>.filled(qty, ClothStatus.pending),
        status: OrderStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      await widget.orderRepository.createOrder(order);
      await _notify.openWhatsApp(mobile: order.mobile, message: _notify.orderSaved(order));
      await _pdf.shareSlip(order: order, settings: settings);
      setState(() => _info = 'Order saved successfully.');
      _clear();
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clear() {
    for (final controller in <TextEditingController>[_slip, _name, _mobile, _qty, _bill, _advance, _design, ..._measurements.values]) {
      controller.clear();
    }
    _qty.text = '1';
  }
}
