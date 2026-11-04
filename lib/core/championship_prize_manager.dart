import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'currency_formatters.dart';
import '../data/user_provider.dart';

class ChampionshipPrizeManager {
  static bool _hasCheckedThisSession = false;
  static Timer? _standingMondayTimer;
  static bool _isSettlingNow = false;

  /// Top 10 Prize Structure
  static const Map<int, double> rankPrizes = {
    1: 50000.0,
    2: 25000.0,
    3: 10000.0,
    4: 1000.0,
    5: 1000.0,
    6: 1000.0,
    7: 1000.0,
    8: 1000.0,
    9: 1000.0,
    10: 1000.0,
  };

  static double getPrizeForRank(int rank) {
    return rankPrizes[rank] ?? (rank <= 10 ? 1000.0 : 0.0);
  }

  /// Returns the start of the current week (most recent Monday at 00:00:00).
  static DateTime getMostRecentMonday(DateTime now) {
    final daysSinceMonday = (now.weekday - DateTime.monday) % 7;
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
    return DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
  }

  /// Returns the next upcoming Monday at 00:00:00 (12:00 AM midnight).
  static DateTime getNextMondayMidnight(DateTime now) {
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    final daysToAdd = daysUntilMonday == 0 ? 7 : daysUntilMonday;
    final nextMonday = now.add(Duration(days: daysToAdd));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 0, 0, 0);
  }

  /// Formats a week identifier (e.g. "Week-2026-11-02")
  static String getWeekId(DateTime monday) {
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return 'Week-$y-$m-$d';
  }

  /// Automatically checks if the current week's Monday 12:00 AM settlement has occurred.
  /// If not, it executes the payout automatically and schedules the timer for next Monday 12:00 AM.
  static Future<void> checkWeeklySettlementAndSchedule() async {
    if (_isSettlingNow) return;

    final now = DateTime.now();
    final recentMonday = getMostRecentMonday(now);
    final weekId = getWeekId(recentMonday);

    try {
      bool alreadySettled = false;

      // 1. Check in weekly_championship (100% permitted for all authenticated users)
      try {
        final champSettlementDoc = await FirebaseFirestore.instance
            .collection('weekly_championship')
            .doc('__settlement_$weekId')
            .get();
        if (champSettlementDoc.exists && (champSettlementDoc.data()?['settled'] == true)) {
          alreadySettled = true;
        }
      } catch (_) {}

      // 2. Fallback check championship_settlement collection
      if (!alreadySettled) {
        try {
          final settlementDoc = await FirebaseFirestore.instance
              .collection('championship_settlement')
              .doc(weekId)
              .get();
          if (settlementDoc.exists && (settlementDoc.data()?['settled'] == true)) {
            alreadySettled = true;
          }
        } catch (_) {}
      }

      // If not yet settled for this week's Monday, run the automated distribution!
      if (!alreadySettled) {
        _isSettlingNow = true;
        debugPrint('[Championship] Auto-triggering weekly prize distribution for $weekId...');

        // Claim settlement lock in weekly_championship
        try {
          await FirebaseFirestore.instance
              .collection('weekly_championship')
              .doc('__settlement_$weekId')
              .set({
            'settled': true,
            'settledAt': FieldValue.serverTimestamp(),
            'autoTriggered': true,
            'weekId': weekId,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[Championship] Lock warning: $e');
        }

        final res = await finalizeAndDistributeRewards(
          weekTitle: 'Weekly Championship ($weekId)',
        );

        debugPrint('[Championship] Auto-settlement result: ${res['message']}');
      }
    } catch (e) {
      debugPrint('[Championship] Error checking automated settlement: $e');
    } finally {
      _isSettlingNow = false;
    }

    // Schedule precision timer for the exact upcoming Monday 12:00 AM
    _scheduleNextMondayTimer();
  }

  static void _scheduleNextMondayTimer() {
    _standingMondayTimer?.cancel();
    final now = DateTime.now();
    final nextMonday = getNextMondayMidnight(now);
    final delay = nextMonday.difference(now);

    debugPrint('[Championship] Scheduled next auto-payout for $nextMonday (in ${delay.inHours}h ${delay.inMinutes % 60}m)');

    _standingMondayTimer = Timer(delay, () async {
      await checkWeeklySettlementAndSchedule();
    });
  }

  /// Checks if current user has an unclaimed Weekly Championship prize.
  static Future<void> checkAndShowClaimDialog(BuildContext context, WidgetRef ref) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    // Trigger auto-settlement check in background on dashboard launch
    unawaited(checkWeeklySettlementAndSchedule());

    try {
      final userState = ref.read(userProvider);
      final email = userState.profile.email;
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final uidKey = email.isNotEmpty ? email.replaceAll('.', '_') : authUid;

      if (uidKey == null || uidKey.isEmpty) return;

      String foundDocId = '';
      String targetCollection = 'weekly_championship';
      Map<String, dynamic> data = {};

      // 1. Check direct prize doc in weekly_championship
      try {
        final champPrizeDoc = await FirebaseFirestore.instance
            .collection('weekly_championship')
            .doc('prize_$uidKey')
            .get();
        if (champPrizeDoc.exists && (champPrizeDoc.data()?['claimed'] != true)) {
          foundDocId = champPrizeDoc.id;
          targetCollection = 'weekly_championship';
          data = champPrizeDoc.data() ?? {};
        }
      } catch (_) {}

      // 2. Check pendingPrize inside user's participant doc in weekly_championship
      if (foundDocId.isEmpty) {
        try {
          final participantDoc = await FirebaseFirestore.instance
              .collection('weekly_championship')
              .doc(uidKey)
              .get();
          if (participantDoc.exists && participantDoc.data()?['pendingPrize'] is Map) {
            final pending = Map<String, dynamic>.from(participantDoc.data()!['pendingPrize'] as Map);
            if (pending['claimed'] != true) {
              foundDocId = participantDoc.id;
              targetCollection = 'weekly_championship';
              data = pending;
            }
          }
        } catch (_) {}
      }

      // 3. Fallback check weekly_prizes collection
      if (foundDocId.isEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('weekly_prizes').doc(uidKey).get();
          if (doc.exists && (doc.data()?['claimed'] != true)) {
            foundDocId = doc.id;
            targetCollection = 'weekly_prizes';
            data = doc.data() ?? {};
          }
        } catch (_) {}
      }

      if (foundDocId.isEmpty || data.isEmpty) return;

      final isClaimed = (data['claimed'] as bool?) ?? false;
      if (isClaimed) return;

      // STRICT ELIGIBILITY CHECK:
      // Only traders who crossed >0.0% profit qualify for prize payouts.
      // Traders with 0.0% or negative scores are strictly ineligible.
      double verifiedScore = 0.0;
      if (data.containsKey('score') && data['score'] != null) {
        verifiedScore = (data['score'] as num?)?.toDouble() ?? 0.0;
      } else {
        // Legacy prize doc without explicit score field: inspect user's participant doc
        try {
          final pDoc = await FirebaseFirestore.instance
              .collection('weekly_championship')
              .doc(uidKey)
              .get();
          if (pDoc.exists) {
            verifiedScore = (pDoc.data()?['tournamentScore'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (_) {}
      }

      if (verifiedScore <= 0.0) {
        debugPrint('[Championship] Disqualified claim attempt for $uidKey (score: $verifiedScore <= 0.0%)');
        unawaited(_voidIneligiblePrize(foundDocId, targetCollection));
        return;
      }

      final rank = (data['rank'] as num?)?.toInt() ?? 1;
      final amount = (data['amount'] as num?)?.toDouble() ?? getPrizeForRank(rank);
      final weekId = (data['weekId'] as String?) ?? 'Weekly Cup';

      if (context.mounted) {
        _showPrizeDialog(
          context,
          ref: ref,
          docId: foundDocId,
          collectionName: targetCollection,
          rank: rank,
          amount: amount,
          weekId: weekId,
          score: verifiedScore,
        );
      }
    } catch (_) {}
  }

  static Future<void> _voidIneligiblePrize(String docId, String collectionName) async {
    try {
      if (collectionName == 'weekly_championship') {
        if (docId.startsWith('prize_')) {
          await FirebaseFirestore.instance.collection('weekly_championship').doc(docId).delete();
        } else {
          await FirebaseFirestore.instance.collection('weekly_championship').doc(docId).update({
            'pendingPrize': FieldValue.delete(),
          });
        }
      } else if (collectionName == 'weekly_prizes') {
        await FirebaseFirestore.instance.collection('weekly_prizes').doc(docId).delete();
      }
    } catch (e) {
      debugPrint('[Championship] Failed to void ineligible prize: $e');
    }
  }

  static void _showPrizeDialog(
    BuildContext context, {
    required WidgetRef ref,
    required String docId,
    required int rank,
    required double amount,
    required String weekId,
    String? collectionName,
    double score = 1.0,
  }) {
    final userState = ref.read(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    // Dynamic Rank Theme Colors
    final Color themeColor;
    final String badgeLabel;
    final IconData iconData;

    if (rank == 1) {
      themeColor = const Color(0xFFF3BA2F); // Gold
      badgeLabel = '🥇 #1 WEEKLY CHAMPION';
      iconData = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      themeColor = const Color(0xFFC0C0C0); // Silver
      badgeLabel = '🥈 #2 RUNNER UP';
      iconData = Icons.military_tech_rounded;
    } else if (rank == 3) {
      themeColor = const Color(0xFFCD7F32); // Bronze
      badgeLabel = '🥉 #3 3RD PLACE PODIUM';
      iconData = Icons.workspace_premium_rounded;
    } else {
      themeColor = AppColors.profit; // Emerald green
      badgeLabel = '🎖️ #$rank TOP 10 ELITE TRADER';
      iconData = Icons.military_tech_outlined;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0D1117),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: themeColor.withValues(alpha: 0.6), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Trophy Badge Glow
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    iconData,
                    color: themeColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),

                // Rank Badge Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Main Title
                const Text(
                  'CONGRATULATIONS!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'You finished Rank #$rank in the $weekId Trading Cup! Your hard work and trading skills paid off.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Prize Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.profit.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.profit.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'VIRTUAL CASH PRIZE WON',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+${formatter.format(amount)}',
                        style: const TextStyle(
                          color: AppColors.profit,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Virtual Cash (Paper Trading Balance)',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Claim Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      // 1. Mark as claimed in Firestore
                      final col = collectionName ?? 'weekly_championship';
                      try {
                        final refDoc = FirebaseFirestore.instance.collection(col).doc(docId);
                        final snapshot = await refDoc.get();
                        if (snapshot.exists) {
                          final snapData = snapshot.data();
                          if (snapData != null && snapData.containsKey('pendingPrize')) {
                            await refDoc.update({
                              'pendingPrize.claimed': true,
                              'pendingPrize.claimedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await refDoc.update({
                              'claimed': true,
                              'claimedAt': FieldValue.serverTimestamp(),
                            });
                          }
                        }
                      } catch (_) {}

                      // Also try weekly_prizes for redundancy
                      try {
                        await FirebaseFirestore.instance.collection('weekly_prizes').doc(docId).update({
                          'claimed': true,
                          'claimedAt': FieldValue.serverTimestamp(),
                        });
                      } catch (_) {}

                      // 2. Credit to user account
                      ref.read(userProvider.notifier).creditChampionshipPrize(
                        amount: amount,
                        rank: rank,
                        weekId: weekId,
                        score: score,
                      );

                      // 3. Show celebration toast
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '🎉 +${formatter.format(amount)} virtual cash credited to your wallet balance!',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.profit,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'CLAIM ${formatter.format(amount)} VIRTUAL CASH 🚀',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
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

  /// Finalize the current week and distribute prizes to Top 10 players.
  /// Also resets all scores back to 0.0% for a fresh week!
  static Future<Map<String, dynamic>> finalizeAndDistributeRewards({
    required String weekTitle,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('weekly_championship')
          .orderBy('tournamentScore', descending: true)
          .get();

      // Filter out internal metadata and prize docs
      final validParticipants = snapshot.docs.where((d) =>
        !d.id.startsWith('__') && !d.id.startsWith('prize_') && !d.id.startsWith('settlement_')
      ).toList();

      if (validParticipants.isEmpty) {
        return {'success': false, 'message': 'No tournament participants found.'};
      }

      // CRITICAL ELIGIBILITY RULE:
      // Only participants who crossed 0.0% profit (> 0.0%) qualify for Top 10 prizes.
      // Participants with 0.0% or negative scores are strictly ineligible.
      final eligibleWinners = validParticipants.where((d) {
        final data = d.data();
        final rawScore = (data['tournamentScore'] as num?)?.toDouble() ?? 0.0;
        return rawScore > 0.0;
      }).take(10).toList();

      int distributedCount = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < eligibleWinners.length; i++) {
        final doc = eligibleWinners[i];
        final rank = i + 1;
        final prize = getPrizeForRank(rank);
        final data = doc.data();
        final rawName = (data['name'] as String?) ?? 'Trader';
        final rawScore = (data['tournamentScore'] as num?)?.toDouble() ?? 0.0;

        // 1. Write prize doc to weekly_championship (100% permitted in Firestore rules)
        final prizeRef = FirebaseFirestore.instance
            .collection('weekly_championship')
            .doc('prize_${doc.id}');
        batch.set(prizeRef, {
          'uid': doc.id,
          'name': rawName,
          'rank': rank,
          'amount': prize,
          'score': rawScore,
          'weekId': weekTitle,
          'claimed': false,
          'awardedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Set pendingPrize and reset score on the participant doc
        batch.set(doc.reference, {
          'pendingPrize': {
            'amount': prize,
            'rank': rank,
            'score': rawScore,
            'weekId': weekTitle,
            'claimed': false,
            'awardedAt': FieldValue.serverTimestamp(),
          },
          'tournamentScore': 0.0,
          'wins': 0,
          'losses': 0,
          'lastResetAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        distributedCount++;
      }

      // Reset all remaining participants' scores for fresh week start
      // AND explicitly delete any pendingPrize or prize_ docs for non-winners!
      final eligibleWinnerIds = eligibleWinners.map((d) => d.id).toSet();
      for (final doc in validParticipants) {
        if (!eligibleWinnerIds.contains(doc.id)) {
          batch.set(doc.reference, {
            'pendingPrize': FieldValue.delete(),
            'tournamentScore': 0.0,
            'wins': 0,
            'losses': 0,
            'lastResetAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          final bogusPrizeRef = FirebaseFirestore.instance
              .collection('weekly_championship')
              .doc('prize_${doc.id}');
          batch.delete(bogusPrizeRef);
        }
      }

      // Record settlement in weekly_championship (100% permitted in Firestore rules)
      final now = DateTime.now();
      final recentMonday = getMostRecentMonday(now);
      final weekId = getWeekId(recentMonday);
      final settlementRef = FirebaseFirestore.instance
          .collection('weekly_championship')
          .doc('__settlement_$weekId');
      batch.set(settlementRef, {
        'settled': true,
        'settledAt': FieldValue.serverTimestamp(),
        'winnersCount': distributedCount,
        'weekId': weekId,
        'minProfitRequired': 0.0,
      }, SetOptions(merge: true));

      await batch.commit();

      // Non-blocking mirror to weekly_prizes and notifications for eligible winners
      try {
        final mirrorBatch = FirebaseFirestore.instance.batch();
        for (int i = 0; i < eligibleWinners.length; i++) {
          final doc = eligibleWinners[i];
          final rank = i + 1;
          final prize = getPrizeForRank(rank);
          final data = doc.data();
          final rawName = (data['name'] as String?) ?? 'Trader';
          final rawScore = (data['tournamentScore'] as num?)?.toDouble() ?? 0.0;
          final pRef = FirebaseFirestore.instance.collection('weekly_prizes').doc(doc.id);
          mirrorBatch.set(pRef, {
            'uid': doc.id,
            'name': rawName,
            'rank': rank,
            'amount': prize,
            'score': rawScore,
            'weekId': weekTitle,
            'claimed': false,
            'awardedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Also deliver to user's notifications box
          FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .collection('notifications')
              .add({
                'userId': doc.id,
                'title': '🏆 Championship Prize Won!',
                'message': 'You placed #$rank in Weekly Championship with +${rawScore.toStringAsFixed(1)}% profit! Your \$$prize prize is ready to claim.',
                'category': 'prize',
                'type': 'weekly_prize',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
                'data': {
                  'rank': rank,
                  'amount': prize,
                  'score': rawScore,
                  'weekId': weekTitle,
                },
              }).then<void>((_) {}, onError: (_) {});
        }
        final sRef = FirebaseFirestore.instance.collection('championship_settlement').doc(weekId);
        mirrorBatch.set(sRef, {
          'settled': true,
          'settledAt': FieldValue.serverTimestamp(),
          'winnersCount': distributedCount,
          'weekId': weekId,
          'minProfitRequired': 0.0,
        }, SetOptions(merge: true));
        await mirrorBatch.commit();
      } catch (e) {
        debugPrint('[Championship] Note: legacy collection mirror skipped ($e)');
      }

      return {
        'success': true,
        'message': distributedCount > 0
            ? 'Successfully awarded $distributedCount eligible trader(s) with >0.0% profit and reset leaderboard to 0.0%!'
            : 'Championship reset for new week. No prizes distributed as no traders crossed >0.0% profit threshold.',
        'count': distributedCount,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
