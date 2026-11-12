import 'package:flutter/services.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Manages the prestigious milestone alert when users unlock Level 50 or Level 100.
/// Matte institutional aesthetic: strictly zero neon glow, particle halos, or radiant pulse.
class PrestigeCelebrationManager {
  static bool _isShowing = false;

  /// Checks on app boot if the user has crossed Level 50 or 100 and hasn't celebrated it yet.
  static Future<void> checkAndShowCelebration(
    BuildContext context,
    UserProfile profile,
    WidgetRef ref,
  ) async {
    if (_isShowing) return;

    final level = profile.level;
    if (level < 50) return;

    final prefs = await SharedPreferences.getInstance();

    if (level >= 250) {
      final shown250 = prefs.getBool('prestige_celebrated_lvl250') ?? false;
      if (!shown250) {
        _isShowing = true;
        await prefs.setBool('prestige_celebrated_lvl250', true);
        if (!context.mounted) return;
        await _showDialog(
          context: context,
          ref: ref,
          level: 250,
          badgeTitle: 'Immortal Paragon',
          badgeIcon: '💎',
          accentColor: const Color(0xFF22D3EE),
        );
        _isShowing = false;
        return;
      }
    }

    if (level >= 200) {
      final shown200 = prefs.getBool('prestige_celebrated_lvl200') ?? false;
      if (!shown200) {
        _isShowing = true;
        await prefs.setBool('prestige_celebrated_lvl200', true);
        if (!context.mounted) return;
        await _showDialog(
          context: context,
          ref: ref,
          level: 200,
          badgeTitle: 'Infinity Archon',
          badgeIcon: '🌌',
          accentColor: const Color(0xFFA855F7),
        );
        _isShowing = false;
        return;
      }
    }

    if (level >= 150) {
      final shown150 = prefs.getBool('prestige_celebrated_lvl150') ?? false;
      if (!shown150) {
        _isShowing = true;
        await prefs.setBool('prestige_celebrated_lvl150', true);
        if (!context.mounted) return;
        await _showDialog(
          context: context,
          ref: ref,
          level: 150,
          badgeTitle: 'Sovereign Overlord',
          badgeIcon: '⚔️',
          accentColor: const Color(0xFFF43F5E),
        );
        _isShowing = false;
        return;
      }
    }

    if (level >= 100) {
      final shown100 = prefs.getBool('prestige_celebrated_lvl100') ?? false;
      if (!shown100) {
        _isShowing = true;
        await prefs.setBool('prestige_celebrated_lvl100', true);
        if (!context.mounted) return;
        await _showDialog(
          context: context,
          ref: ref,
          level: 100,
          badgeTitle: 'Mythic Centurion',
          badgeIcon: '👑',
          accentColor: const Color(0xFFF3BA2F),
        );
        _isShowing = false;
        return;
      }
    }

    if (level >= 50) {
      final shown50 = prefs.getBool('prestige_celebrated_lvl50') ?? false;
      if (!shown50) {
        _isShowing = true;
        await prefs.setBool('prestige_celebrated_lvl50', true);
        if (!context.mounted) return;
        await _showDialog(
          context: context,
          ref: ref,
          level: 50,
          badgeTitle: 'Grandmaster 50',
          badgeIcon: '🔱',
          accentColor: const Color(0xFF38BDF8),
        );
        _isShowing = false;
      }
    }
  }

  static Future<void> _showDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int level,
    required String badgeTitle,
    required String badgeIcon,
    required Color accentColor,
  }) async {
    HapticFeedback.lightImpact();

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Prestige Celebrated',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
      pageBuilder: (context, _, __) {
        return _PrestigeCelebrationDialog(
          level: level,
          badgeTitle: badgeTitle,
          badgeIcon: badgeIcon,
          accentColor: accentColor,
        );
      },
    );
  }
}

class _PrestigeCelebrationDialog extends StatelessWidget {
  final int level;
  final String badgeTitle;
  final String badgeIcon;
  final Color accentColor;

  const _PrestigeCelebrationDialog({
    required this.level,
    required this.badgeTitle,
    required this.badgeIcon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF141922),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF283141),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2532),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E394C),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: accentColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'PRESTIGE MILESTONE UNLOCKED',
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Matte Badge Emblem
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2330),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF333E52),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  badgeIcon,
                  style: const TextStyle(fontSize: 40, height: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              badgeTitle,
              style: GoogleFonts.inter(
                color: const Color(0xFFF1F5F9),
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            Text(
              'You achieved Level $level in your trading career!',
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Info Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A212D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF283344), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.leaderboard_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Prestige Badge is now featured on the global Leaderboard and your trader profile.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Equip & Showcase Badge',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
