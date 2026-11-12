import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/app_review_manager.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../../core/rewarded_ad_manager.dart';
import '../profile/widgets/zero_balance_refill_sheet.dart';

class SpotTradeSheet extends ConsumerStatefulWidget {
  final Stock stock;
  final OrderSide initialSide;
  final double? suggestedLimitPrice;

  const SpotTradeSheet({
    super.key,
    required this.stock,
    required this.initialSide,
    this.suggestedLimitPrice,
  });

  @override
  ConsumerState<SpotTradeSheet> createState() => _SpotTradeSheetState();
}

class _SpotTradeSheetState extends ConsumerState<SpotTradeSheet> {
  late OrderSide _side;
  String _orderType = 'Market'; // 'Market' or 'Limit'
  bool _isCryptoInput = true;
  final _inputController = TextEditingController();
  final _targetPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    final initPrice = widget.suggestedLimitPrice ?? widget.stock.currentPrice;
    _targetPriceController.text = initPrice.toStringAsFixed(2);
    if (widget.suggestedLimitPrice != null) {
      _orderType = 'Limit';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userState = ref.read(userProvider);
      if (userState.profile.virtualBalance <= 0) {
        RewardedAdManager.instance.preload();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _targetPriceController.dispose();
    super.dispose();
  }

  Stock get _liveStock {
    return ref.watch(marketProvider).firstWhere(
      (s) => s.symbol == widget.stock.symbol,
      orElse: () => widget.stock,
    );
  }

  double get _inputVal => double.tryParse(_inputController.text) ?? 0.0;
  double get _targetPrice {
    final raw = _orderType == 'Limit'
        ? (double.tryParse(_targetPriceController.text) ?? _liveStock.currentPrice)
        : _liveStock.currentPrice;
    return raw.clamp(0.00000001, double.infinity);
  }

  int get _cryptoQty => _isCryptoInput
      ? _inputVal.floor()
      : (_inputVal / _targetPrice).floor();

  double get _fiatAmount =>
      _isCryptoInput ? (_inputVal * _targetPrice) : _inputVal;

  int _getOwnedQty(UserState state) {
    return state.availableHoldingQty(widget.stock.symbol);
  }

  void _adjustTargetPrice(double pct) {
    final current = double.tryParse(_targetPriceController.text) ?? _liveStock.currentPrice;
    final updated = current * (1 + pct);
    _targetPriceController.text = updated.toStringAsFixed(2);
    setState(() {});
  }

  void _setPercentage(double pct, UserState state) {
    if (_side == OrderSide.buy) {
      final maxFiat = state.profile.virtualBalance;
      final targetFiat = maxFiat * pct;
      if (_isCryptoInput) {
        _inputController.text = (targetFiat / _targetPrice).floor().toString();
      } else {
        _inputController.text = targetFiat.toStringAsFixed(2);
      }
    } else {
      final maxQty = _getOwnedQty(state);
      final targetQty = (maxQty * pct).floor();
      if (_isCryptoInput) {
        _inputController.text = targetQty.toString();
      } else {
        _inputController.text = (targetQty * _targetPrice).toStringAsFixed(2);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final isMarketOnline = ref.watch(marketOnlineProvider);
    final liveStock = _liveStock;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);

    final isBuy = _side == OrderSide.buy;
    final isLimit = _orderType == 'Limit';
    final ownedQty = _getOwnedQty(userState);
    final execPrice = _targetPrice;
    final totalCost = _cryptoQty * execPrice;
    final fee = totalCost * 0.001;
    final totalWithFee = isBuy ? totalCost + fee : totalCost - fee;

    final isLimitPlausible = !isLimit || (
      _targetPrice >= liveStock.currentPrice * 0.70 && _targetPrice <= liveStock.currentPrice * 1.30
    );

    final canExecute = isMarketOnline &&
        liveStock.isLive &&
        liveStock.currentPrice > 0 &&
        _cryptoQty > 0 &&
        execPrice > 0 &&
        isLimitPlausible &&
        (isBuy ? totalWithFee <= userState.profile.virtualBalance : _cryptoQty <= ownedQty);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Side Selector (Buy / Sell)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.buy),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isBuy ? AppColors.profit : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Buy Spot',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isBuy ? Colors.white : AppColors.subtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.sell),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isBuy ? AppColors.loss : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sell Spot',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !isBuy ? Colors.white : AppColors.subtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Order Type Selector (Market vs Limit)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _orderType = 'Market'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isLimit ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: !isLimit ? AppColors.primary : AppColors.outline),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Market Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: !isLimit ? AppColors.primary : AppColors.subtle,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _orderType = 'Limit'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isLimit ? AppColors.warning.withValues(alpha: 0.15) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isLimit ? AppColors.warning : AppColors.outline),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Limit Order',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isLimit ? AppColors.warning : AppColors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Limit Price Input
            if (isLimit) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Target Limit Price', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Market: ${formatter.format(widget.stock.currentPrice)}', style: TextStyle(color: AppColors.subtle, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixText: '$currSym ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.warning, width: 1.5)),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPriceAdjBtn('-5%', -0.05),
                  _buildPriceAdjBtn('-1%', -0.01),
                  _buildPriceAdjBtn('+1%', 0.01),
                  _buildPriceAdjBtn('+5%', 0.05),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Crypto / Fiat Switcher & Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isBuy ? 'Available: ${formatter.format(userState.profile.virtualBalance)}' : 'Available: $ownedQty ${widget.stock.symbol}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _isCryptoInput = !_isCryptoInput;
                    _inputController.clear();
                  }),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        _isCryptoInput ? 'Input in $currSym' : 'Input in ${widget.stock.symbol}',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: _isCryptoInput ? 'Amount (${widget.stock.symbol})' : 'Amount ($currSym)',
                labelStyle: TextStyle(fontSize: 16, color: AppColors.subtle),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outline)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outline)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isBuy ? AppColors.profit : AppColors.loss, width: 1.5)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                suffixText: _isCryptoInput ? widget.stock.symbol : currSym,
                suffixStyle: TextStyle(color: AppColors.subtle, fontWeight: FontWeight.bold),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_inputVal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4),
                child: Text(
                  _isCryptoInput ? '≈ ${formatter.format(_fiatAmount)}' : '≈ $_cryptoQty ${widget.stock.symbol}',
                  style: TextStyle(color: AppColors.subtle),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPctBtn('25%', 0.25, userState),
                _buildPctBtn('50%', 0.50, userState),
                _buildPctBtn('75%', 0.75, userState),
                _buildPctBtn('MAX', 1.0, userState),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Value', style: TextStyle(color: AppColors.textSecondary)),
                      Text(formatter.format(totalCost), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Est. Trading Fee (0.1%)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(formatter.format(fee), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  Divider(color: AppColors.outline, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isBuy ? 'Total Payable' : 'Total Receivable', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text(
                        formatter.format(totalWithFee),
                        style: TextStyle(fontWeight: FontWeight.w900, color: isBuy ? AppColors.profit : AppColors.textPrimary, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_inputVal > 0 && _cryptoQty < 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Minimum order is 1 ${widget.stock.symbol} (${formatter.format(execPrice)})',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else if (_inputVal > 0 && isBuy && totalWithFee > userState.profile.virtualBalance)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.loss, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Insufficient available balance', style: TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    InkWell(
                      onTap: () => ZeroBalanceRefillSheet.show(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2330),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2E374D), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Color(0xFF00C087), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Free Refill',
                              style: TextStyle(color: Color(0xFF00C087), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_inputVal > 0 && !isBuy && _cryptoQty > ownedQty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.loss, size: 16),
                    const SizedBox(width: 8),
                    Text('Insufficient ${widget.stock.symbol} balance', style: const TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (isLimit && !isLimitPlausible) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.loss.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.loss, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBuy
                            ? 'Limit price cannot be lower than 10% of market price.'
                            : 'Limit price cannot exceed 10x current market price.',
                        style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isMarketOnline || !liveStock.isLive || liveStock.currentPrice <= 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6465D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF6465D).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem_rounded, color: Color(0xFFF6465D), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !isMarketOnline
                            ? 'Connecting to live market. Orders are locked until price is verified.'
                            : 'Syncing real-time exchange price for ${liveStock.symbol}...',
                        style: const TextStyle(color: Color(0xFFF6465D), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canExecute
                  ? () {
                      if (isLimit) {
                        final success = ref.read(userProvider.notifier).placeSpotLimitOrder(
                              stock: liveStock,
                              side: _side,
                              quantity: _cryptoQty,
                              targetPrice: _targetPrice,
                            );
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Spot Limit ${isBuy ? "Buy" : "Sell"} order placed at ${formatter.format(_targetPrice)}!'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      } else {
                        final success = ref.read(userProvider.notifier).tradeStock(liveStock, _side, _cryptoQty);
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Spot order executed successfully!'), backgroundColor: AppColors.profit),
                          );
                          if (!isBuy) {
                            AppReviewManager.checkAndPromptReview(
                              context,
                              ref,
                              triggerReason: 'Spot Crypto Trade',
                            );
                          }
                        }
                      }
                    }
                  : (isBuy && totalWithFee > userState.profile.virtualBalance
                      ? () => ZeroBalanceRefillSheet.show(context)
                      : null),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: (!isMarketOnline || !liveStock.isLive || liveStock.currentPrice <= 0)
                    ? const Color(0xFF2B3139)
                    : (canExecute
                        ? (isLimit ? AppColors.warning : (isBuy ? AppColors.profit : AppColors.loss))
                        : (isBuy && totalWithFee > userState.profile.virtualBalance
                            ? const Color(0xFF1E2330)
                            : const Color(0xFF2B3139))),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: (!canExecute && isBuy && totalWithFee > userState.profile.virtualBalance)
                      ? const BorderSide(color: Color(0xFF2E374D), width: 1.2)
                      : BorderSide.none,
                ),
              ),
              child: Text(
                (!isMarketOnline || !liveStock.isLive || liveStock.currentPrice <= 0)
                    ? 'Syncing Live Price...'
                    : (isLimit && !isLimitPlausible
                        ? 'Limit Price Out of Range'
                        : (canExecute
                            ? (isLimit ? 'Place Limit ${isBuy ? "Buy" : "Sell"}' : (isBuy ? 'Confirm Buy Spot' : 'Confirm Sell Spot'))
                            : (isBuy && totalWithFee > userState.profile.virtualBalance
                                ? 'Balance Empty — Tap for Free Refill'
                                : (isLimit ? 'Place Limit ${isBuy ? "Buy" : "Sell"}' : (isBuy ? 'Confirm Buy Spot' : 'Confirm Sell Spot'))))),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: canExecute
                      ? (isLimit ? Colors.black : Colors.white)
                      : (isBuy && totalWithFee > userState.profile.virtualBalance
                          ? const Color(0xFF00C087)
                          : AppColors.subtle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAdjBtn(String label, double pct) {
    return GestureDetector(
      onTap: () => _adjustTargetPrice(pct),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.warning)),
      ),
    );
  }

  Widget _buildPctBtn(String label, double pct, UserState state) {
    return GestureDetector(
      onTap: () => _setPercentage(pct, state),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
      ),
    );
  }
}
