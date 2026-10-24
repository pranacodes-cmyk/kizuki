import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class ProviderIcon extends StatelessWidget {
  final String provider;
  const ProviderIcon(this.provider, {super.key});
  @override
  Widget build(BuildContext context) => provider == 'apple'
      ? const Icon(Icons.apple, size: 24, color: T.foreground)
      : const SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 4;
    for (final part in [(T.googleBlue, -0.05, 0.8), (T.googleGreen, 0.75, 1.6), (T.googleYellow, 2.35, 0.8), (T.googleRed, 3.15, 2.3)]) {
      canvas.drawArc(rect, part.$2, part.$3, false, paint..color = part.$1);
    }
    canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width - 1, size.height / 2), paint..color = T.googleBlue);
    canvas.drawArc(rect, 0, math.pi / 4, false, paint);
  }
  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}