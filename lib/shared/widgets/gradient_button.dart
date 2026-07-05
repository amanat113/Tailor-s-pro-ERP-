import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: enabled
              ? const LinearGradient(colors: <Color>[Color(0xFF1E3557), Color(0xFFC69A5B)])
              : const LinearGradient(colors: <Color>[Color(0xFF98A2B3), Color(0xFF667085)]),
          boxShadow: enabled
              ? const <BoxShadow>[
                  BoxShadow(color: Color(0x332A1B04), blurRadius: 18, offset: Offset(0, 10)),
                ]
              : const <BoxShadow>[],
        ),
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon ?? Icons.lock_open_rounded, color: Colors.white),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
  }
}
