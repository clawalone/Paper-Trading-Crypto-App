import 'package:stock_arena/core/app_material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/profile/request_money_screen.dart';
import 'app_theme.dart';

class TopUpOfferManager {
  static const String _prefDismissedOfferKey = 'dismissed_topup_offer_id';
  static bool _hasCheckedThisSession = false;

  static Future<void> checkAndShowOffer(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('promotions').get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final isActive = (data['isActive'] as bool?) ?? false;
      if (!isActive) return;

      final isRepeat = (data['repeat'] as bool?) ?? false;
      final offerId = (data['offerId'] as String?) ?? 'default_offer';
      
      // Check if this offerId was already dismissed (unless repeat is enabled)
      if (!isRepeat) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedOfferId = prefs.getString(_prefDismissedOfferKey);
        if (dismissedOfferId == offerId) return;
      }

      final title = (data['title'] as String?) ?? 'Top Up Virtual Capital';
      final message = (data['message'] as String?) ??
          'Add funds to your paper trading account to practice new strategies without financial risk.';
      final badgeText = (data['badgeText'] as String?) ?? 'Promotional Offer';
      final buttonText = (data['buttonText'] as String?) ?? 'View Packages';

      if (context.mounted) {
        _showOfferDialog(
          context,
          offerId: offerId,
          title: title,
          message: message,
          badgeText: badgeText,
          buttonText: buttonText,
        );
      }
    } catch (_) {}
  }

  static Future<void> _markOfferDismissed(String offerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDismissedOfferKey, offerId);
    } catch (_) {}
  }

  static void _showOfferDialog(
    BuildContext context, {
    required String offerId,
    required String title,
    required String message,
    required String badgeText,
    required String buttonText,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.outline,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Clean Wallet / Capital Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.outline,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pill Badge
                  if (badgeText.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText.replaceAll('🔥', '').replaceAll('🚀', '').trim(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Heading
                  Text(
                    title.replaceAll('🔥', '').replaceAll('🚀', '').trim(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    message,
                    style: TextStyle(
                      color: AppColors.subtle,
                      fontSize: 13,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  // Structured Feature Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          icon: Icons.shield_outlined,
                          title: '100% Risk-Free Simulation',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: AppColors.outline, height: 1),
                        ),
                        _buildSummaryRow(
                          icon: Icons.flash_on_outlined,
                          title: 'Instant balance top-up',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Solid Primary Action
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        _markOfferDismissed(offerId);
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RequestMoneyScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        buttonText.replaceAll('🔥', '').replaceAll('🚀', '').trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Minimal Secondary Dismiss
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: TextButton(
                      onPressed: () {
                        _markOfferDismissed(offerId);
                        Navigator.pop(dialogContext);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.subtle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subtle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildSummaryRow({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.subtle,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
