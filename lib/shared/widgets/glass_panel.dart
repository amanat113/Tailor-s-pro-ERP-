import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xCC13243A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF2A3D5C)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 22)),
        ],
      ),
      child: child,
    );
  }
}
