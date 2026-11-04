import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../data/user_provider.dart';

class TopUpPackage {
  final String productId;
  final String? legacyProductId;
  final double usdAmount;
  final double inrAmount;
  final double virtualAmount;
  final String title;
  final String subtitle;
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
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor = AppColors.primary,
    required this.icon,
    this.isFeatured = false,
  });
}

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
  TopUpPackage _selectedPackage = packages[2]; // Default to Value Pack ($30)

  static const List<TopUpPackage> packages = [
    TopUpPackage(
      productId: 'starter_pack_50',
      legacyProductId: 'starter_pack_10',
      usdAmount: 10,
      inrAmount: 845,
      virtualAmount: 50000,
      title: 'Starter Pack',
      subtitle: 'Basic virtual capital refill',
      icon: Icons.bolt_rounded,
      badgeColor: AppColors.primary,
    ),
    TopUpPackage(
      productId: 'standard_pack_100',
      legacyProductId: 'standard_pack_20',
      usdAmount: 20,
      inrAmount: 1690,
      virtualAmount: 100000,
      title: 'Standard Pack',
      subtitle: 'Popular among active traders',
      badge: 'POPULAR',
      badgeColor: AppColors.primary,
      icon: Icons.star_rounded,
    ),
    TopUpPackage(
      productId: 'value_pack_200',
      legacyProductId: 'value_pack_30',
      usdAmount: 30,
      inrAmount: 2535,
      virtualAmount: 500000,
      title: 'Value Pack',
      subtitle: '+25% Extra Bonus Capital',
      badge: 'BEST VALUE 🔥',
      badgeColor: AppColors.profit,
      icon: Icons.local_fire_department_rounded,
      isFeatured: true,
    ),
    TopUpPackage(
      productId: 'pro_pack_500',
      legacyProductId: 'pro_pack_50',
      usdAmount: 50,
      inrAmount: 4225,
      virtualAmount: 1000000,
      title: 'Pro Trader Pack',
      subtitle: '+50% Bonus + Unlocks AI Signals Desk ⚡',
      badge: 'PRO TIER 🚀',
      badgeColor: AppColors.warning,
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
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
          virtualAmount: pkg.virtualAmount,
          inrAmount: pkg.inrAmount,
          paymentId: paymentId,
          paymentMethod: 'google_play',
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
    final formattedVirtual = AppCurrencyFormatter(ref.read(userProvider).profile.preferredCurrency).format(pkg.virtualAmount);
    final isProTier = pkg.usdAmount >= 50 || pkg.productId == 'pro_pack_500' || pkg.productId == 'pro_pack_50';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.profit, size: 56),
            SizedBox(height: 12),
            Text('Payment Successful!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Instantly Credited $formattedVirtual Virtual Capital to your balance via Google Play Billing.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
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
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline),
              ),
              child: SelectableText(
                'Transaction ID: $paymentId',
                style: const TextStyle(color: AppColors.subtle, fontSize: 12, fontFamily: 'monospace'),
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
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
              virtualAmount: pkg.virtualAmount,
              inrAmount: pkg.inrAmount,
              paymentId: testPaymentId,
              paymentMethod: 'google_play',
            );
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
                    onPressed: () {
                      final testPaymentId = 'TEST_IAP_${DateTime.now().millisecondsSinceEpoch}';
                      ref.read(userProvider.notifier).addVirtualFundsFromPayment(
                            virtualAmount: pkg.virtualAmount,
                            inrAmount: pkg.inrAmount,
                            paymentId: testPaymentId,
                            paymentMethod: 'google_play',
                          );
                      _showSuccessDialog(pkg, testPaymentId);
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Buy Virtual Funds',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
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
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatters.getInfo(userState.profile.preferredCurrency).flag,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        userState.profile.preferredCurrency,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.subtle),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Balance Card
              _buildHeaderBalanceCard(userState, formatter),

              const SizedBox(height: 20),

              // Google Play Transparency Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shop_two_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Play Secure Purchase',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Payments are processed directly via Google Play Billing to instantly top-up virtual paper-trading capital in your Stock Arena account.',
                            style: TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Select Capital Package',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // Package List Tiers
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: packages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pkg = packages[index];
                  final isSelected = _selectedPackage.productId == pkg.productId;
                  final storeProduct = _getProductDetails(pkg);

                  return _PackageSelectableCard(
                    package: pkg,
                    storeProduct: storeProduct,
                    formatter: formatter,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedPackage = pkg);
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Trust Badges
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSecurityChip(Icons.shield_outlined, 'Google Play Safe'),
                    _buildSecurityChip(Icons.bolt_rounded, 'Instant Auto-Credit'),
                    _buildSecurityChip(Icons.verified_outlined, 'Play Billing Verified'),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              const Divider(color: AppColors.outline, thickness: 1),
              const SizedBox(height: 16),

              // Top-Up History
              const Text(
                'Top-Up History',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (user == null)
                const SizedBox.shrink()
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('money_requests')
                      .where('requesterId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading history', style: TextStyle(color: AppColors.loss)));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.history_toggle_off, color: AppColors.subtle, size: 36),
                            SizedBox(height: 8),
                            Text('No previous top-ups yet.', style: TextStyle(color: AppColors.subtle, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                        final inrAmount = (data['inrAmount'] as num?)?.toDouble();
                        final paymentMethod = data['paymentMethod'] as String? ?? 'google_play';
                        final status = data['status'] as String? ?? 'approved';
                        final dateStr = data['createdAt'] as String?;
                        DateTime? dt = dateStr != null ? DateTime.tryParse(dateStr) : null;
                        final formattedDate = dt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(dt) : 'Recently';

                        final providerLabel = paymentMethod == 'razorpay' ? 'Razorpay' : 'Google Play';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.profit.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_downward_rounded, color: AppColors.profit, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+${formatter.format(amount)} Virtual Cash',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      inrAmount != null ? 'Paid Real ${CurrencyFormatters.format(inrAmount, userState.profile.preferredCurrency)} via $providerLabel • $formattedDate' : formattedDate,
                                      style: const TextStyle(color: AppColors.subtle, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.profit.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(color: AppColors.profit, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),

      // Sticky Bottom Checkout Action Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ${_PackageSelectableCard.formatPackagePrice(_selectedPackage, _getProductDetails(_selectedPackage), userState.profile.preferredCurrency)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${formatter.format(_selectedPackage.virtualAmount)} Virtual Capital',
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _startPayment,
                  icon: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.shop_two_rounded, size: 18, color: Colors.black),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Pay with Play',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBalanceCard(UserState userState, AppCurrencyFormatter formatter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Current Virtual Balance', style: TextStyle(color: AppColors.subtle, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.profit.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('VERIFIED', style: TextStyle(color: AppColors.profit, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatter.format(userState.profile.virtualBalance),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.subtle, size: 14),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PackageSelectableCard extends StatelessWidget {
  final TopUpPackage package;
  final ProductDetails? storeProduct;
  final AppCurrencyFormatter formatter;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageSelectableCard({
    required this.package,
    this.storeProduct,
    required this.formatter,
    required this.isSelected,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Custom Radio Checkmark
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.muted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 12)
                    : null,
              ),
              const SizedBox(width: 10),

              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(package.icon, color: isSelected ? AppColors.primary : AppColors.subtle, size: 20),
              ),
              const SizedBox(width: 10),

              // Main Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          package.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (package.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: package.badgeColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              package.badge!,
                              style: TextStyle(color: package.badgeColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '+${formatter.format(package.virtualAmount)} Capital',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      package.subtitle,
                      style: const TextStyle(color: AppColors.subtle, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Price Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outline,
                  ),
                ),
                child: Text(
                  displayPrice,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
