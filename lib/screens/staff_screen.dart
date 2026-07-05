import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/validators.dart';
import '../data/staff_repository.dart';
import '../models/staff_ledger_entry.dart';
import '../models/staff_member.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({required this.staffRepository, required this.ownerMode, super.key});

  final StaffRepository staffRepository;
  final bool ownerMode;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  StaffMember? _selected;
  String? _type;
  int _qty = 1;
  final TextEditingController _paid = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _specialization = TextEditingController();
  final TextEditingController _rateType = TextEditingController();
  final TextEditingController _ratePrice = TextEditingController();
  final Map<String, num> _rates = <String, num>{};
  String? _error;
  String? _info;
  bool _loading = false;

  @override
  void dispose() {
    _paid.dispose();
    _name.dispose();
    _specialization.dispose();
    _rateType.dispose();
    _ratePrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Ledger', style: TextStyle(fontWeight: FontWeight.w900))),
      body: StreamBuilder<List<StaffMember>>(
        stream: widget.staffRepository.watchStaff(),
        builder: (context, staffSnapshot) {
          final staff = staffSnapshot.data ?? <StaffMember>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: <Widget>[
              MessageBanner(error: _error, info: _info),
              if (widget.ownerMode) _staffSetupCard(),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Daily Work Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<StaffMember>(
                      value: _selected,
                      decoration: const InputDecoration(labelText: 'Select Staff', prefixIcon: Icon(Icons.person_rounded)),
                      items: staff.map((person) => DropdownMenuItem(value: person, child: Text(person.name))).toList(),
                      onChanged: (person) => setState(() {
                        _selected = person;
                        _type = person?.rates.keys.isNotEmpty == true ? person!.rates.keys.first : null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Stitch Type', prefixIcon: Icon(Icons.checkroom_rounded)),
                      items: (_selected?.rates.keys ?? <String>[]).map((type) => DropdownMenuItem(value: type, child: Text('$type • ₹${_selected!.rates[type]}'))).toList(),
                      onChanged: (type) => setState(() => _type = type),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _qty,
                      decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.format_list_numbered_rounded)),
                      items: List<int>.generate(10, (index) => index + 1).map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(),
                      onChanged: (value) => setState(() => _qty = value ?? 1),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(controller: _paid, label: 'Today Paid Amount', icon: Icons.payments_rounded, keyboardType: TextInputType.number),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(18)),
                      child: Text('Earning: ₹${_earning()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(label: 'Save Staff Work', loading: _loading, icon: Icons.save_rounded, onPressed: _saveWork),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _summaryCard(),
              const SizedBox(height: 14),
              _ledgerList(),
            ],
          );
        },
      ),
    );
  }

  Widget _staffSetupCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Staff Setup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            AppTextField(controller: _name, label: 'Staff Name', icon: Icons.person_add_rounded),
            AppTextField(controller: _specialization, label: 'Specialization', icon: Icons.badge_rounded),
            Row(
              children: <Widget>[
                Expanded(child: AppTextField(controller: _rateType, label: 'Work Type', icon: Icons.category_rounded)),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(controller: _ratePrice, label: 'Rate', icon: Icons.currency_rupee_rounded, keyboardType: TextInputType.number)),
              ],
            ),
            OutlinedButton.icon(onPressed: _addRate, icon: const Icon(Icons.add_rounded), label: const Text('Add Rate')),
            Wrap(spacing: 8, children: _rates.entries.map((entry) => Chip(label: Text('${entry.key}: ₹${entry.value}'), onDeleted: () => setState(() => _rates.remove(entry.key)))).toList()),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Save Staff', loading: _loading, icon: Icons.save_rounded, onPressed: _saveStaff),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final staff = _selected;
    if (staff == null) return const EmptyState(title: 'Select staff', message: 'Choose a staff member to view all-time details.', icon: Icons.groups_rounded);
    return FutureBuilder<StaffSummary>(
      future: widget.staffRepository.summary(staff.id),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const StaffSummary(daysWorked: 0, totalQty: 0, totalEarned: 0, totalPaid: 0);
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('${staff.name} Summary', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _summaryRow('Days Worked', '${summary.daysWorked}'),
            _summaryRow('Total Clothes', '${summary.totalQty}'),
            _summaryRow('Work Value', '₹${summary.totalEarned}'),
            _summaryRow('Payments Received', '₹${summary.totalPaid}'),
            _summaryRow('Balance Due', '₹${summary.balance}'),
          ]),
        );
      },
    );
  }

  Widget _ledgerList() {
    return StreamBuilder<List<StaffLedgerEntry>>(
      stream: widget.staffRepository.watchLedger(staffId: _selected?.id),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? <StaffLedgerEntry>[];
        if (entries.isEmpty) return const EmptyState(title: 'No ledger yet', message: 'Saved daily work will appear here.', icon: Icons.history_rounded);
        return Column(
          children: entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text('${entry.staffName} • ${entry.stitchType}', style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(DateFormat('dd MMM yyyy').format(entry.workDate), style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Text('Qty ${entry.qty} × ₹${entry.rate} = ₹${entry.earning} | Paid ₹${entry.paid}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
        Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ]),
    );
  }

  num _earning() {
    final staff = _selected;
    final type = _type;
    if (staff == null || type == null) return 0;
    return (staff.rates[type] ?? 0) * _qty;
  }

  void _addRate() {
    final type = _rateType.text.trim();
    final price = Validators.parseMoney(_ratePrice.text);
    if (type.isEmpty || price <= 0) return;
    setState(() {
      _rates[type] = price;
      _rateType.clear();
      _ratePrice.clear();
    });
  }

  Future<void> _saveStaff() async {
    setState(() => _loading = true);
    try {
      await widget.staffRepository.saveStaff(name: _name.text, specialization: _specialization.text, rates: _rates);
      setState(() {
        _info = 'Staff saved.';
        _error = null;
        _name.clear();
        _specialization.clear();
        _rates.clear();
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveWork() async {
    final staff = _selected;
    final type = _type;
    if (staff == null || type == null) return;
    setState(() => _loading = true);
    try {
      await widget.staffRepository.addLedger(
        staff: staff,
        stitchType: type,
        rate: staff.rates[type] ?? 0,
        qty: _qty,
        paid: Validators.parseMoney(_paid.text),
        workDate: DateTime.now(),
      );
      setState(() {
        _info = 'Daily work saved.';
        _error = null;
        _paid.clear();
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      setState(() => _loading = false);
    }
  }
}
