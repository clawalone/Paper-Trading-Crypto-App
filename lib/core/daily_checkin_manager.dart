import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'app_review_manager.dart';
import 'currency_formatters.dart';
import 'rewarded_ad_manager.dart';
import '../data/user_provider.dart';

class DailyCheckInManager {
  static bool _hasPromptedThisSession = false;

  /// Call to manually open the daily check-in dialog.
  static void showDailyDialog(BuildContext context, WidgetRef ref) {
    _showDailyDialog(context, ref);
  }

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
    // Warm up the rewarded ad buffer immediately so the 2X ad starts instantly
    RewardedAdManager.instance.preload();

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
        bool isAdLoading = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final alreadyClaimed = ref.read(userProvider).hasClaimedDaily;
            return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              physics: const BouncingScrollPhysics(),
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
                            Text(
                              'Daily Check-In',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Check in 7 consecutive days for mega rewards!',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🔥 ${profile.streak}',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
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

                if (alreadyClaimed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF00C087), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Checked in for today! Streak: ${profile.streak} 🔥',
                          style: const TextStyle(
                            color: Color(0xFF00C087),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Primary Action: 2X Double Video Reward
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isAdLoading
                          ? null
                          : () async {
                              setDialogState(() => isAdLoading = true);
                              final success = await RewardedAdManager.instance.playRewardedSequence(
                                context: context,
                                requiredAds: 1,
                                onProgress: (current, total) {},
                              );

                              if (!dialogContext.mounted) return;
                              setDialogState(() => isAdLoading = false);

                              if (success) {
                                ref.read(userProvider.notifier).claimDailyReward(
                                      customCash: todayCash * 2,
                                      customXp: todayXp * 2,
                                    );
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Text('⚡', style: TextStyle(fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Day $todayCycleDay 2X Doubled! +${formatCash(todayCash * 2)} & +${todayXp * 2} XP added!',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF00C087),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                if (todayCycleDay >= 2) {
                                  AppReviewManager.checkAndPromptReview(
                                    context,
                                    ref,
                                    triggerReason: 'Day $todayCycleDay Streak Doubled',
                                  );
                                }
                              } else {
                                final lastCode = RewardedAdManager.instance.lastLoadErrorCode;
                                final String errorMsg;
                                if (lastCode == 3) {
                                  errorMsg = 'No ad available right now. You can still claim your standard 1X reward below!';
                                } else {
                                  errorMsg = 'Ad was not completed. Reward not doubled.';
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg),
                                    backgroundColor: AppColors.loss,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isAdLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, size: 20, color: Colors.black),
                                const SizedBox(width: 8),
                                Text(
                                  'Double to 2X (+${formatCash(todayCash * 2)})',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Action: 1X Standard Claim (Free)
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: isAdLoading
                          ? null
                          : () {
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
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.outline, width: 1.2),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Claim 1X (+${formatCash(todayCash)})',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Maybe Later
                  Center(
                    child: TextButton(
                      onPressed: isAdLoading ? null : () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
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
      cardBg = AppColors.surfaceAlt;
      borderColor = const Color(0xFFF59E0B);
    } else if (isClaimed) {
      cardBg = AppColors.surfaceAlt.withValues(alpha: 0.5);
      borderColor = AppColors.profit.withValues(alpha: 0.4);
    } else {
      cardBg = AppColors.surfaceAlt;
      borderColor = AppColors.outline;
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
                  : AppColors.subtle,
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
            Icon(Icons.lock_outline_rounded, color: AppColors.subtle, size: 18),
          const SizedBox(height: 5),
          Text(
            '+$cashReward',
            style: TextStyle(
              color: isToday
                  ? AppColors.profit
                  : AppColors.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '+$xpReward XP',
            style: TextStyle(
              color: isToday ? const Color(0xFFF59E0B) : AppColors.subtle,
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
      cardBg = AppColors.surfaceAlt;
      borderColor = const Color(0xFFF59E0B);
    } else if (isClaimed) {
      cardBg = AppColors.surfaceAlt.withValues(alpha: 0.5);
      borderColor = AppColors.profit.withValues(alpha: 0.4);
    } else {
      cardBg = AppColors.surfaceAlt;
      borderColor = AppColors.outline;
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
                        color: isToday ? const Color(0xFFF59E0B) : AppColors.textPrimary,
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
                    color: isToday ? AppColors.profit : AppColors.textPrimary,
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
            Icon(Icons.lock_outline_rounded, color: AppColors.subtle, size: 18),
        ],
      ),
    );
  }
}
