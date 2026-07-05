import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/firestore_paths.dart';
import '../data/settings_repository.dart';
import '../models/shop_settings.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.settingsRepository, super.key});

  final SettingsRepository settingsRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _shopName = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _measurement = TextEditingController();
  final TextEditingController _stitch = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  List<String> _measurements = <String>[];
  List<String> _stitchTypes = <String>[];
  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[_shopName, _address, _phone, _note, _measurement, _stitch, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))),
      body: StreamBuilder<ShopSettings>(
        stream: widget.settingsRepository.watchSettings(),
        builder: (context, snapshot) {
          final settings = snapshot.data ?? ShopSettings.defaults();
          if (!_loaded) {
            _loaded = true;
            _shopName.text = settings.shopName;
            _address.text = settings.address;
            _phone.text = settings.phone;
            _note.text = settings.slipNote;
            _measurements = List<String>.from(settings.measurements);
            _stitchTypes = List<String>.from(settings.stitchTypes);
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: <Widget>[
              MessageBanner(error: _error, info: _info),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const Text('Shop Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  AppTextField(controller: _shopName, label: 'Shop Name', icon: Icons.store_rounded),
                  AppTextField(controller: _address, label: 'Address', icon: Icons.location_on_rounded, maxLines: 2),
                  AppTextField(controller: _phone, label: 'Shop Phone', icon: Icons.phone_rounded),
                  AppTextField(controller: _note, label: 'Slip Note', icon: Icons.note_rounded),
                ]),
              ),
              const SizedBox(height: 14),
              _listEditor('Measurement Labels', _measurements, _measurement),
              const SizedBox(height: 14),
              _listEditor('Stitch Types', _stitchTypes, _stitch),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Save Settings', loading: _saving, icon: Icons.save_rounded, onPressed: _save),
              const SizedBox(height: 18),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const Text('Backup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _exportJson, icon: const Icon(Icons.download_rounded), label: const Text('Create JSON Backup in Firestore')),
                ]),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const Text('Danger Zone', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.red)),
                  const SizedBox(height: 12),
                  AppTextField(controller: _confirm, label: 'Type CONFIRM to clear data', icon: Icons.warning_rounded),
                  OutlinedButton.icon(onPressed: _resetData, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Clear Orders/Staff/Ledgers')),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _listEditor(String title, List<String> values, TextEditingController controller) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: <Widget>[
          Expanded(child: AppTextField(controller: controller, label: 'Add item', icon: Icons.add_rounded)),
          const SizedBox(width: 10),
          FilledButton(onPressed: () => _addToList(values, controller), child: const Text('Add')),
        ]),
        Wrap(spacing: 8, runSpacing: 4, children: values.map((item) => Chip(label: Text(item), onDeleted: () => setState(() => values.remove(item)))).toList()),
      ]),
    );
  }

  void _addToList(List<String> values, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty || values.contains(text)) return;
    setState(() {
      values.add(text);
      controller.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.settingsRepository.saveSettings(ShopSettings(
        shopName: _shopName.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        slipNote: _note.text.trim(),
        measurements: _measurements,
        stitchTypes: _stitchTypes,
      ));
      setState(() {
        _info = 'Settings saved.';
        _error = null;
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _exportJson() async {
    try {
      final Map<String, dynamic> backup = <String, dynamic>{};
      for (final entry in <String, CollectionReference<Map<String, dynamic>>>{
        'orders': FirestorePaths.orders(),
        'staff': FirestorePaths.staff(),
        'staffLedger': FirestorePaths.staffLedger(),
        'deliveryLedger': FirestorePaths.deliveryLedger(),
      }.entries) {
        final docs = await entry.value.get();
        backup[entry.key] = docs.docs.map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()}).toList();
      }
      await FirestorePaths.shop().collection('backups').add(<String, dynamic>{
        'json': jsonEncode(backup, toEncodable: (object) => '$object'),
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _info = 'Backup saved in Firestore backups collection.');
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _resetData() async {
    if (_confirm.text.trim() != 'CONFIRM') {
      setState(() => _error = 'Type CONFIRM first.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('This will delete orders, staff, ledgers and logs from this shop.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.settingsRepository.resetAllData();
    setState(() => _info = 'Data cleared.');
  }
}
