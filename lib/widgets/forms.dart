import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({required this.controller, required this.label, this.icon, this.keyboardType, this.maxLines = 1, this.onChanged, super.key});

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      ),
    );
  }
}
