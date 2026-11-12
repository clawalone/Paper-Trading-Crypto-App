import 'package:stock_arena/core/app_material.dart';
import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';

class FuturesPositionCard extends StatelessWidget {
  final FuturesPosition pos;
  final Stock stock;
  final double pnl;
  final double roe;
  final bool isLong;
  final AppCurrencyFormatter formatter;
  final VoidCallback onClose;

  const FuturesPositionCard({
    super.key,
    required this.pos,
    required this.stock,
    required this.pnl,
    required this.roe,
    required this.isLong,
    required this.formatter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor  = pnl >= 0 ? AppColors.profit : AppColors.loss;
    final sideColor = isLong ? AppColors.profit : AppColors.loss;

    final positionSize  = pos.quantity * pos.entryPrice;          // full leveraged value
    final currentValue  = pos.quantity * stock.currentPrice;       // current mark value
    final liqPrice      = pos.liquidationPrice;

    // Distance to liquidation as a %
    final distToLiq = liqPrice > 0
        ? ((stock.currentPrice - liqPrice) / stock.currentPrice * 100).abs()
        : 0.0;
    final liqColor = distToLiq < 5
        ? AppColors.loss
        : distToLiq < 15
            ? AppColors.warning
            : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outline,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── TOP HEADER ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                // Coin icon
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: CoinIcon(symbol: pos.symbol, size: 36),
                ),
                const SizedBox(width: 10),

                // Symbol + side badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pos.symbol,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: -0.2),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: sideColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: sideColor.withValues(alpha: 0.35),
                                  width: 0.8),
                            ),
                            child: Text(
                              '${isLong ? 'LONG' : 'SHORT'} ${pos.leverage}x',
                              style: TextStyle(
                                  color: sideColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Perpetual Contract • Isolated',
                        style: TextStyle(
                            color: Color(0xFF71767B), fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Live PnL
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}',
                      style: TextStyle(
                          color: pnlColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: pnlColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'ROE ${roe >= 0 ? '+' : ''}${roe.toStringAsFixed(2)}%',
                        style: TextStyle(
                            color: pnlColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.outline, thickness: 0.8),

          // ── STATS GRID (TWITTER MICRO-METRICS) ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Row 1
                Row(
                  children: [
                    _Stat(
                      label: 'Margin',
                      value: formatter.format(pos.margin),
                      valueColor: AppColors.textPrimary,
                    ),
                    _Stat(
                      label: 'Position Size',
                      value: formatter.format(positionSize),
                      valueColor: AppColors.primary,
                      align: CrossAxisAlignment.center,
                    ),
                    _Stat(
                      label: 'Current Value',
                      value: formatter.format(currentValue),
                      align: CrossAxisAlignment.end,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2
                Row(
                  children: [
                    _Stat(
                      label: 'Entry Price',
                      value: formatter.format(pos.entryPrice),
                    ),
                    _Stat(
                      label: 'Mark Price',
                      value: formatter.format(stock.currentPrice),
                      valueColor: stock.currentPrice >= pos.entryPrice
                          ? AppColors.profit
                          : AppColors.loss,
                      align: CrossAxisAlignment.center,
                    ),
                    _Stat(
                      label: 'Qty (${pos.symbol})',
                      value: pos.quantity.toStringAsFixed(4),
                      align: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── LIQUIDATION BAR ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.outline, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: liqColor, size: 14),
                  const SizedBox(width: 6),
                  const Text('Liquidation Price:  ',
                      style: TextStyle(
                          color: Color(0xFF71767B), fontSize: 11.5)),
                  Text(
                    formatter.format(liqPrice),
                    style: TextStyle(
                        color: liqColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${distToLiq.toStringAsFixed(1)}% away',
                    style: TextStyle(
                        color: liqColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // ── CLOSE BUTTON (TWITTER PILL STYLE) ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: InkWell(
              onTap: () => _confirmClose(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outline, width: 0.9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded,
                        color: pnlColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Close Position  •  ${pnl >= 0 ? '+' : ''}${formatter.format(pnl)} P&L',
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClose(BuildContext context) {
    final pnlColor = pnl >= 0 ? AppColors.profit : AppColors.loss;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Close Position?',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text(
              '${pos.symbol} ${isLong ? 'Long' : 'Short'} ${pos.leverage}x',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline, width: 1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    const Text('MARGIN',
                        style: TextStyle(
                            color: Color(0xFF71767B), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(formatter.format(pos.margin),
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ]),
                  Column(children: [
                    const Text('P&L',
                        style: TextStyle(
                            color: Color(0xFF71767B), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      '${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}',
                      style: TextStyle(
                          color: pnlColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ]),
                  Column(children: [
                    const Text('YOU RECEIVE',
                        style: TextStyle(
                            color: Color(0xFF71767B), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format((pos.margin + pnl).clamp(0, double.infinity)),
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.outline, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onClose();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.loss,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Confirm Close',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final CrossAxisAlignment align;

  const _Stat({
    required this.label,
    required this.value,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF71767B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
