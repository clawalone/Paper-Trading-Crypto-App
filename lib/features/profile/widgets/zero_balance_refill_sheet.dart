import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/currency_formatters.dart';
import '../../../core/rewarded_ad_manager.dart';
import '../../../data/user_provider.dart';
import '../request_money_screen.dart';

class ZeroBalanceRefillSheet extends ConsumerStatefulWidget {
  final String title;
  final String message;
  final double rewardAmountUsd;

  const ZeroBalanceRefillSheet({
    super.key,
    this.title = 'Account Balance Empty',
    this.message =
        'Watch a short video to receive an instant free capital refill and jump straight back into the market.',
    this.rewardAmountUsd = 10.0,
  });

  static DateTime? _lastAutoShownTime;

  /// Automatically shows the refill sheet if user balance is <= 0, with a 15-minute debounce.
  static Future<bool?> checkAndPromptIfZero(
    BuildContext context,
    double balance,
  ) async {
    if (balance > 0.0) return false;
    final now = DateTime.now();
    if (_lastAutoShownTime != null &&
        now.difference(_lastAutoShownTime!) < const Duration(minutes: 15)) {
      return false;
    }
    _lastAutoShownTime = now;
    return show(context);
  }

  /// Explicitly opens the zero-balance refill sheet (e.g., when a trade is blocked by 0 balance).
  static Future<bool?> show(
    BuildContext context, {
    String title = 'Insufficient Trading Margin',
    String message =
        'Your available cash is empty. Watch a short video to claim an instant free capital refill.',
    double rewardAmountUsd = 10.0,
  }) {
    // Smart JIT: Buffer ad as soon as sheet presentation intent occurs
    RewardedAdManager.instance.preload();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ZeroBalanceRefillSheet(
        title: title,
        message: message,
        rewardAmountUsd: rewardAmountUsd,
      ),
    );
  }

  @override
  ConsumerState<ZeroBalanceRefillSheet> createState() =>
      _ZeroBalanceRefillSheetState();
}

class _ZeroBalanceRefillSheetState extends ConsumerState<ZeroBalanceRefillSheet> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    RewardedAdManager.instance.preload();
  }

  Future<void> _watchAd() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final success = await RewardedAdManager.instance.playRewardedSequence(
      context: context,
      requiredAds: 1,
      onProgress: (current, total) {},
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ref.read(userProvider.notifier).addVirtualFundsFromRewardedAd(
            rewardUsd: widget.rewardAmountUsd,
            adCount: 1,
          );

      final currency = ref.read(userProvider).profile.preferredCurrency;
      final formattedCredit = CurrencyFormatters.formatUsd(
        widget.rewardAmountUsd,
        currency,
        decimalDigits: 0,
      );

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Capital Refilled! +$formattedCredit added to your paper balance.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF00C087),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      final lastCode = RewardedAdManager.instance.lastLoadErrorCode;
      final String errorMsg;
      if (lastCode == 3) {
        errorMsg =
            'No ad inventory available right now. Google AdMob is currently warming up ad inventory for this app. Please try again shortly.';
      } else {
        errorMsg =
            'Ad was not completed or no ad available. Reward not credited.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.loss,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(userProvider).profile.preferredCurrency;
    final formattedReward = CurrencyFormatters.formatUsd(
      widget.rewardAmountUsd,
      currency,
      decimalDigits: 0,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14171F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF262D3D), width: 1.2),
          left: BorderSide(color: Color(0xFF262D3D), width: 1.2),
          right: BorderSide(color: Color(0xFF262D3D), width: 1.2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2D3548),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Row with Tag and Dismiss button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2330),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2E374D), width: 1),
                ),
                child: const Text(
                  'CAPITAL REFILL',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context, false),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      color: Color(0xFF71767B), size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            widget.message,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Reward Card (Clean, Matte, Professional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF191D28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262D3D), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222838),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D3548), width: 1),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch 1 Short Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Instant paper cash credited to your balance',
                        style: TextStyle(
                          color: Color(0xFF71767B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+$formattedReward',
                  style: const TextStyle(
                    color: Color(0xFF00C087),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary Watch Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _watchAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C087),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF00C087).withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Watch Video (+$formattedReward)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary: View All Packages
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context, false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestMoneyScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF262D3D), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View All Top-Up Packages',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
