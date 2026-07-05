import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const Color ink = Color(0xFF172033);
  static const Color navy = Color(0xFF1E3557);
  static const Color bronze = Color(0xFFC69A5B);
  static const Color paper = Color(0xFFF7F3EC);
  static const Color card = Color(0xFFFFFCF7);
  static const Color line = Color(0xFFE4DDD2);
  static const Color muted = Color(0xFF697386);
  static const Color green = Color(0xFF267A57);
  static const Color red = Color(0xFFB42318);
  static const Color blue = Color(0xFF2563EB);
}

class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.padding = const EdgeInsets.all(18), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.label, required this.onPressed, this.loading = false, this.icon, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon ?? Icons.check_circle_rounded),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

class MessageBanner extends StatelessWidget {
  const MessageBanner({this.error, this.info, super.key});

  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final text = error ?? info;
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    final isError = error != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE6E3) : const Color(0xFFEAF6EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isError ? const Color(0xFFFFB4AB) : const Color(0xFF99D9AF)),
      ),
      child: Row(
        children: <Widget>[
          Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded, color: isError ? AppColors.red : AppColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: isError ? AppColors.red : AppColors.green, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, required this.message, this.icon = Icons.inbox_rounded, super.key});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 48, color: AppColors.bronze),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
