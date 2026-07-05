import 'package:flutter/material.dart';

class MessageBanner extends StatelessWidget {
  const MessageBanner({this.error, this.info, super.key});

  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final message = error ?? info;
    if (message == null || message.trim().isEmpty) return const SizedBox.shrink();
    final isError = error != null;
    final color = isError ? const Color(0xFFB42318) : const Color(0xFF2F7D6D);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F0) : const Color(0xFFEFF8F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        children: <Widget>[
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(fontWeight: FontWeight.w800, color: color))),
        ],
      ),
    );
  }
}
