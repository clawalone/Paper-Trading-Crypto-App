import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_theme.dart';
import 'currency_formatters.dart';
import '../data/user_provider.dart';

class AppReviewManager {
  static const String _prefKeyHasRated = 'app_review_has_rated';
  static const String _prefKeyLastPromptEpoch = 'app_review_last_prompt_epoch';
  static const String _prefKeyRewardClaimed = 'app_review_reward_claimed';

  static const double bonusCashReward = 25.0;
  static const int bonusXpReward = 100;
  static const String feedbackEmail = 'acadrio.official@gmail.com';

  static final InAppReview _inAppReview = InAppReview.instance;
  static bool _isDialogShowing = false;

  /// Check if the user has already claimed the review reward
  static Future<bool> hasClaimedReviewReward() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyRewardClaimed) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check if eligible to prompt automatically on a happy moment
  static Future<bool> shouldPromptReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRated = prefs.getBool(_prefKeyHasRated) ?? false;
      if (hasRated) {
        debugPrint('[AppReviewManager] User already rated, skipping prompt');
        return false;
      }

      final lastDismissedEpoch = prefs.getInt(_prefKeyLastPromptEpoch) ?? 0;
      if (lastDismissedEpoch > 0) {
        final lastDismissed = DateTime.fromMillisecondsSinceEpoch(lastDismissedEpoch);
        final daysSinceLast = DateTime.now().difference(lastDismissed).inDays;
        // Snooze for at least 7 days before prompting again if user previously tapped 'Maybe Later'
        if (daysSinceLast < 7) {
          debugPrint('[AppReviewManager] Snoozed: $daysSinceLast days since last dismissal (needs 7)');
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Triggers a review check on "Happy Moments" (e.g. profitable trade, streak milestone)
  static void checkAndPromptReview(
    BuildContext context,
    WidgetRef ref, {
    String triggerReason = 'Profitable Trade',
    double? pnlAmount,
  }) {
    if (_isDialogShowing) {
      debugPrint('[AppReviewManager] Dialog is already active, skipping trigger');
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!context.mounted) {
        debugPrint('[AppReviewManager] context was unmounted after 500ms delay');
        return;
      }
      if (_isDialogShowing) return;
      final eligible = await shouldPromptReview();
      if (!eligible || !context.mounted) return;

      debugPrint('[AppReviewManager] Launching review dialog for: $triggerReason');
      showReviewDialog(
        context,
        ref,
        triggerReason: triggerReason,
        pnlAmount: pnlAmount,
        isFromProfile: false,
      );
    });
  }

  /// Shows the high-conversion review dialog
  static Future<void> showReviewDialog(
    BuildContext context,
    WidgetRef ref, {
    String? triggerReason,
    double? pnlAmount,
    bool isFromProfile = false,
  }) async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadyClaimed = prefs.getBool(_prefKeyRewardClaimed) ?? false;
      final userState = ref.read(userProvider);
      final currency = userState.profile.preferredCurrency;
      final formattedReward = CurrencyFormatters.formatUsd(bonusCashReward, currency, decimalDigits: 0);

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: const Color(0xFF1E2329),
            elevation: 24,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: const Color(0xFFF0B90B).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Gold Stars Badge
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF0B90B).withValues(alpha: 0.25),
                          const Color(0xFFF0B90B).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFF0B90B).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF0B90B),
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5 Star decorative row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF0B90B),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Win context badge (if triggered by a profitable trade or milestone)
                  if (triggerReason != null && pnlAmount != null && pnlAmount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.profit.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.profit.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '🎉 $triggerReason • +${CurrencyFormatters.formatUsd(pnlAmount, currency)} Profit!',
                        style: const TextStyle(
                          color: AppColors.profit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  // Title
                  const Text(
                    'Enjoying Paper Trading?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  const Text(
                    'Your 5-star rating helps other traders find us and keeps our free simulator growing!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reward Callout Card (if bonus not yet claimed)
                  if (!alreadyClaimed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF0B90B).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0B90B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.card_giftcard_rounded,
                              color: Color(0xFFF0B90B),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rating Reward Bonus',
                                  style: TextStyle(
                                    color: Color(0xFFF0B90B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '+$formattedReward Cash & +$bonusXpReward XP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ─── ACTION BUTTONS ───
                  // Button 1: "Loving it! Rate on Google Play"
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _handlePositiveRating(context, ref, alreadyClaimed, formattedReward);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0B90B),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.thumb_up_rounded, size: 18, color: Colors.black),
                      label: const Text(
                        'Loving it! Rate on Play Store ⭐',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Button 2: "Could be better" (Sends private email to keep 1-stars off the store)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _handleConstructiveFeedback(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF2B3139), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white60),
                      label: const Text(
                        'Could be better 💬',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),

                  // Button 3: Maybe Later
                  if (!isFromProfile) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        final p = await SharedPreferences.getInstance();
                        await p.setInt(_prefKeyLastPromptEpoch, DateTime.now().millisecondsSinceEpoch);
                      },
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  /// Handles 5-star positive review by navigating to Google Play Store listing
  static Future<void> _handlePositiveRating(
    BuildContext context,
    WidgetRef ref,
    bool alreadyClaimed,
    String formattedReward,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyHasRated, true);

      // Directly open the Google Play Store directly to reviews
      final marketUri = Uri.parse('market://details?id=com.acadriotrade&showAllReviews=true');
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.acadriotrade&showAllReviews=true');

      bool launched = false;
      try {
        launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          if (await canLaunchUrl(marketUri)) {
            launched = await launchUrl(marketUri, mode: LaunchMode.externalNonBrowserApplication);
          }
        } catch (_) {}
      }

      if (!launched) {
        try {
          launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      if (!launched) {
        try {
          await _inAppReview.openStoreListing(appStoreId: 'com.acadriotrade');
        } catch (_) {}
      }

      // Claim one-time reward if not yet claimed
      if (!alreadyClaimed) {
        await prefs.setBool(_prefKeyRewardClaimed, true);
        ref.read(userProvider.notifier).claimReviewReward(
          amount: bonusCashReward,
          xp: bonusXpReward,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E2329),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFF0B90B), width: 1),
              ),
              content: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thank you for your rating! +$formattedReward Cash & +$bonusXpReward XP added!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {}
  }

  /// Handles constructive negative feedback privately via email
  static Future<void> _handleConstructiveFeedback(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'Unknown';

    const subject = '[Trader Feedback] Improvement Suggestions';
    final body =
        'Hi Acadrio Team,\n\n'
        'Here are a few suggestions to improve Paper Trading - Crypto:\n\n'
        '1. What could be improved?\n'
        '[Enter your feedback here]\n\n'
        '2. Features you would like to see:\n'
        '[Enter requested features]\n\n'
        'Trader UID: $uid\n\n'
        'Thank you!';

    final emailUri = Uri(
      scheme: 'mailto',
      path: feedbackEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not launch mail client');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: feedbackEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E2329),
            content: Text(
              'Thank you! Support email copied: acadrio.official@gmail.com',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
