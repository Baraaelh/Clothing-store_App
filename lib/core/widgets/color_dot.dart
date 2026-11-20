import 'package:flutter/material.dart';

/// دائرة صغيرة بلون الصنف (من hex السيرفر).
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, this.hex, this.size = 14});

  final String? hex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
    final color = value == null ? Colors.grey.shade300 : Color(0xFF000000 | value);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}
