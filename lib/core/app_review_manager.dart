import 'dart:async';
import 'package:stock_arena/core/app_material.dart';
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

  static const String feedbackEmail = 'acadrio.official@gmail.com';

  static final InAppReview _inAppReview = InAppReview.instance;
  static bool _isDialogShowing = false;

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

  /// Directly launches the Google Play Store / App Store listing (unbiased)
  static Future<void> openStoreListing() async {
    final marketUri = Uri.parse('market://details?id=com.acadriotrade');
    final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.acadriotrade');

    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing(appStoreId: 'com.acadriotrade');
        return;
      }
    } catch (_) {}

    bool launched = false;
    try {
      launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  /// Shows the standard, unbiased in-app review prompt (Google Play compliant)
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
      final userState = ref.read(userProvider);
      final currency = userState.profile.preferredCurrency;

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: AppColors.surface,
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
                  // Gold Stars Badge
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0B90B).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFFF0B90B).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF0B90B),
                        size: 36,
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
                  Text(
                    'Enjoying Paper Trading?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'Your honest review helps other paper traders discover the app and supports our continuous simulator improvements.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button 1: Rate on Google Play (or in-app review API)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_prefKeyHasRated, true);

                        // Try native in-app review sheet first, fallback to store listing
                        try {
                          if (await _inAppReview.isAvailable()) {
                            await _inAppReview.requestReview();
                            return;
                          }
                        } catch (_) {}

                        await openStoreListing();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0B90B),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.star_rounded, size: 20, color: Colors.black),
                      label: const Text(
                        'Rate on Google Play',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Action Button 2: Send Feedback / Contact Support
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _handleConstructiveFeedback(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.outline, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.mail_outline_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text(
                        'Send Feedback or Report Bug',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  // Action Button 3: Maybe Later
                  if (!isFromProfile) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        final p = await SharedPreferences.getInstance();
                        await p.setInt(_prefKeyLastPromptEpoch, DateTime.now().millisecondsSinceEpoch);
                      },
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
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

  /// Handles constructive user feedback privately via email
  static Future<void> _handleConstructiveFeedback(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'Unknown';

    const subject = '[Trader Feedback] Improvement Suggestions';
    final body =
        'Hi Acadrio Team,\n\n'
        'Here are a few suggestions to improve PaperTrading - Crypto & Stocks:\n\n'
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
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Thank you! Support email copied: acadrio.official@gmail.com',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
