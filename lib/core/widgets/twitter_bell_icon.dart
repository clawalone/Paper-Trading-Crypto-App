import 'package:flutter/material.dart';

class TwitterBellIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isFilled;

  const TwitterBellIcon({
    super.key,
    this.size = 18,
    required this.color,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TwitterBellPainter(color: color, isFilled: isFilled),
      ),
    );
  }
}

class _TwitterBellPainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  const _TwitterBellPainter({required this.color, this.isFilled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Dome and flared body of Twitter bell
    final bellPath = Path();
    bellPath.moveTo(6.0, 9.0);
    // Smooth dome top
    bellPath.cubicTo(6.0, 5.2, 8.8, 2.5, 12.0, 2.5);
    bellPath.cubicTo(15.2, 2.5, 18.0, 5.2, 18.0, 9.0);
    // Flared bottom rim
    bellPath.cubicTo(18.0, 13.5, 19.5, 15.5, 20.5, 16.8);
    bellPath.lineTo(3.5, 16.8);
    bellPath.cubicTo(4.5, 15.5, 6.0, 13.5, 6.0, 9.0);
    bellPath.close();

    canvas.drawPath(bellPath, strokePaint);

    // Clapper at bottom
    final clapperPaint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final clapperPath = Path();
    clapperPath.moveTo(10.0, 18.2);
    clapperPath.arcToPoint(
      const Offset(14.0, 18.2),
      radius: const Radius.circular(2.4),
      clockwise: false,
    );
    if (isFilled) {
      clapperPath.close();
    }
    canvas.drawPath(clapperPath, clapperPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TwitterBellPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isFilled != isFilled;
}
