import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1E3557), Color(0xFFC69A5B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x332A1B04), blurRadius: 28, offset: Offset(0, 16)),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'TE',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}
