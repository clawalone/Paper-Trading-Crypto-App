import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../core/rewarded_ad_manager.dart';
import '../../data/user_provider.dart';

class TopUpPackage {
  final String productId;
  final String? legacyProductId;
  final double usdAmount;
  final double inrAmount;
  final double virtualAmount;
  final double bonusPercent;
  final String title;
  final String bonusNote;
  final String? perkNote;
  final String? badge;
  final Color badgeColor;
  final IconData icon;
  final bool isFeatured;

  const TopUpPackage({
    required this.productId,
    this.legacyProductId,
    required this.usdAmount,
    required this.inrAmount,
    required this.virtualAmount,
    this.bonusPercent = 0.0,
    required this.title,
    required this.bonusNote,
    this.perkNote,
    this.badge,
    this.badgeColor = const Color(0xFF1A73E8),
    required this.icon,
    this.isFeatured = false,
  });

  /// Extra bonus capital calculated on top of base virtual capital
  double get bonusAmount => virtualAmount * bonusPercent;

  /// Total virtual capital credited to user (base + bonus)
  double get totalVirtualAmount => virtualAmount + bonusAmount;
}

const Color _googlePlayBlue = Color(0xFF0066F5);
const Color _brandBlue = Color(0xFF1A73E8);
const Color _accentGreen = Color(0xFF16A34A);

class RequestMoneyScreen extends ConsumerStatefulWidget {
  const RequestMoneyScreen({super.key});

  @override
  ConsumerState<RequestMoneyScreen> createState() => _RequestMoneyScreenState();
}

class _RequestMoneyScreenState extends ConsumerState<RequestMoneyScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  Map<String, ProductDetails> _products = {};
  bool _isAvailable = false;
  bool _isProcessing = false;
  bool _isPlayingAd = false;
  bool _showAllHistory = false;
  int _selectedSection = 0; // 0: Capital Packages, 1: Free Video Refill
  int _currentAdStep = 0;
  int _totalAdSteps = 0;
  String _adStatusMessage = '';
  TopUpPackage _selectedPackage = packages[2]; // Default to Advanced ($30) as in design

  // Original packages with verified pricing and virtual capital preserved
  static const List<TopUpPackage> packages = [
    TopUpPackage(
      productId: 'starter_pack_50',
      legacyProductId: 'starter_pack_10',
      usdAmount: 10,
      inrAmount: 845,
      virtualAmount: 50000,
      bonusPercent: 0.0,
      title: 'Starter',
      bonusNote: 'Perfect for your first trades',
      icon: Icons.bolt_rounded,
    ),
    TopUpPackage(
      productId: 'standard_pack_100',
      legacyProductId: 'standard_pack_20',
      usdAmount: 20,
      inrAmount: 1690,
      virtualAmount: 100000,
      bonusPercent: 0.05,
      title: 'Trader',
      bonusNote: '+5% bonus capital',
      icon: Icons.star_rounded,
    ),
    TopUpPackage(
      productId: 'value_pack_200',
      legacyProductId: 'value_pack_30',
      usdAmount: 30,
      inrAmount: 2535,
      virtualAmount: 500000,
      bonusPercent: 0.25,
      title: 'Advanced',
      bonusNote: '+25% bonus capital',
      badge: 'Most popular',
      icon: Icons.local_fire_department_rounded,
      isFeatured: true,
    ),
    TopUpPackage(
      productId: 'pro_pack_500',
      legacyProductId: 'pro_pack_50',
      usdAmount: 50,
      inrAmount: 4225,
      virtualAmount: 1000000,
      bonusPercent: 0.50,
      title: 'Pro Trader',
      bonusNote: '+50% bonus capital',
      perkNote: 'Unlocks AI Signals Desk',
      icon: Icons.workspace_premium_rounded,
      badgeColor: AppColors.warning,
    ),
  ];

  @override
  void initState() {
    super.initState();
    RewardedAdManager.instance.preload();
    final purchaseStream = _iap.purchaseStream;
    _subscription = purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.loss, content: Text('Billing Error: $error')),
          );
        }
      },
    );
    _initIap();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  ProductDetails? _getProductDetails(TopUpPackage pkg) {
    return _products[pkg.productId] ??
        _products[pkg.productId.replaceAll('_', '-')] ??
        (pkg.legacyProductId != null
            ? (_products[pkg.legacyProductId] ?? _products[pkg.legacyProductId!.replaceAll('_', '-')])
            : null);
  }

  Future<void> _initIap() async {
    final available = await _iap.isAvailable();
    if (!mounted) return;
    setState(() => _isAvailable = available);

    if (available) {
      final ids = <String>{
        for (var p in packages) ...[
          p.productId,
          p.productId.replaceAll('_', '-'),
          if (p.legacyProductId != null) ...[
            p.legacyProductId!,
            p.legacyProductId!.replaceAll('_', '-'),
          ],
        ],
      };
      final response = await _iap.queryProductDetails(ids);
      if (!mounted) return;
      final map = <String, ProductDetails>{};
      for (var pd in response.productDetails) {
        map[pd.id] = pd;
      }
      setState(() => _products = map);
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isProcessing = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (mounted) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.loss,
                content: Text('Purchase Failed: ${purchaseDetails.error?.message ?? "Cancelled"}'),
              ),
            );
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _processSuccessfulPurchase(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _processSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    final pkg = packages.firstWhere(
      (p) => p.productId == purchaseDetails.productID || p.legacyProductId == purchaseDetails.productID,
      orElse: () => _selectedPackage,
    );
    final paymentId = purchaseDetails.purchaseID ?? 'IAP_${DateTime.now().millisecondsSinceEpoch}';

    ref.read(userProvider.notifier).addVirtualFundsFromPayment(
          virtualAmount: pkg.totalVirtualAmount,
          inrAmount: pkg.inrAmount,
          paymentId: paymentId,
          paymentMethod: 'google_play',
          bonusVirtualAmount: pkg.bonusAmount > 0 ? pkg.bonusAmount : null,
        );

    if (pkg.usdAmount >= 50 || pkg.productId == 'pro_pack_500' || pkg.productId == 'pro_pack_50') {
      await ref.read(userProvider.notifier).unlockAiSignals(
            paymentId: paymentId,
            inrAmount: pkg.inrAmount.toDouble(),
          );
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showSuccessDialog(pkg, paymentId);
  }

  void _showSuccessDialog(TopUpPackage pkg, String paymentId) {
    final theme = AppColors.of(context);
    final userCurrency = ref.read(userProvider).profile.preferredCurrency;
    final formattedTotal = AppCurrencyFormatter(userCurrency).format(pkg.totalVirtualAmount);
    final formattedBonus = AppCurrencyFormatter(userCurrency).format(pkg.bonusAmount);
    final isProTier = pkg.usdAmount >= 50 || pkg.productId == 'pro_pack_500' || pkg.productId == 'pro_pack_50';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.outline),
        ),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: _accentGreen, size: 56),
            SizedBox(height: 12),
            Text('Payment Successful!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Instantly Credited $formattedTotal Virtual Capital to your balance via Google Play Billing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            if (pkg.bonusPercent > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: _accentGreen, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Includes +${(pkg.bonusPercent * 100).toInt()}% Bonus (+$formattedBonus)',
                      style: const TextStyle(
                        color: _accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isProTier) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB800), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bonus: AI Signals & Safe Leverage Desk unlocked for lifetime access!',
                        style: TextStyle(color: Color(0xFFFFB800), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.outline),
              ),
              child: SelectableText(
                'Transaction ID: $paymentId',
                style: TextStyle(color: theme.subtle, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _googlePlayBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Start Trading Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _startPayment() async {
    final pkg = _selectedPackage;
    setState(() => _isProcessing = true);

    if (!_isAvailable) {
      if (kDebugMode) {
        // Fallback ONLY for local debug mode during development
        final testPaymentId = 'SIM_IAP_${DateTime.now().millisecondsSinceEpoch}';
        ref.read(userProvider.notifier).addVirtualFundsFromPayment(
              virtualAmount: pkg.totalVirtualAmount,
              inrAmount: pkg.inrAmount,
              paymentId: testPaymentId,
              paymentMethod: 'google_play',
              bonusVirtualAmount: pkg.bonusAmount > 0 ? pkg.bonusAmount : null,
            );
        if (pkg.usdAmount >= 50 || pkg.productId == 'pro_pack_500' || pkg.productId == 'pro_pack_50') {
          await ref.read(userProvider.notifier).unlockAiSignals(
                paymentId: testPaymentId,
                inrAmount: pkg.inrAmount.toDouble(),
              );
        }
        if (mounted) {
          setState(() => _isProcessing = false);
          _showSuccessDialog(pkg, testPaymentId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DEBUG ONLY: Simulated purchase for local dev mode.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.loss,
              content: Text('Google Play Store billing is currently unavailable on this device.'),
            ),
          );
        }
        return;
      }
    }

    final productDetails = _getProductDetails(pkg);
    if (productDetails != null) {
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      try {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.loss,
              content: Text('Error launching Google Play Billing: $e'),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.loss,
            content: Text(
              'Package "${pkg.title}" is currently unavailable for purchase. Please try again later.',
            ),
            duration: const Duration(seconds: 4),
            action: kDebugMode
                ? SnackBarAction(
                    label: 'DEV Simulate',
                    onPressed: () async {
                      final testPaymentId = 'TEST_IAP_${DateTime.now().millisecondsSinceEpoch}';
                      ref.read(userProvider.notifier).addVirtualFundsFromPayment(
                            virtualAmount: pkg.totalVirtualAmount,
                            inrAmount: pkg.inrAmount,
                            paymentId: testPaymentId,
                            paymentMethod: 'google_play',
                            bonusVirtualAmount: pkg.bonusAmount > 0 ? pkg.bonusAmount : null,
                          );
                      if (pkg.usdAmount >= 50 || pkg.productId == 'pro_pack_500' || pkg.productId == 'pro_pack_50') {
                        await ref.read(userProvider.notifier).unlockAiSignals(
                              paymentId: testPaymentId,
                              inrAmount: pkg.inrAmount.toDouble(),
                            );
                      }
                      _showSuccessDialog(pkg, testPaymentId);
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _watchAdBundle({required int adCount, required double rewardAmount}) async {
    if (_isPlayingAd) return;

    setState(() {
      _isPlayingAd = true;
      _currentAdStep = 1;
      _totalAdSteps = adCount;
      _adStatusMessage = 'Loading video ad 1 of $adCount...';
    });

    final success = await RewardedAdManager.instance.playRewardedSequence(
      context: context,
      requiredAds: adCount,
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _currentAdStep = current;
            _totalAdSteps = total;
            _adStatusMessage = 'Playing ad $current of $total...';
          });
        }
      },
    );

    if (!mounted) return;
    setState(() => _isPlayingAd = false);

    if (success) {
      ref.read(userProvider.notifier).addVirtualFundsFromRewardedAd(
            rewardUsd: rewardAmount,
            adCount: adCount,
          );
      _showAdSuccessDialog(adCount, rewardAmount);
    } else {
      final lastCode = RewardedAdManager.instance.lastLoadErrorCode;
      final String errorMsg;
      if (lastCode == 3) {
        errorMsg = 'No ad available right now. Google AdMob is currently warming up ad inventory for this app. Please try again shortly.';
      } else {
        errorMsg = 'Ad was not completed or no ad available. Reward not credited.';
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

  void _showAdSuccessDialog(int adCount, double amountUsd) {
    final theme = AppColors.of(context);
    final currency = ref.read(userProvider).profile.preferredCurrency;
    final formattedVirtual = CurrencyFormatters.formatUsd(amountUsd, currency, decimalDigits: 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.outline),
        ),
        title: Column(
          children: [
            const Icon(Icons.stars_rounded, color: _accentGreen, size: 56),
            const SizedBox(height: 12),
            Text('Reward Claimed!', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Successfully completed $adCount ${adCount == 1 ? "ad" : "ads"} and credited $formattedVirtual to your balance!',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentGreen.withValues(alpha: 0.3)),
              ),
              child: Text(
                '+$formattedVirtual',
                style: const TextStyle(
                  color: _accentGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _googlePlayBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHistoryDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('h:mm a').format(dt);

    if (date == today) {
      return 'Today, $timeStr';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else if (now.year == dt.year) {
      return '${DateFormat('MMM d').format(dt)}, $timeStr';
    } else {
      return '${DateFormat('MMM d, yyyy').format(dt)}, $timeStr';
    }
  }

  String _getPackageTitleForAmount(double amount) {
    if (amount >= 950000) return 'Pro Trader package';
    if (amount >= 450000) return 'Advanced package';
    if (amount >= 90000) return 'Trader package';
    if (amount >= 45000) return 'Starter package';
    return 'Top-up package';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final currencyInfo = CurrencyFormatters.getInfo(userState.profile.preferredCurrency);

    final selectedPriceString = _PackageSelectableCard.formatPackagePrice(
      _selectedPackage,
      _getProductDetails(_selectedPackage),
      userState.profile.preferredCurrency,
    );

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Top up',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: () {
                  CurrencyPicker.show(
                    context,
                    currentCode: userState.profile.preferredCurrency,
                    onSelected: (code) {
                      ref.read(userProvider.notifier).updateProfileSettings(currency: code);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.outline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${userState.profile.preferredCurrency} ${currencyInfo.symbol}',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: theme.subtle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Two-Button Section Switcher at Top
              _buildSectionSwitcher(theme, isDark),

              const SizedBox(height: 14),

              // 2. Available Paper Cash Hero Card
              _buildHeaderBalanceCard(theme, isDark, userState, formatter),

              const SizedBox(height: 18),

              if (_selectedSection == 0) ...[
                // 3A. Capital Packages Section (Primary In-App Store Offerings)
                Text(
                  'Capital packages',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select one to add to your paper account.',
                  style: TextStyle(
                    color: theme.subtle,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCapitalPackagesGroupedCard(theme, isDark, formatter),

                const SizedBox(height: 16),

                // Google Play Secure Purchase Banner
                _buildGooglePlayBanner(theme, isDark),

                const SizedBox(height: 18),

                // Trust Badges Row
                _buildTrustBadges(theme),
              ] else ...[
                // 3B. Free Video Rewards Section
                Text(
                  'Free video rewards',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Watch short ads for an instant capital refill. No purchase needed.',
                  style: TextStyle(
                    color: theme.subtle,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFreeVideoRewardsCard(theme, isDark, userState),

                const SizedBox(height: 16),

                // Google Play Secure Info
                _buildGooglePlayBanner(theme, isDark),
              ],

              const SizedBox(height: 24),

              // 4. Top-Up History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top-up history',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => _showAllHistory = !_showAllHistory);
                      },
                      child: Text(
                        _showAllHistory ? 'Show less' : 'See all',
                        style: const TextStyle(
                          color: _brandBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTopUpHistoryCard(theme, isDark, user, formatter, userState),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Sticky Bottom Checkout Action Bar (Shown exclusively when Capital Packages tab is active)
      bottomNavigationBar: _selectedSection == 0
          ? SafeArea(
              child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.outline, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 12, color: theme.subtle),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Virtual simulation funds only. Zero real-world cash value. Non-refundable.',
                        style: TextStyle(color: theme.subtle, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      'Total',
                      style: TextStyle(color: theme.subtle, fontSize: 11),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      selectedPriceString,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _selectedPackage.bonusPercent > 0
                          ? '${_selectedPackage.title} · ${formatter.format(_selectedPackage.totalVirtualAmount)} capital (+${(_selectedPackage.bonusPercent * 100).toInt()}% bonus)'
                          : '${_selectedPackage.title} · ${formatter.format(_selectedPackage.virtualAmount)} capital',
                      style: TextStyle(color: theme.subtle, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _googlePlayBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else ...[
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'Pay with Play',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ) : null,
);
  }

  // ── TOP TWO-BUTTON SECTION SWITCHER ────────────────────────────────────────
  Widget _buildSectionSwitcher(AppColorTheme theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildSectionTabItem(
            index: 0,
            title: 'Capital Packages',
            icon: Icons.bolt_rounded,
          ),
          _buildSectionTabItem(
            index: 1,
            title: 'Free Video Refill',
            icon: Icons.smart_display_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabItem({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedSection == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedSection = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D9BF0) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.subtle,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.subtle,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Available Paper Cash Hero Card
  Widget _buildHeaderBalanceCard(
    AppColorTheme theme,
    bool isDark,
    UserState userState,
    AppCurrencyFormatter formatter,
  ) {
    final afterBalance = userState.profile.virtualBalance + _selectedPackage.totalVirtualAmount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available paper cash',
                style: TextStyle(
                  color: theme.subtle,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Live',
                    style: TextStyle(
                      color: _accentGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatter.format(userState.profile.virtualBalance),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Virtual funds for paper trading. No real money is traded.',
            style: TextStyle(
              color: theme.subtle,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: theme.outline, thickness: 1, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'After selected top-up',
                    style: TextStyle(
                      color: theme.subtle,
                      fontSize: 12,
                    ),
                  ),
                  if (_selectedPackage.bonusPercent > 0)
                    Text(
                      'Includes +${formatter.format(_selectedPackage.bonusAmount)} (${(_selectedPackage.bonusPercent * 100).toInt()}% bonus)',
                      style: const TextStyle(
                        color: _accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              Text(
                formatter.format(afterBalance),
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Free Video Rewards Card
  Widget _buildFreeVideoRewardsCard(AppColorTheme theme, bool isDark, UserState userState) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_isPlayingAd) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: isDark ? const Color(0xFF0F2542) : const Color(0xFFEFF6FF),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _brandBlue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _adStatusMessage.isNotEmpty
                              ? _adStatusMessage
                              : 'Playing Ad $_currentAdStep of $_totalAdSteps... Please do not close.',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _totalAdSteps > 0 ? _currentAdStep / _totalAdSteps : null,
                      backgroundColor: theme.outline,
                      valueColor: const AlwaysStoppedAnimation<Color>(_brandBlue),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.outline, thickness: 1, height: 1),
          ],
          _buildVideoRewardRow(
            theme: theme,
            isDark: isDark,
            title: 'Watch 1 ad',
            subtitle: 'Free, instant credit',
            rewardText: '+${CurrencyFormatters.formatUsd(10, userState.profile.preferredCurrency, decimalDigits: 0)}',
            adCount: 1,
            rewardAmount: 10.0,
          ),
          Divider(color: theme.outline, thickness: 1, height: 1),
          _buildVideoRewardRow(
            theme: theme,
            isDark: isDark,
            title: 'Watch 2 ads',
            subtitle: 'Free, instant credit',
            rewardText: '+${CurrencyFormatters.formatUsd(25, userState.profile.preferredCurrency, decimalDigits: 0)}',
            adCount: 2,
            rewardAmount: 25.0,
          ),
          Divider(color: theme.outline, thickness: 1, height: 1),
          _buildVideoRewardRow(
            theme: theme,
            isDark: isDark,
            title: 'Watch 3 ads',
            subtitle: 'Best value, free',
            rewardText: '+${CurrencyFormatters.formatUsd(40, userState.profile.preferredCurrency, decimalDigits: 0)}',
            adCount: 3,
            rewardAmount: 40.0,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoRewardRow({
    required AppColorTheme theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required String rewardText,
    required int adCount,
    required double rewardAmount,
  }) {
    final isBusy = _isPlayingAd;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Circle play icon container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2542) : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1D9BF0), size: 22),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Green reward text
          Text(
            rewardText,
            style: const TextStyle(
              color: _accentGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),

          // Outlined Watch button
          OutlinedButton(
            onPressed: isBusy ? null : () => _watchAdBundle(adCount: adCount, rewardAmount: rewardAmount),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(68, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Watch',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Google Play Transparency Banner
  Widget _buildGooglePlayBanner(AppColorTheme theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E36) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: _brandBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure purchase with Google Play',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Payments are processed by Play Billing. Your card details never reach us.',
                  style: TextStyle(
                    color: theme.subtle,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Grouped Capital Packages Card
  Widget _buildCapitalPackagesGroupedCard(
    AppColorTheme theme,
    bool isDark,
    AppCurrencyFormatter formatter,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < packages.length; i++) ...[
            if (i > 0) Divider(color: theme.outline, thickness: 1, height: 1),
            _PackageSelectableCard(
              package: packages[i],
              storeProduct: _getProductDetails(packages[i]),
              formatter: formatter,
              isSelected: _selectedPackage.productId == packages[i].productId,
              theme: theme,
              isDark: isDark,
              onTap: () {
                setState(() => _selectedPackage = packages[i]);
              },
            ),
          ],
        ],
      ),
    );
  }

  // 5. Trust Badges
  Widget _buildTrustBadges(AppColorTheme theme) {
    return Row(
      children: [
        Expanded(
          child: _buildTrustBadgeItem(
            icon: Icons.verified_outlined,
            title: 'Verified purchase',
            subtitle: 'Play Billing',
            theme: theme,
          ),
        ),
        Expanded(
          child: _buildTrustBadgeItem(
            icon: Icons.bolt_outlined,
            title: 'Instant credit',
            subtitle: 'Added right away',
            theme: theme,
          ),
        ),
        Expanded(
          child: _buildTrustBadgeItem(
            icon: Icons.lock_outline_rounded,
            title: 'Encrypted checkout',
            subtitle: 'Protected payments',
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadgeItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppColorTheme theme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.subtle, size: 20),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtle,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // 6. Top-Up History Card
  Widget _buildTopUpHistoryCard(
    AppColorTheme theme,
    bool isDark,
    User? user,
    AppCurrencyFormatter formatter,
    UserState userState,
  ) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('money_requests')
          .where('requesterId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.outline),
            ),
            child: const Center(
              child: Text('Error loading history', style: TextStyle(color: AppColors.loss, fontSize: 13)),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.outline),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.outline),
            ),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off, color: theme.subtle, size: 36),
                const SizedBox(height: 8),
                Text('No previous top-ups yet.', style: TextStyle(color: theme.subtle, fontSize: 13)),
              ],
            ),
          );
        }

        final displayDocs = _showAllHistory ? docs : docs.take(5).toList();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.outline, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int index = 0; index < displayDocs.length; index++) ...[
                if (index > 0) Divider(color: theme.outline, thickness: 1, height: 1),
                _buildHistoryRow(displayDocs[index], theme, isDark, formatter),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryRow(
    DocumentSnapshot doc,
    AppColorTheme theme,
    bool isDark,
    AppCurrencyFormatter formatter,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = data['paymentMethod'] as String? ?? 'google_play';
    final status = data['status'] as String? ?? 'approved';
    final adCount = (data['adCount'] as num?)?.toInt();
    final isAd = paymentMethod == 'rewarded_ad' || (amount <= 50 && data['inrAmount'] == null);
    final dateStr = data['createdAt'] as String?;
    DateTime? dt = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final formattedDate = _formatHistoryDate(dt);

    final String itemTitle;
    if (isAd) {
      final count = adCount ?? 1;
      itemTitle = '$count video ${count == 1 ? "ad" : "ads"}';
    } else {
      itemTitle = _getPackageTitleForAmount(amount);
    }

    final Color statusColor;
    final String statusLabel;
    if (status == 'approved' || status == 'completed') {
      statusColor = _accentGreen;
      statusLabel = isAd ? 'Credited' : 'Completed';
    } else if (status == 'pending') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Pending';
    } else {
      statusColor = AppColors.loss;
      statusLabel = 'Failed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Icon container (card or play)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2329) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAd ? Icons.play_arrow_rounded : Icons.credit_card_outlined,
              color: theme.subtle,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemTitle,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: theme.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Amount & Status with colored bullet
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${formatter.format(amount)}',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageSelectableCard extends StatelessWidget {
  final TopUpPackage package;
  final ProductDetails? storeProduct;
  final AppCurrencyFormatter formatter;
  final bool isSelected;
  final AppColorTheme theme;
  final bool isDark;
  final VoidCallback onTap;

  const _PackageSelectableCard({
    required this.package,
    this.storeProduct,
    required this.formatter,
    required this.isSelected,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  static String formatPackagePrice(TopUpPackage package, ProductDetails? storeProduct, String? userCurrency) {
    final targetCurrency = userCurrency ?? 'USD';
    if (storeProduct != null &&
        storeProduct.currencyCode.toUpperCase() == targetCurrency.toUpperCase() &&
        (storeProduct.rawPrice - package.usdAmount).abs() < 1.0) {
      return storeProduct.price;
    }
    return CurrencyFormatters.formatUsd(package.usdAmount, targetCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final displayPrice = formatPackagePrice(package, storeProduct, formatter.currencyCode);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? (isDark ? const Color(0xFF132238) : const Color(0xFFF0F7FF))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custom Radio Circle matching design
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A73E8)
                      : (isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8)),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Package Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        package.title,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (package.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F2542) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBFDBFE),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            package.badge!,
                            style: const TextStyle(
                              color: Color(0xFF1A73E8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        '${formatter.format(package.virtualAmount)} capital',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (package.bonusPercent > 0)
                        Text(
                          '→ ${formatter.format(package.totalVirtualAmount)} total',
                          style: const TextStyle(
                            color: _accentGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    package.bonusPercent > 0
                        ? '${package.bonusNote} (+${formatter.format(package.bonusAmount)})'
                        : package.bonusNote,
                    style: TextStyle(
                      color: package.bonusPercent > 0 ? _accentGreen : theme.subtle,
                      fontSize: 12,
                      fontWeight: package.bonusPercent > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (package.perkNote != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 4),
                        Text(
                          package.perkNote!,
                          style: const TextStyle(
                            color: Color(0xFF1A73E8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Price Text on Right
            Text(
              displayPrice,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
