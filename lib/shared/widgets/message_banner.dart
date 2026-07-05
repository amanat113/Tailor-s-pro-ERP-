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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0x33FB7185) : const Color(0x3322C55E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isError ? const Color(0xFFFB7185) : const Color(0xFF22C55E)),
      ),
      child: Row(
        children: <Widget>[
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? const Color(0xFFFB7185) : const Color(0xFF22C55E)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
