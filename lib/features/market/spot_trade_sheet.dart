import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/app_review_manager.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';

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
  double get _targetPrice => _orderType == 'Limit'
      ? (double.tryParse(_targetPriceController.text) ?? _liveStock.currentPrice)
      : _liveStock.currentPrice;

  int get _cryptoQty => _isCryptoInput
      ? _inputVal.floor()
      : (_inputVal / _targetPrice).floor();

  double get _fiatAmount =>
      _isCryptoInput ? (_inputVal * _targetPrice) : _inputVal;

  int _getOwnedQty(UserState state) {
    final h = state.holdings.firstWhere(
      (e) => e.symbol == widget.stock.symbol,
      orElse: () => Holding(symbol: widget.stock.symbol, quantity: 0, averagePrice: 0),
    );
    return h.quantity;
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

    final canExecute = isMarketOnline &&
        liveStock.isLive &&
        _cryptoQty > 0 &&
        execPrice > 0 &&
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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
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
                            color: isBuy ? Colors.white : Colors.white54,
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
                            color: !isBuy ? Colors.white : Colors.white54,
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
                        color: !isLimit ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: !isLimit ? AppColors.primary : AppColors.outline),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Market Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: !isLimit ? AppColors.primary : Colors.white54,
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
                        color: isLimit ? AppColors.warning.withValues(alpha: 0.15) : AppColors.surface,
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
                              color: isLimit ? AppColors.warning : Colors.white54,
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
                  const Text('Target Limit Price', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Market: ${formatter.format(widget.stock.currentPrice)}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  prefixText: '$currSym ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surface,
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
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: _isCryptoInput ? 'Amount (${widget.stock.symbol})' : 'Amount ($currSym)',
                labelStyle: const TextStyle(fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
                suffixText: _isCryptoInput ? widget.stock.symbol : currSym,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_inputVal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4),
                child: Text(
                  _isCryptoInput ? '≈ ${formatter.format(_fiatAmount)}' : '≈ $_cryptoQty ${widget.stock.symbol}',
                  style: const TextStyle(color: Colors.white54),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Value', style: TextStyle(color: Colors.white70)),
                      Text(formatter.format(totalCost), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Est. Trading Fee (0.1%)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      Text(formatter.format(fee), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isBuy ? 'Total Payable' : 'Total Receivable', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        formatter.format(totalWithFee),
                        style: TextStyle(fontWeight: FontWeight.w900, color: isBuy ? AppColors.profit : Colors.white, fontSize: 16),
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
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.loss, size: 16),
                    SizedBox(width: 8),
                    Text('Insufficient available balance', style: TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.w600)),
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
            if (!isMarketOnline || !liveStock.isLive) ...[
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
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: (!isMarketOnline || !liveStock.isLive)
                    ? const Color(0xFF2B3139)
                    : (isLimit ? AppColors.warning : (isBuy ? AppColors.profit : AppColors.loss)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                (!isMarketOnline || !liveStock.isLive)
                    ? 'Syncing Live Price...'
                    : (isLimit ? 'Place Limit ${isBuy ? "Buy" : "Sell"}' : (isBuy ? 'Confirm Buy Spot' : 'Confirm Sell Spot')),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: (!isMarketOnline || !liveStock.isLive) ? Colors.white38 : (isLimit ? Colors.black : Colors.white),
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
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
