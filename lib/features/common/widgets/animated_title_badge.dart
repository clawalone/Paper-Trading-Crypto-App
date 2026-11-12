import 'package:stock_arena/core/app_material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean, high-contrast trader title badges.
/// 100% solid vector rendering with zero shadows or blur filters
/// to completely eliminate GPU black-box artifacts, flickering, or layout shifts.
class AnimatedTitleBadge extends StatelessWidget {
  final String title;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final bool showIcon;

  const AnimatedTitleBadge({
    super.key,
    required this.title,
    this.fontSize = 10.5,
    this.padding,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.trim();
    final lower = cleanTitle.toLowerCase();

    final isParagon = lower.contains('paragon') || lower.contains('immortal');
    final isArchon = lower.contains('archon') || lower.contains('infinity');
    final isOverlord = lower.contains('overlord') || lower.contains('sovereign overlord');
    final isTitan = lower.contains('celestial titan') || lower.contains('titan');
    final isMythicCenturion = lower.contains('centurion') || lower.contains('mythic');
    final isApexLegend = lower.contains('apex legend');
    final isSovereign = lower.contains('liquidity sovereign');
    final isGrandmaster = lower.contains('grandmaster');
    final isWhale = lower.contains('whale');
    final isVanguard = lower.contains('vanguard');
    final isProAnalyst = lower.contains('pro analyst');
    final isMaestro = lower.contains('market maestro') || lower.contains('maestro');
    final isCaptain = lower.contains('strategy captain') || lower.contains('captain');
    final isMomentum = lower.contains('momentum');
    final isApprentice = lower.contains('apprentice');

    if (isParagon) {
      return _buildParagonBadge(cleanTitle);
    } else if (isArchon) {
      return _buildArchonBadge(cleanTitle);
    } else if (isOverlord) {
      return _buildOverlordBadge(cleanTitle);
    } else if (isTitan) {
      return _buildTitanBadge(cleanTitle);
    } else if (isMythicCenturion) {
      return _buildMythicCenturionBadge(cleanTitle);
    } else if (isApexLegend) {
      return _buildApexLegendBadge(cleanTitle);
    } else if (isSovereign) {
      return _buildSovereignBadge(cleanTitle);
    } else if (isGrandmaster) {
      return _buildGrandmasterBadge(cleanTitle);
    } else if (isWhale) {
      return _buildWhaleBadge(cleanTitle);
    } else if (isVanguard) {
      return _buildVanguardBadge(cleanTitle);
    } else if (isProAnalyst) {
      return _buildProAnalystBadge(cleanTitle);
    } else if (isMaestro) {
      return _buildMaestroBadge(cleanTitle);
    } else if (isCaptain) {
      return _buildCaptainBadge(cleanTitle);
    } else if (isMomentum) {
      return _buildMomentumBadge(cleanTitle);
    } else if (isApprentice) {
      return _buildApprenticeBadge(cleanTitle);
    } else {
      return _buildRookieBadge(cleanTitle);
    }
  }

  // ─── 00. IMMORTAL PARAGON (LVL 250 - DIAMOND CYAN 💎) ────────────────────
  Widget _buildParagonBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07272E),
            Color(0xFF041217),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.2,
          color: const Color(0xFF22D3EE),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('💎', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFE0F7FA),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 01. INFINITY ARCHON (LVL 200 - COSMIC VIOLET 🌌) ───────────────────────
  Widget _buildArchonBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E0E38),
            Color(0xFF0E061C),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.2,
          color: const Color(0xFFA855F7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🌌', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFF3E8FF),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 02. SOVEREIGN OVERLORD (LVL 150 - WARLORD CRIMSON ⚔️) ─────────────────
  Widget _buildOverlordBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B0B13),
            Color(0xFF1A0307),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.2,
          color: const Color(0xFFF43F5E),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('⚔️', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFE4E6),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 03. CELESTIAL TITAN (LVL 125 - STELLAR INDIGO 🪐) ────────────────────
  Widget _buildTitanBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141933),
            Color(0xFF0A0D1C),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.1,
          color: const Color(0xFF818CF8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🪐', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFE0E7FF),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 0. MYTHIC CENTURION (SUPREME TIER - 24K GOLD & OBSIDIAN 👑) ───────────
  Widget _buildMythicCenturionBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B2703),
            Color(0xFF140D01),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.2,
          color: const Color(0xFFFFD700),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('👑', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFE082),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 0.5. GRANDMASTER 50 (ELITE DIAMOND CYAN & INDIGO 🔱) ─────────────────
  Widget _buildGrandmasterBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0C2F47),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.1,
          color: const Color(0xFF38BDF8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🔱', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFBAE6FD),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. APEX LEGEND (HIGHEST TIER - FIRE FLAME BADGE 🔥) ────────────────────
  Widget _buildApexLegendBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A1005),
            Color(0xFF260803),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFFFF6D00),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🔥', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFD54F), // Luminous, high-contrast golden flame
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1.5. LIQUIDITY SOVEREIGN (LVL 65 - DEEP OCEAN CYAN 🌊) ────────────────
  Widget _buildSovereignBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03262C),
            Color(0xFF011417),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.1,
          color: const Color(0xFF06B6D4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🌊', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFCFFAFE),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2.5. ALPHA VANGUARD (LVL 31 - IRON BRONZE VANGUARD 🛡️) ─────────────────
  Widget _buildVanguardBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E1905),
            Color(0xFF170C02),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFFF97316),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🛡️', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFEDD5),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. CRYPTO WHALE (DEEP OCEAN NEON CYAN 🐋) ──────────────────────────────
  Widget _buildWhaleBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF042442),
            Color(0xFF02162B),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFF00B0FF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🐋', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFF80D8FF),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. PRO ANALYST (RADIANT GOLD METALLIC 📊) ──────────────────────────────
  Widget _buildProAnalystBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF332608),
            Color(0xFF1E1705),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFFF3BA2F),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('📊', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFF3BA2F),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. MARKET MAESTRO (ROYAL VIOLET / AMETHYST 🎯) ────────────────────────
  Widget _buildMaestroBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E0F40),
            Color(0xFF1A0824),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFFBA68C8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🎯', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFE1BEE7),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. STRATEGY CAPTAIN (TACTICAL EMERALD 🧭) ─────────────────────────────
  Widget _buildCaptainBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B3322),
            Color(0xFF051D13),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFF00E676),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🧭', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFF69F0AE),
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 6. MOMENTUM TRADER (ELECTRIC CYAN ⚡) ──────────────────────────────────
  Widget _buildMomentumBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A263B),
            Color(0xFF051624),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFF00E5FF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('⚡', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFF18FFFF),
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7. APPRENTICE TRADER (BRONZE METALLIC 🎖️) ─────────────────────────────
  Widget _buildApprenticeBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF332013),
            Color(0xFF1E130B),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 1.0,
          color: const Color(0xFFD48B47),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: Text('🎖️', style: TextStyle(fontSize: 10.5, height: 1.0)),
              ),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFE5A65D),
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 8. ROOKIE TRADER / BEGINNER (CLEAN SLATE PILL) ─────────────────────────
  Widget _buildRookieBadge(String text) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF384250), width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF9CA3AF),
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
