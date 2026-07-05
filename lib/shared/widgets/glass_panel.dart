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
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE4DDD2)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x18000000), blurRadius: 32, offset: Offset(0, 18)),
        ],
      ),
      child: child,
    );
  }
}
