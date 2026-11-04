import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class AnimatedCryptoBackground extends StatefulWidget {
  const AnimatedCryptoBackground({super.key});

  @override
  State<AnimatedCryptoBackground> createState() => _AnimatedCryptoBackgroundState();
}

class _AnimatedCryptoBackgroundState extends State<AnimatedCryptoBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, 
    duration: const Duration(seconds: 40)
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
          painter: _CryptoChartPainter(_controller.value),
        );
      },
    );
  }
}

class _CryptoChartPainter extends CustomPainter {
  final double progress;
  _CryptoChartPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Add an extra blur filter to the canvas for a deep background ambient effect
    final blurPaint = Paint()..imageFilter = ImageFilter.blur(sigmaX: 12, sigmaY: 12);
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), blurPaint);

    final profitPaint = Paint()
      ..color = AppColors.profit.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final lossPaint = Paint()
      ..color = AppColors.loss.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Draw giant blurred candlesticks that slowly drift across the screen
    final double candleWidth = 40.0;
    final double spacing = 30.0;
    final double totalWidth = candleWidth + spacing;
    final int candlesCount = (size.width / totalWidth).ceil() + 6;
    
    // As progress goes from 0 to 1, offset shifts everything by the total width
    final double offset = progress * size.width * 2; 

    for (int i = 0; i < candlesCount; i++) {
      final int index = i - (offset / totalWidth).floor();
      
      // Use index to deterministically generate a pseudo-random candlestick
      final rand1 = (index * 137.0).abs() % 100.0 / 100.0;
      final rand2 = (index * 251.0).abs() % 100.0 / 100.0;
      
      final bool isUp = (index * 97).abs() % 2 == 0;
      
      final double highY = size.height * 0.1 + rand1 * size.height * 0.5;
      final double lowY = highY + 100 + rand2 * 300;
      
      final double openY = isUp ? lowY - 40 - rand1 * 100 : highY + 40 + rand1 * 100;
      final double closeY = isUp ? highY + 40 + rand2 * 100 : lowY - 40 - rand2 * 100;

      final double x = i * totalWidth - (offset % totalWidth);

      final paint = isUp ? profitPaint : lossPaint;

      // Draw Wick
      canvas.drawRect(
        Rect.fromLTRB(x + candleWidth / 2 - 4, highY, x + candleWidth / 2 + 4, lowY), 
        paint
      );
      
      // Draw Body
      canvas.drawRect(
        Rect.fromLTRB(x, min(openY, closeY), x + candleWidth, max(openY, closeY)), 
        paint
      );
    }
    
    // Restore the canvas
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CryptoChartPainter oldDelegate) => oldDelegate.progress != progress;
}
