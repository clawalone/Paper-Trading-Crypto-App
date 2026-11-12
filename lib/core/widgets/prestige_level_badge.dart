import 'package:stock_arena/core/app_material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/rewards/rewards_screen.dart';

/// Elite level progression badges for all career ranks:
/// - Apprentice (Lv.2) 🎖️
/// - Momentum (Lv.3) ⚡
/// - Strategy Captain (Lv.5) 🧭
/// - Market Maestro (Lv.11) 🎯
/// - Pro Analyst (Lv.21) 📊
/// - Crypto Whale (Lv.41) 🐋
/// - Grandmaster 50 (Lv.50) 🔱
/// - Apex Legend (Lv.81) 🔥
/// - Mythic Centurion (Lv.100) 👑
///
/// Designed with matte institutional high-contrast styling: strictly zero glow,
/// neon bloom, or GPU black-box artifacts.
class PrestigeLevelBadge extends StatefulWidget {
  final int level;
  final bool isCompact;
  final bool animateOnMount;
  final VoidCallback? onTap;

  const PrestigeLevelBadge({
    super.key,
    required this.level,
    this.isCompact = false,
    this.animateOnMount = false,
    this.onTap,
  });

  @override
  State<PrestigeLevelBadge> createState() => _PrestigeLevelBadgeState();
}

class _PrestigeLevelBadgeState extends State<PrestigeLevelBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;
  Animation<double>? _scaleAnim;

  bool get isPrestige => widget.level >= 50;

  @override
  void initState() {
    super.initState();
    if (widget.animateOnMount && isPrestige) {
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );

      _scaleAnim = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.1)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 60,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.1, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 40,
        ),
      ]).animate(_animController!);

      _animController!.forward();
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget badgeWidget;

    if (widget.level >= 250) {
      badgeWidget = _buildBadge(
        icon: '💎',
        label: 'LVL ${widget.level}',
        tag: 'PARAGON',
        bgColors: const [Color(0xFF07272E), Color(0xFF041217)],
        borderColor: const Color(0xFF22D3EE),
        textColor: const Color(0xFFE0F7FA),
        tagColor: const Color(0xFF22D3EE),
      );
    } else if (widget.level >= 200) {
      badgeWidget = _buildBadge(
        icon: '🌌',
        label: 'LVL ${widget.level}',
        tag: 'ARCHON',
        bgColors: const [Color(0xFF1E0E38), Color(0xFF0E061C)],
        borderColor: const Color(0xFFA855F7),
        textColor: const Color(0xFFF3E8FF),
        tagColor: const Color(0xFFA855F7),
      );
    } else if (widget.level >= 150) {
      badgeWidget = _buildBadge(
        icon: '⚔️',
        label: 'LVL ${widget.level}',
        tag: 'OVERLORD',
        bgColors: const [Color(0xFF3B0B13), Color(0xFF1A0307)],
        borderColor: const Color(0xFFF43F5E),
        textColor: const Color(0xFFFFE4E6),
        tagColor: const Color(0xFFF43F5E),
      );
    } else if (widget.level >= 125) {
      badgeWidget = _buildBadge(
        icon: '🪐',
        label: 'LVL ${widget.level}',
        tag: 'TITAN',
        bgColors: const [Color(0xFF141933), Color(0xFF0A0D1C)],
        borderColor: const Color(0xFF818CF8),
        textColor: const Color(0xFFE0E7FF),
        tagColor: const Color(0xFF818CF8),
      );
    } else if (widget.level >= 100) {
      badgeWidget = _buildBadge(
        icon: '👑',
        label: 'LVL ${widget.level}',
        tag: 'MYTHIC',
        bgColors: const [Color(0xFF2C1E03), Color(0xFF140D01)],
        borderColor: const Color(0xFFFFD700),
        textColor: const Color(0xFFFFE082),
        tagColor: const Color(0xFFFFD700),
      );
    } else if (widget.level >= 81) {
      badgeWidget = _buildBadge(
        icon: '🔥',
        label: 'LVL ${widget.level}',
        tag: 'APEX',
        bgColors: const [Color(0xFF330D08), Color(0xFF170503)],
        borderColor: const Color(0xFFEF4444),
        textColor: const Color(0xFFFECACA),
        tagColor: const Color(0xFFEF4444),
      );
    } else if (widget.level >= 65) {
      badgeWidget = _buildBadge(
        icon: '🌊',
        label: 'LVL ${widget.level}',
        tag: 'SOVEREIGN',
        bgColors: const [Color(0xFF03262C), Color(0xFF011417)],
        borderColor: const Color(0xFF06B6D4),
        textColor: const Color(0xFFCFFAFE),
        tagColor: const Color(0xFF06B6D4),
      );
    } else if (widget.level >= 50) {
      badgeWidget = _buildBadge(
        icon: '🔱',
        label: 'LVL ${widget.level}',
        tag: 'GRANDMASTER',
        bgColors: const [Color(0xFF08283C), Color(0xFF0F172A)],
        borderColor: const Color(0xFF38BDF8),
        textColor: const Color(0xFFBAE6FD),
        tagColor: const Color(0xFF38BDF8),
      );
    } else if (widget.level >= 41) {
      badgeWidget = _buildBadge(
        icon: '🐋',
        label: 'LVL ${widget.level}',
        tag: 'WHALE',
        bgColors: const [Color(0xFF0A2239), Color(0xFF0D1B2A)],
        borderColor: const Color(0xFF0EA5E9),
        textColor: const Color(0xFFE0F2FE),
        tagColor: const Color(0xFF0EA5E9),
      );
    } else if (widget.level >= 31) {
      badgeWidget = _buildBadge(
        icon: '🛡️',
        label: 'LVL ${widget.level}',
        tag: 'VANGUARD',
        bgColors: const [Color(0xFF2E1905), Color(0xFF170C02)],
        borderColor: const Color(0xFFF97316),
        textColor: const Color(0xFFFFEDD5),
        tagColor: const Color(0xFFF97316),
      );
    } else if (widget.level >= 21) {
      badgeWidget = _buildBadge(
        icon: '📊',
        label: 'LVL ${widget.level}',
        tag: 'ANALYST',
        bgColors: const [Color(0xFF062A1F), Color(0xFF0A1C16)],
        borderColor: const Color(0xFF10B981),
        textColor: const Color(0xFFA7F3D0),
        tagColor: const Color(0xFF10B981),
      );
    } else if (widget.level >= 11) {
      badgeWidget = _buildBadge(
        icon: '🎯',
        label: 'LVL ${widget.level}',
        tag: 'MAESTRO',
        bgColors: const [Color(0xFF21133B), Color(0xFF110A1F)],
        borderColor: const Color(0xFF8B5CF6),
        textColor: const Color(0xFFDDD6FE),
        tagColor: const Color(0xFF8B5CF6),
      );
    } else if (widget.level >= 5) {
      badgeWidget = _buildBadge(
        icon: '🧭',
        label: 'LVL ${widget.level}',
        tag: 'CAPTAIN',
        bgColors: const [Color(0xFF0C2444), Color(0xFF081424)],
        borderColor: const Color(0xFF3B82F6),
        textColor: const Color(0xFFBFDBFE),
        tagColor: const Color(0xFF3B82F6),
      );
    } else if (widget.level >= 3) {
      badgeWidget = _buildBadge(
        icon: '⚡',
        label: 'LVL ${widget.level}',
        tag: 'MOMENTUM',
        bgColors: const [Color(0xFF2E1C06), Color(0xFF190E02)],
        borderColor: const Color(0xFFF59E0B),
        textColor: const Color(0xFFFDE68A),
        tagColor: const Color(0xFFF59E0B),
      );
    } else if (widget.level >= 2) {
      badgeWidget = _buildBadge(
        icon: '🎖️',
        label: 'LVL ${widget.level}',
        tag: 'APPRENTICE',
        bgColors: const [Color(0xFF082623), Color(0xFF051715)],
        borderColor: const Color(0xFF14B8A6),
        textColor: const Color(0xFFCCFBF1),
        tagColor: const Color(0xFF14B8A6),
      );
    } else {
      badgeWidget = _buildStandardLevelBadge();
    }

    if (_animController != null && _scaleAnim != null) {
      return AnimatedBuilder(
        animation: _animController!,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim!.value,
            child: child,
          );
        },
        child: _wrapTap(badgeWidget),
      );
    }

    return _wrapTap(badgeWidget);
  }

  Widget _wrapTap(Widget child) {
    return GestureDetector(
      onTap: widget.onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RewardsScreen()),
            );
          },
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _buildBadge({
    required String icon,
    required String label,
    required String tag,
    required List<Color> bgColors,
    required Color borderColor,
    required Color textColor,
    required Color tagColor,
  }) {
    final hPad = widget.isCompact ? 5.5 : 8.5;
    final vPad = widget.isCompact ? 2.0 : 3.0;
    final fSize = widget.isCompact ? 9.5 : 11.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: widget.isCompact ? 10.0 : 11.5,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: fSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          if (!widget.isCompact) ...[
            const SizedBox(width: 3.5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tag,
                style: GoogleFonts.inter(
                  color: tagColor,
                  fontSize: 8.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── ROOKIE LEVEL 1 ─────────────────────────────────────────────────────────
  Widget _buildStandardLevelBadge() {
    final hPad = widget.isCompact ? 5.0 : 7.0;
    final vPad = widget.isCompact ? 1.5 : 2.5;
    final fSize = widget.isCompact ? 9.0 : 10.5;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          width: 0.8,
          color: const Color(0xFF334155),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Lv.1',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: fSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
