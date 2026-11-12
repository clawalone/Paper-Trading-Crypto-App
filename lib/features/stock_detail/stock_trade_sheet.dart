import 'package:flutter/services.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../../data/stock_market_provider.dart';

class StockTradeSheet extends ConsumerStatefulWidget {
  final Stock stock;
  final OrderSide initialSide;

  const StockTradeSheet({
    super.key,
    required this.stock,
    required this.initialSide,
  });

  static Future<void> show(BuildContext context, Stock stock, OrderSide initialSide) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StockTradeSheet(stock: stock, initialSide: initialSide),
    );
  }

  @override
  ConsumerState<StockTradeSheet> createState() => _StockTradeSheetState();
}

class _StockTradeSheetState extends ConsumerState<StockTradeSheet> {
  late OrderSide _side;
  int _quantity = 1;
  int _leverage = 1; // 1 = Delivery, 2..5 = Margin
  final TextEditingController _qtyController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Stock get _liveStock {
    final list = ref.watch(stockMarketProvider);
    return list.firstWhere(
      (s) => s.symbol == widget.stock.symbol,
      orElse: () => widget.stock,
    );
  }

  int _getOwnedQty(UserState userState) {
    return userState.availableHoldingQty(widget.stock.symbol);
  }

  void _updateQuantity(int val) {
    if (val < 1) val = 1;
    setState(() {
      _quantity = val;
      _qtyController.text = val.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final stock = _liveStock;
    final isBuy = _side == OrderSide.buy;
    final isMarketOpen = stock.isMarketOpen;
    final ownedQty = _getOwnedQty(userState);

    final isIndian = stock.currency == 'INR';
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final currencySymbol = isIndian ? '₹' : '\$';

    // Base cost in native stock currency
    final localPrice = stock.currentPrice;
    final localTotal = localPrice * _quantity;

    // USD equivalent for master virtual wallet
    final usdPrice = isIndian ? (localPrice / inrRate) : localPrice;
    final usdTotal = usdPrice * _quantity;
    final usdMarginRequired = usdTotal / _leverage;

    final isPriceLive = stock.isLive && stock.currentPrice > 0;
    final canAfford = isPriceLive && (isBuy
        ? userState.profile.virtualBalance >= usdMarginRequired
        : (_leverage > 1
            ? userState.profile.virtualBalance >= usdMarginRequired
            : ownedQty >= _quantity));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF181A20),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2B313A), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B313A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row: Stock Info + Market Open/Closed Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stock.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B313A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stock.exchange,
                            style: const TextStyle(
                              color: Color(0xFF848E9C),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stock.symbol} • $currencySymbol${localPrice.toStringAsFixed(2)}${isIndian ? " (≈ \$${usdPrice.toStringAsFixed(2)} USD)" : ""}',
                      style: const TextStyle(
                        color: Color(0xFF848E9C),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Market State Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMarketOpen
                        ? const Color(0xFF0ECB81).withValues(alpha: 0.15)
                        : const Color(0xFFF6465D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMarketOpen ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isMarketOpen ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMarketOpen ? 'MARKET OPEN' : 'MARKET CLOSED',
                        style: TextStyle(
                          color: isMarketOpen ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Order Side Selector (BUY vs SELL)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2B313A)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _side = OrderSide.buy);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isBuy ? const Color(0xFF0ECB81) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'BUY (LONG)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isBuy ? Colors.black : const Color(0xFF848E9C),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _side = OrderSide.sell);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isBuy ? const Color(0xFFF6465D) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'SELL (SHORT / EXIT)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: !isBuy ? Colors.white : const Color(0xFF848E9C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Product Type Selector: Delivery (1x) vs Intraday Margin (up to 5x)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2B313A)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _leverage = 1);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _leverage == 1 ? const Color(0xFF2B313A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🚚 Delivery (1x Cash)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _leverage = 5);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _leverage > 1 ? const Color(0xFF2B313A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '⚡ Margin (5x Intraday)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _leverage > 1 ? const Color(0xFFF3BA2F) : const Color(0xFF848E9C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Margin Leverage Tier Pills (if Margin is selected)
            if (_leverage > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Margin Multiplier:',
                    style: TextStyle(color: Color(0xFF848E9C), fontSize: 12),
                  ),
                  Row(
                    children: [2, 3, 5].map((lev) {
                      final isSel = _leverage == lev;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _leverage = lev);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFF3BA2F) : const Color(0xFF2B313A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${lev}x',
                            style: TextStyle(
                              color: isSel ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Quantity Header: Available shares and Stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Number of Shares (Whole Units):',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isBuy
                      ? 'Cash: \$${userState.profile.virtualBalance.toStringAsFixed(2)}'
                      : 'Owned: $ownedQty shares',
                  style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Stepper & Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2B313A)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 1 ? () => _updateQuantity(_quantity - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF848E9C)),
                    iconSize: 24,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixText: 'shares',
                        suffixStyle: TextStyle(color: Color(0xFF848E9C), fontSize: 13),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val) ?? 1;
                        if (parsed >= 1) {
                          setState(() => _quantity = parsed);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => _updateQuantity(_quantity + 1),
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0ECB81)),
                    iconSize: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Share Shortcut Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [1, 2, 5, 10, 25, 50, 100].map((qty) {
                final isSelected = _quantity == qty;
                return GestureDetector(
                  onTap: () => _updateQuantity(qty),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2B313A) : const Color(0xFF0B0E11),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0ECB81) : const Color(0xFF2B313A),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '+$qty',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF0ECB81) : const Color(0xFF848E9C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Financial Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2B313A)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Value', style: TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                      Text(
                        isIndian
                            ? '$currencySymbol${localTotal.toStringAsFixed(2)} (≈ \$${usdTotal.toStringAsFixed(2)} USD)'
                            : '$currencySymbol${localTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_leverage > 1) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Margin Required (${_leverage}x)', style: const TextStyle(color: Color(0xFFF3BA2F), fontSize: 12)),
                        Text(
                          '\$${usdMarginRequired.toStringAsFixed(2)} USD',
                          style: const TextStyle(color: Color(0xFFF3BA2F), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Brokerage Commission', style: TextStyle(color: Color(0xFF848E9C), fontSize: 12)),
                      Text('FREE (\$0.00)', style: TextStyle(color: Color(0xFF0ECB81), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFF2B313A), height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Wallet Deduction',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${usdMarginRequired.toStringAsFixed(2)} USD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Price Sync Notice Banner (if price is unloaded / stale)
            if (!isPriceLive) ...[
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
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF6465D)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Syncing real-time exchange price for ${stock.symbol}... Trading is locked until price is verified.',
                        style: const TextStyle(color: Color(0xFFF6465D), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Off-Hours Notice Banner (if market is closed)
            if (!isMarketOpen && isPriceLive) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B313A).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF3BA2F).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nightlight_round, color: Color(0xFFF3BA2F), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Market is currently closed. This order will be queued as an After-Market Order (AMO) and executed when the opening bell rings.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Execute / Queue Button
            FilledButton(
              onPressed: (canAfford && isPriceLive)
                  ? () {
                      final notifier = ref.read(userProvider.notifier);

                      if (!isMarketOpen) {
                        // Queue After-Market Order (AMO)
                        final ok = notifier.queueAmoOrder(
                          stock: stock,
                          side: _side,
                          quantity: _quantity,
                          leverage: _leverage,
                        );
                        Navigator.pop(context);
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'After-Market Order (AMO) queued for $_quantity shares of ${stock.symbol}! 🌅',
                              ),
                              backgroundColor: const Color(0xFFF3BA2F),
                            ),
                          );
                        }
                      } else {
                        // Live Market Execution
                        if (_leverage > 1) {
                          final ok = notifier.openFuturesPosition(
                            stock,
                            _side,
                            _leverage,
                            _quantity.toDouble(),
                            orderType: 'Margin Intraday',
                          );
                          Navigator.pop(context);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Margin trade executed: $_quantity shares of ${stock.symbol} at ${_leverage}x!'),
                                backgroundColor: const Color(0xFF0ECB81),
                              ),
                            );
                          }
                        } else {
                          final ok = notifier.tradeStock(stock, _side, _quantity);
                          Navigator.pop(context);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Delivery trade executed: $_quantity shares of ${stock.symbol}!'),
                                backgroundColor: const Color(0xFF0ECB81),
                              ),
                            );
                          }
                        }
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: (!isPriceLive || !canAfford)
                    ? const Color(0xFF2B313A)
                    : (!isMarketOpen
                        ? const Color(0xFFF3BA2F)
                        : (isBuy ? const Color(0xFF0ECB81) : const Color(0xFFF6465D))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                !isPriceLive
                    ? 'Syncing Live Price...'
                    : (!canAfford
                        ? (isBuy ? 'Insufficient Virtual Balance' : 'Insufficient Shares Owned')
                        : (!isMarketOpen
                            ? 'Queue After-Market Order (AMO) 🌙'
                            : (isBuy ? 'Confirm Buy ($_quantity shares)' : 'Confirm Sell ($_quantity shares)'))),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: (!isPriceLive || !canAfford)
                      ? const Color(0xFF848E9C)
                      : (!isMarketOpen ? Colors.black : (isBuy ? Colors.black : Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
