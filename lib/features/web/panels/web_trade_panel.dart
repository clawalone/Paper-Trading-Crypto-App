import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/currency_formatters.dart';
import '../../../data/market_provider.dart';
import '../../../data/user_provider.dart';
import '../../../data/models.dart';

class WebTradePanel extends ConsumerStatefulWidget {
  final String symbol;
  const WebTradePanel({super.key, required this.symbol});

  @override
  ConsumerState<WebTradePanel> createState() => _WebTradePanelState();
}

class _WebTradePanelState extends ConsumerState<WebTradePanel> {
  bool _isSpot = true;
  bool _isBuy = true;
  double _leverage = 10;
  final _amountCtrl = TextEditingController();

  @override
  void didUpdateWidget(covariant WebTradePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _amountCtrl.clear();
    }
  }

  void _executeTrade() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    final market = ref.read(marketProvider);
    final stock = market.firstWhere((s) => s.symbol == widget.symbol, orElse: () => market.first);

    final success = _isSpot
        ? ref.read(userProvider.notifier).tradeStock(stock, _isBuy ? OrderSide.buy : OrderSide.sell, amount.toInt())
        : ref.read(userProvider.notifier).openFuturesPosition(stock, _isBuy ? OrderSide.buy : OrderSide.sell, _leverage.toInt(), amount);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order Filled: ${widget.symbol} ${_isBuy ? 'Buy/Long' : 'Sell/Short'}'),
        backgroundColor: AppColors.profit,
      ));
      _amountCtrl.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Insufficient funds or invalid trade'),
        backgroundColor: AppColors.loss,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final stock = market.firstWhere((s) => s.symbol == widget.symbol, orElse: () => market.first);
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final avail = userState.profile.virtualBalance;

    return Container(
      color: const Color(0xFF161A1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spot / Futures Tabs
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSpot = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _isSpot ? AppColors.primary : Colors.transparent, width: 2)),
                    ),
                    child: Center(child: Text('Spot', style: TextStyle(color: _isSpot ? AppColors.primary : const Color(0xFF848E9C), fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSpot = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: !_isSpot ? AppColors.primary : Colors.transparent, width: 2)),
                    ),
                    child: Center(child: Text('Futures', style: TextStyle(color: !_isSpot ? AppColors.primary : const Color(0xFF848E9C), fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Buy / Sell Tabs
                Container(
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isBuy = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: _isBuy ? AppColors.profit : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('Buy', style: TextStyle(color: _isBuy ? Colors.black : const Color(0xFF848E9C), fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isBuy = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: !_isBuy ? AppColors.loss : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('Sell', style: TextStyle(color: !_isBuy ? Colors.black : const Color(0xFF848E9C), fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available', style: TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                    Text(formatter.format(avail), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Price Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price', style: TextStyle(color: Color(0xFF848E9C))),
                      Text(stock.currentPrice.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Amount Input
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _isSpot ? 'Quantity' : 'Margin Amount (USD)',
                    labelStyle: const TextStyle(color: Color(0xFF848E9C)),
                    filled: true,
                    fillColor: const Color(0xFF1E2329),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isSpot) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Leverage', style: TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                      Text('${_leverage.toInt()}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: _leverage,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: AppColors.primary,
                    inactiveColor: const Color(0xFF2B3139),
                    onChanged: (v) => setState(() => _leverage = v),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Button
                FilledButton(
                  onPressed: _executeTrade,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isBuy ? AppColors.profit : AppColors.loss,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_isSpot ? (_isBuy ? 'Buy ${stock.symbol}' : 'Sell ${stock.symbol}') : (_isBuy ? 'Long ${stock.symbol}' : 'Short ${stock.symbol}'), 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
