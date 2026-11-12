import 'package:stock_arena/core/app_material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';

/// Clean, high-performance matte animated username for the Dashboard header.
/// Strictly zero glow, neon bloom, or shader artifacts.
/// Smoothly fades in on app opening with crisp institutional typography.
class AnimatedUsernameText extends StatefulWidget {
  final String name;
  final int level;
  final double fontSize;
  final FontWeight fontWeight;

  const AnimatedUsernameText({
    super.key,
    required this.name,
    this.level = 1,
    this.fontSize = 14.5,
    this.fontWeight = FontWeight.w700,
  });

  @override
  State<AnimatedUsernameText> createState() => _AnimatedUsernameTextState();
}

class _AnimatedUsernameTextState extends State<AnimatedUsernameText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  bool get isMythic => widget.level >= 100;
  bool get isGrandmaster => widget.level >= 50 && widget.level < 100;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.split(' ').first;

    final String? insignia;
    final Color nameColor;

    if (widget.level >= 250) {
      nameColor = const Color(0xFF22D3EE);
      insignia = '💎';
    } else if (widget.level >= 200) {
      nameColor = const Color(0xFFA855F7);
      insignia = '🌌';
    } else if (widget.level >= 150) {
      nameColor = const Color(0xFFF43F5E);
      insignia = '⚔️';
    } else if (widget.level >= 125) {
      nameColor = const Color(0xFF818CF8);
      insignia = '🪐';
    } else if (widget.level >= 100) {
      nameColor = const Color(0xFFFFD54F);
      insignia = '👑';
    } else if (widget.level >= 81) {
      nameColor = const Color(0xFFF87171);
      insignia = '🔥';
    } else if (widget.level >= 65) {
      nameColor = const Color(0xFF06B6D4);
      insignia = '🌊';
    } else if (widget.level >= 50) {
      nameColor = const Color(0xFF38BDF8);
      insignia = '🔱';
    } else if (widget.level >= 41) {
      nameColor = const Color(0xFF38BDF8);
      insignia = '🐋';
    } else if (widget.level >= 31) {
      nameColor = const Color(0xFFFB923C);
      insignia = '🛡️';
    } else if (widget.level >= 21) {
      nameColor = const Color(0xFF34D399);
      insignia = '📊';
    } else if (widget.level >= 11) {
      nameColor = const Color(0xFFA78BFA);
      insignia = '🎯';
    } else if (widget.level >= 5) {
      nameColor = const Color(0xFF60A5FA);
      insignia = '🧭';
    } else if (widget.level >= 3) {
      nameColor = const Color(0xFFFBBF24);
      insignia = '⚡';
    } else if (widget.level >= 2) {
      nameColor = const Color(0xFF2DD4BF);
      insignia = '🎖️';
    } else {
      nameColor = AppColors.textPrimary;
      insignia = null;
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              displayName,
              style: GoogleFonts.inter(
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                color: nameColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (insignia != null) ...[
            const SizedBox(width: 4),
            Text(
              insignia,
              style: TextStyle(
                fontSize: widget.fontSize * 0.9,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
