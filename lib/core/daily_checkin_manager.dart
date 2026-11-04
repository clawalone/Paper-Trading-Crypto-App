import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'app_review_manager.dart';
import 'currency_formatters.dart';
import '../data/user_provider.dart';

class DailyCheckInManager {
  static bool _hasPromptedThisSession = false;

  /// Call on Dashboard startup. If the user hasn't claimed their daily check-in today,
  /// opens a welcoming 7-day progression pop-up dialog.
  static void checkAndShowDailyDialog(BuildContext context, WidgetRef ref) {
    if (_hasPromptedThisSession) return;

    final userState = ref.read(userProvider);
    if (!userState.isOnboarded || userState.hasClaimedDaily || userState.isLoading) return;

    _hasPromptedThisSession = true;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!context.mounted) return;
      final current = ref.read(userProvider);
      if (current.hasClaimedDaily) return;

      _showDailyDialog(context, ref);
    });
  }

  static void _showDailyDialog(BuildContext context, WidgetRef ref) {
    final userState = ref.read(userProvider);
    final profile = userState.profile;
    String formatCash(double usd) {
      return CurrencyFormatters.formatUsd(usd, profile.preferredCurrency, decimalDigits: 0);
    }

    // Calculate current cycle day (1 to 7) based on streak
    final now = DateTime.now().toLocal();
    int nextStreak = 1;
    if (profile.lastDailyClaim != null) {
      final lastClaim = DateTime.tryParse(profile.lastDailyClaim!);
      if (lastClaim != null) {
        final lastClaimDate = DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
        final nowDate = DateTime(now.year, now.month, now.day);
        final diff = nowDate.difference(lastClaimDate).inDays;
        if (diff == 1) {
          nextStreak = profile.streak + 1;
        } else if (diff == 0) {
          nextStreak = profile.streak;
        } else {
          nextStreak = 1;
        }
      }
    }

    final int todayCycleDay = ((nextStreak - 1) % 7) + 1; // 1..7
    const List<double> cashRewards = UserNotifier.DAILY_CASH_TIERS;
    const List<int> xpRewards = UserNotifier.DAILY_XP_TIERS;
    final double todayCash = cashRewards[todayCycleDay - 1];
    final int todayXp = xpRewards[todayCycleDay - 1];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2329),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF2B3139), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row: Title & Streak Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('📅', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Check-In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Check in 7 consecutive days for mega rewards!',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '🔥 ${profile.streak}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 7-DAY PROGRESSION GRID
                // Row 1: Days 1 to 4
                Row(
                  children: [
                    for (int day = 1; day <= 4; day++) ...[
                      Expanded(
                        child: _buildDayCard(
                          day: day,
                          isToday: day == todayCycleDay,
                          isClaimed: day < todayCycleDay,
                          cashReward: formatCash(cashRewards[day - 1]),
                          xpReward: xpRewards[day - 1],
                        ),
                      ),
                      if (day < 4) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Day 5, Day 6, and Day 7 (Day 7 is Mega Bonus spanning 2x)
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildDayCard(
                        day: 5,
                        isToday: 5 == todayCycleDay,
                        isClaimed: 5 < todayCycleDay,
                        cashReward: formatCash(cashRewards[4]),
                        xpReward: xpRewards[4],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: _buildDayCard(
                        day: 6,
                        isToday: 6 == todayCycleDay,
                        isClaimed: 6 < todayCycleDay,
                        cashReward: formatCash(cashRewards[5]),
                        xpReward: xpRewards[5],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: _buildDay7Card(
                        isToday: 7 == todayCycleDay,
                        isClaimed: 7 < todayCycleDay,
                        cashReward: formatCash(cashRewards[6]),
                        xpReward: xpRewards[6],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Claim Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(userProvider.notifier).claimDailyReward(
                        customCash: todayCash,
                        customXp: todayXp,
                      );
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Text('🎉', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Day $todayCycleDay claimed! +${formatCash(todayCash)} & +$todayXp XP added!',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.profit,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      if (todayCycleDay >= 2) {
                        AppReviewManager.checkAndPromptReview(
                          context,
                          ref,
                          triggerReason: 'Day $todayCycleDay Streak Reached',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'Claim Day $todayCycleDay (+${formatCash(todayCash)})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Maybe Later
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildDayCard({
    required int day,
    required bool isToday,
    required bool isClaimed,
    required String cashReward,
    required int xpReward,
  }) {
    Color cardBg;
    Color borderColor;

    if (isToday) {
      cardBg = const Color(0xFF242A32);
      borderColor = const Color(0xFFF59E0B);
    } else if (isClaimed) {
      cardBg = const Color(0xFF14191F);
      borderColor = AppColors.profit.withValues(alpha: 0.4);
    } else {
      cardBg = const Color(0xFF181C22);
      borderColor = const Color(0xFF2B3139);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Day $day',
            style: TextStyle(
              color: isToday
                  ? const Color(0xFFF59E0B)
                  : (isClaimed ? Colors.white54 : Colors.white38),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          if (isClaimed)
            const Icon(Icons.check_circle_rounded, color: AppColors.profit, size: 20)
          else if (isToday)
            const Text('💰', style: TextStyle(fontSize: 18))
          else
            const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 18),
          const SizedBox(height: 5),
          Text(
            '+$cashReward',
            style: TextStyle(
              color: isToday
                  ? AppColors.profit
                  : (isClaimed ? Colors.white38 : Colors.white70),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '+$xpReward XP',
            style: TextStyle(
              color: isToday ? const Color(0xFFF59E0B) : Colors.white24,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDay7Card({
    required bool isToday,
    required bool isClaimed,
    required String cashReward,
    required int xpReward,
  }) {
    Color cardBg;
    Color borderColor;

    if (isToday) {
      cardBg = const Color(0xFF242A32);
      borderColor = const Color(0xFFF59E0B);
    } else if (isClaimed) {
      cardBg = const Color(0xFF14191F);
      borderColor = AppColors.profit.withValues(alpha: 0.4);
    } else {
      cardBg = const Color(0xFF181C22);
      borderColor = const Color(0xFF2B3139);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Day 7',
                      style: TextStyle(
                        color: isToday ? const Color(0xFFF59E0B) : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'MEGA',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+$cashReward',
                  style: TextStyle(
                    color: isToday ? AppColors.profit : (isClaimed ? Colors.white38 : Colors.white),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '+$xpReward XP',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (isClaimed)
            const Icon(Icons.check_circle_rounded, color: AppColors.profit, size: 20)
          else if (!isToday)
            const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 18),
        ],
      ),
    );
  }
}
