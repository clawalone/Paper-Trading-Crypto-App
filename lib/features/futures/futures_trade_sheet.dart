import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../../core/rewarded_ad_manager.dart';
import '../profile/widgets/zero_balance_refill_sheet.dart';

class FuturesTradeSheet extends ConsumerStatefulWidget {
  final Stock stock;
  final OrderSide initialSide;
  final int initialLeverage;
  const FuturesTradeSheet({
    super.key,
    required this.stock,
    this.initialSide = OrderSide.buy,
    this.initialLeverage = 1,
  });

  @override
  ConsumerState<FuturesTradeSheet> createState() => _FuturesTradeSheetState();
}

class _FuturesTradeSheetState extends ConsumerState<FuturesTradeSheet> {
  late OrderSide _side;
  int _leverage = 1;
  final _amountController = TextEditingController(); // user enters margin in ₹

  static const _leverageOptions = [1, 2, 5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    _leverage = _leverageOptions.contains(widget.initialLeverage)
        ? widget.initialLeverage
        : 1;
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
    _amountController.dispose();
    super.dispose();
  }

  Stock get _liveStock {
    return ref.watch(marketProvider).firstWhere(
      (s) => s.symbol == widget.stock.symbol,
      orElse: () => widget.stock,
    );
  }

  /// Margin the user wants to put in (₹)
  double get _margin => double.tryParse(_amountController.text) ?? 0.0;

  /// Position size = margin × leverage (₹)
  double get _positionSize => _margin * _leverage;

  /// Coin quantity = position size / current price
  double get _quantity => _positionSize / (_liveStock.currentPrice > 0 ? _liveStock.currentPrice : 1.0);

  /// Approx liquidation price
  double get _liquidationPrice {
    final price = _liveStock.currentPrice;
    if (_side == OrderSide.buy) {
      return price * (1 - 1 / _leverage);
    } else {
      return price * (1 + 1 / _leverage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final isMarketOnline = ref.watch(marketOnlineProvider);
    final liveStock = _liveStock;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
    final isLong = _side == OrderSide.buy;
    final canExecute = isMarketOnline && liveStock.isLive && liveStock.currentPrice > 0 && _margin > 0 && _margin <= userState.profile.virtualBalance;

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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.stock.symbol}-PERP',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(formatter.format(widget.stock.currentPrice),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 20),

            // Long / Short toggle
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
                          color: isLong ? AppColors.profit : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('Open Long',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isLong ? Colors.white : Colors.white54)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.sell),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isLong ? AppColors.loss : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('Open Short',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !isLong ? Colors.white : Colors.white54)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Leverage selector
            const Text('Leverage', style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: _leverageOptions.map((lev) {
                final selected = _leverage == lev;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _leverage = lev),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : const Color(0xFF1E2329),
                        borderRadius: BorderRadius.circular(8),
                        border: selected ? null : Border.all(color: const Color(0xFF2B3139)),
                      ),
                      alignment: Alignment.center,
                      child: Text('${lev}x',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.black : Colors.white70,
                              fontSize: 13)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Margin input (rupees)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Avail: ${formatter.format(userState.profile.virtualBalance)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if (userState.profile.virtualBalance <= 0)
                  InkWell(
                    onTap: () => ZeroBalanceRefillSheet.show(context),
                    borderRadius: BorderRadius.circular(4),
                    child: const Text(
                      'Free Refill (Watch Ad)',
                      style: TextStyle(
                        color: Color(0xFF00C087),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'Margin Amount ($currSym)',
                labelStyle: const TextStyle(fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
                prefixText: '$currSym ',
                prefixStyle: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white70),
                helperText: 'This is the amount deducted from your balance',
                helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Summary box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Position Size',
                    value: formatter.format(_positionSize),
                    highlight: true,
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Coin Qty',
                    value: '${_quantity.toStringAsFixed(4)} ${widget.stock.symbol}',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Est. Liq. Price',
                    value: formatter.format(_liquidationPrice),
                    valueColor: Colors.amber,
                  ),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppColors.outline)),
                  _SummaryRow(
                    label: 'Margin (deducted)',
                    value: formatter.format(_margin),
                    valueColor: AppColors.loss,
                    highlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                            ? 'Connecting to live market. Futures orders are locked...'
                            : 'Syncing real-time futures price for ${liveStock.symbol}...',
                        style: const TextStyle(color: Color(0xFFF6465D), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Execute button
            FilledButton(
              onPressed: canExecute
                  ? () {
                      final success = ref
                          .read(userProvider.notifier)
                          .openFuturesPosition(
                              liveStock, _side, _leverage, _quantity);
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Position opened! ${_leverage}x ${isLong ? 'Long' : 'Short'} ${liveStock.symbol} • Margin: ${formatter.format(_margin)}'),
                            backgroundColor: AppColors.profit));
                      }
                    }
                  : (_margin > userState.profile.virtualBalance || userState.profile.virtualBalance <= 0
                      ? () => ZeroBalanceRefillSheet.show(context)
                      : null),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: (!isMarketOnline || !liveStock.isLive)
                    ? const Color(0xFF2B3139)
                    : (canExecute
                        ? (isLong ? AppColors.profit : AppColors.loss)
                        : (_margin > userState.profile.virtualBalance || userState.profile.virtualBalance <= 0
                            ? const Color(0xFF1E2330)
                            : const Color(0xFF2B3139))),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: (!canExecute && (_margin > userState.profile.virtualBalance || userState.profile.virtualBalance <= 0))
                      ? const BorderSide(color: Color(0xFF2E374D), width: 1.2)
                      : BorderSide.none,
                ),
              ),
              child: Text(
                  (!isMarketOnline || !liveStock.isLive)
                      ? 'Syncing Live Price...'
                      : (canExecute
                          ? '${isLong ? 'Buy / Long' : 'Sell / Short'}  •  ${_leverage}x  •  ${formatter.format(_margin)} margin'
                          : (_margin > userState.profile.virtualBalance || userState.profile.virtualBalance <= 0
                              ? 'Margin Empty — Tap for Free Refill'
                              : '${isLong ? 'Buy / Long' : 'Sell / Short'}  •  ${_leverage}x  •  ${formatter.format(_margin)} margin')),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: (!isMarketOnline || !liveStock.isLive)
                          ? Colors.white38
                          : (canExecute
                              ? Colors.white
                              : (_margin > userState.profile.virtualBalance || userState.profile.virtualBalance <= 0
                                  ? const Color(0xFF00C087)
                                  : Colors.white38))),
                ),
              ),
            ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white60,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontWeight: highlight ? FontWeight.w900 : FontWeight.bold,
                fontSize: highlight ? 16 : 14,
                color: valueColor ?? Colors.white)),
      ],
    );
  }
}
