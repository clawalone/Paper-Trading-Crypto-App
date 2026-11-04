import 'package:flutter/material.dart';
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

    final isApexLegend = lower.contains('apex legend');
    final isWhale = lower.contains('whale');
    final isProAnalyst = lower.contains('pro analyst');
    final isMaestro = lower.contains('market maestro') || lower.contains('maestro');
    final isCaptain = lower.contains('strategy captain') || lower.contains('captain');
    final isMomentum = lower.contains('momentum');
    final isApprentice = lower.contains('apprentice');

    if (isApexLegend) {
      return _buildApexLegendBadge(cleanTitle);
    } else if (isWhale) {
      return _buildWhaleBadge(cleanTitle);
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
