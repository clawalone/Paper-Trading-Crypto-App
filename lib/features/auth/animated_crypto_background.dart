import 'dart:math';
import 'package:stock_arena/core/app_material.dart';

import '../../core/app_theme.dart';

class AnimatedCryptoBackground extends StatefulWidget {
  const AnimatedCryptoBackground({super.key});

  @override
  State<AnimatedCryptoBackground> createState() => _AnimatedCryptoBackgroundState();
}

class _AnimatedCryptoBackgroundState extends State<AnimatedCryptoBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 45),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CryptoAtmospherePainter(_controller.value),
        );
      },
    );
  }
}

class _CryptoAtmospherePainter extends CustomPainter {
  final double progress;
  const _CryptoAtmospherePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle ambient radial glow at top-center and bottom-right
    final topAura = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.75),
        radius: 1.1,
        colors: [
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.primary.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), topAura);

    final bottomAura = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, 0.9),
        radius: 0.9,
        colors: [
          const Color(0xFF1E293B).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bottomAura);

    // 2. Subtle Bloomberg / TradingView financial grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    const double gridSpacingY = 80.0;
    for (double y = gridSpacingY; y < size.height; y += gridSpacingY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Elegant, refined drifting candlesticks with delicate opacity
    final profitPaint = Paint()
      ..color = AppColors.profit.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final lossPaint = Paint()
      ..color = AppColors.loss.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const double candleWidth = 18.0;
    const double spacing = 28.0;
    const double totalWidth = candleWidth + spacing;
    final int candlesCount = (size.width / totalWidth).ceil() + 6;

    final double offset = progress * size.width * 1.5;

    for (int i = 0; i < candlesCount; i++) {
      final int index = i - (offset / totalWidth).floor();

      final rand1 = (index * 137.0).abs() % 100.0 / 100.0;
      final rand2 = (index * 251.0).abs() % 100.0 / 100.0;
      final bool isUp = (index * 97).abs() % 2 == 0;

      final double highY = size.height * 0.15 + rand1 * (size.height * 0.45);
      final double lowY = highY + 80 + rand2 * 180;
      final double openY = isUp ? lowY - 30 - rand1 * 60 : highY + 30 + rand1 * 60;
      final double closeY = isUp ? highY + 30 + rand2 * 60 : lowY - 30 - rand2 * 60;

      final double x = i * totalWidth - (offset % totalWidth);
      final paint = isUp ? profitPaint : lossPaint;

      // Draw Thin Wick (1.5px)
      canvas.drawRect(
        Rect.fromLTRB(x + candleWidth / 2 - 0.75, highY, x + candleWidth / 2 + 0.75, lowY),
        paint,
      );

      // Draw Candlestick Body with subtle rounded corners
      final double top = min(openY, closeY);
      final double bottom = max(openY, closeY);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, top, x + candleWidth, bottom.clamp(top + 4, lowY)),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CryptoAtmospherePainter oldDelegate) => oldDelegate.progress != progress;
}
