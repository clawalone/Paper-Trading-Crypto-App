import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/app_review_manager.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_mode_provider.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/stock_market_provider.dart';
import '../../data/user_provider.dart';
import '../stock_detail/stock_detail_screen.dart';
import 'futures_pro_screen.dart';
import 'futures_position_card.dart';

class FuturesScreen extends ConsumerStatefulWidget {
  const FuturesScreen({super.key});

  @override
  ConsumerState<FuturesScreen> createState() => _FuturesScreenState();
}

class _FuturesScreenState extends ConsumerState<FuturesScreen> {
  String _query = '';
  String _filter = 'All';
  bool _showPositions = false;

  static const _categories = [
    'All', 'Layer 1', 'Layer 2', 'DeFi', 'Exchange',
    'Infrastructure', 'Payments', 'Gaming', 'AI', 'Meme',
  ];

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final marketMode = ref.watch(marketModeProvider);
    final isStocks = marketMode == MarketMode.stocks;
    final market = isStocks ? ref.watch(stockMarketProvider) : ref.watch(marketProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final activePositions = userState.futuresPositions.where((pos) {
      final isStockPos = pos.symbol.endsWith('.NS') || pos.leverage <= 5;
      if (isStocks && !isStockPos) return false;
      if (!isStocks && isStockPos) return false;
      final stockIdx = market.indexWhere((s) => s.symbol == pos.symbol);
      if (stockIdx < 0) return true;
      return !pos.isLiquidated(market[stockIdx].currentPrice);
    }).toList();

    double totalUnrealizedPnl = 0;
    double totalMargin = 0;
    for (final pos in activePositions) {
      final stock = market.firstWhere(
          (s) => s.symbol == pos.symbol, orElse: () => market.first);
      final isLong = pos.side == OrderSide.buy;
      final priceDiff = stock.currentPrice - pos.entryPrice;
      final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
      totalUnrealizedPnl += pnl;
      totalMargin += pos.margin;
    }

    final categories = isStocks
        ? const [
            'All',
            'US Tech',
            'Semiconductors',
            'Crypto & FinTech',
            'Finance & Banks',
            'Consumer',
            'Energy & Industrial',
            'Healthcare',
            'ETFs',
          ]
        : _categories;
    final effectiveFilter = categories.contains(_filter) ? _filter : 'All';

    final filteredMarket = market.where((s) {
      final q = _query.toLowerCase();
      final matchesSearch = s.symbol.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q);
      final matchesFilter = effectiveFilter == 'All' || s.category == effectiveFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── HEADER ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Text(
                    isStocks ? 'Margin 5x' : 'Futures'.tr(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: (isStocks ? const Color(0xFF3B82F6) : AppColors.primary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (isStocks ? const Color(0xFF3B82F6) : AppColors.primary).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: isStocks ? const Color(0xFF3B82F6) : AppColors.primary, size: 6),
                        const SizedBox(width: 4),
                        Text(
                          isStocks ? '5x INTRADAY' : '100x PERP',
                          style: TextStyle(
                            color: isStocks ? const Color(0xFF60A5FA) : AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── TWITTER-STYLE TABS ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.outline, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TwitterTab(
                      label: 'Markets',
                      isSelected: !_showPositions,
                      onTap: () => setState(() => _showPositions = false),
                    ),
                  ),
                  Expanded(
                    child: _TwitterTab(
                      label: 'Positions',
                      badgeText: activePositions.isNotEmpty ? '${activePositions.length}' : null,
                      isSelected: _showPositions,
                      onTap: () => setState(() => _showPositions = true),
                    ),
                  ),
                ],
              ),
            ),

            // ── PNL STRIP (TWITTER CARD STYLE) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline, width: 0.9),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'UNREALIZED P&L'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF71767B),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    totalUnrealizedPnl >= 0 ? Icons.trending_up : Icons.trending_down,
                                    size: 13,
                                    color: totalUnrealizedPnl >= 0 ? AppColors.profit : AppColors.loss,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${totalUnrealizedPnl >= 0 ? '+' : ''}${formatter.format(totalUnrealizedPnl)}',
                                  style: TextStyle(
                                    color: totalUnrealizedPnl >= 0
                                        ? AppColors.profit
                                        : totalUnrealizedPnl < 0
                                            ? AppColors.loss
                                            : const Color(0xFF71767B),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFF2F3336),
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BALANCE'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF71767B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatter.format(userState.profile.virtualBalance),
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: AppColors.outline, height: 1, thickness: 0.8),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Margin Used: ',
                              style: TextStyle(
                                color: Color(0xFF71767B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              formatter.format(totalMargin),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text(
                              'Open Positions: ',
                              style: TextStyle(
                                color: Color(0xFF71767B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: activePositions.isNotEmpty
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : const Color(0xFF202327),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: activePositions.isNotEmpty
                                      ? AppColors.primary.withValues(alpha: 0.4)
                                      : const Color(0xFF2F3336),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (activePositions.isNotEmpty) ...[
                                    const Icon(Icons.circle, size: 5, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '${activePositions.length}',
                                    style: TextStyle(
                                      color: activePositions.isNotEmpty ? AppColors.primary : const Color(0xFF71767B),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  
                  final marketsWidget = Column(
                    children: [
                      // ── SEARCH (TWITTER PILL STYLE) ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              hintText: isStocks
                                  ? 'Search stocks (AAPL, RELIANCE...)'
                                  : 'Search contracts (BTC, ETH, SOL...)',
                              hintStyle: TextStyle(color: AppColors.subtle, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: AppColors.subtle, size: 18),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: AppColors.outline, width: 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                              ),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                      ),

                      // ── CATEGORY FILTERS (TWITTER TOPIC PILLS) ──────────────────
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          scrollDirection: Axis.horizontal,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: categories.length,
                          itemBuilder: (_, i) {
                            final cat = categories[i];
                            final selected = effectiveFilter == cat;
                            return GestureDetector(
                              onTap: () => setState(() => _filter = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? (isStocks ? const Color(0xFF3B82F6) : AppColors.primary)
                                      : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? (isStocks ? const Color(0xFF3B82F6) : AppColors.primary)
                                        : AppColors.outline,
                                    width: 0.8,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cat.tr(),
                                  style: TextStyle(
                                    color: selected ? Colors.white : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // ── COLUMN HEADERS ──────────────────────────────────────────
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text('CONTRACT',
                                  style: TextStyle(
                                      color: Color(0xFF71767B),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6)),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text('PRICE',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('24H %',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text('LEV',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: AppColors.outline),

                      // ── MARKET CARDS ────────────────────────────────────────────
                      Expanded(
                        child: filteredMarket.isEmpty
                            ? const Center(
                                child: Text('No contracts found.',
                                    style: TextStyle(color: Color(0xFF6B7280))))
                            : ListView.separated(
                                physics: const ClampingScrollPhysics(),
                                itemCount: filteredMarket.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: AppColors.outline),
                                itemBuilder: (_, i) => _ContractCard(
                                  stock: filteredMarket[i],
                                  formatter: formatter,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => isStocks
                                          ? StockDetailScreen(stockSymbol: filteredMarket[i].symbol)
                                          : FuturesProScreen(stockSymbol: filteredMarket[i].symbol),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );

                  final positionsWidget = Column(
                    children: [
                      // ── OPEN POSITIONS ──────────────────────────────────────────
                      Expanded(
                        child: activePositions.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inbox_outlined,
                                        color: Color(0xFF2B3139), size: 48),
                                    SizedBox(height: 12),
                                    Text('No open positions',
                                        style: TextStyle(
                                            color: Color(0xFF6B7280), fontSize: 14)),
                                    SizedBox(height: 6),
                                    Text('Open a contract to start trading',
                                        style: TextStyle(
                                            color: Color(0xFF4B5563), fontSize: 12)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                physics: const ClampingScrollPhysics(),
                                itemCount: activePositions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final pos = activePositions[i];
                                  final stock = market.firstWhere(
                                      (s) => s.symbol == pos.symbol,
                                      orElse: () => market.first);
                                  final isLong = pos.side == OrderSide.buy;
                                  final priceDiff =
                                      stock.currentPrice - pos.entryPrice;
                                  final pnl = isLong
                                      ? priceDiff * pos.quantity
                                      : -priceDiff * pos.quantity;
                                  final roe = (pnl / pos.margin) * 100;

                                  return FuturesPositionCard(
                                    pos: pos,
                                    stock: stock,
                                    pnl: pnl,
                                    roe: roe,
                                    isLong: isLong,
                                    formatter: formatter,
                                    onClose: () {
                                      if (!ref.read(marketOnlineProvider)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Cannot close position: Market data is offline.'),
                                            backgroundColor: AppColors.loss,
                                          ),
                                        );
                                        return;
                                      }
                                      ref
                                          .read(userProvider.notifier)
                                          .closeFuturesPosition(
                                              pos, stock.currentPrice);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Position closed'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                      if (pnl > 0) {
                                        AppReviewManager.checkAndPromptReview(
                                          context,
                                          ref,
                                          triggerReason: 'Profitable Trade',
                                          pnlAmount: pnl,
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: marketsWidget),
                        Container(width: 1, color: AppColors.outline),
                        Expanded(flex: 2, child: positionsWidget),
                      ],
                    );
                  }

                  return _showPositions ? positionsWidget : marketsWidget;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TWITTER TAB
// ─────────────────────────────────────────────────────────────────────────────
class _TwitterTab extends StatelessWidget {
  final String label;
  final String? badgeText;
  final bool isSelected;
  final VoidCallback onTap;

  const _TwitterTab({
    required this.label,
    this.badgeText,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.transparent,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.tr(),
                    style: TextStyle(
                      color: isSelected ? AppColors.textPrimary : AppColors.subtle,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.outline,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                height: 3.5,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// CONTRACT CARD (row in the market list)
// ─────────────────────────────────────────────────────────────────────────────
class _ContractCard extends StatelessWidget {
  final Stock stock;
  final AppCurrencyFormatter formatter;
  final VoidCallback onTap;

  const _ContractCard({
    required this.stock,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final pctColor = good ? AppColors.profit : AppColors.loss;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.02),
      highlightColor: Colors.white.withValues(alpha: 0.01),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // ── Symbol + name ──────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  CoinIcon(symbol: stock.symbol, size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                stock.symbol,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (stock.isStock) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                  border: Border.all(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  '5x',
                                  style: TextStyle(
                                    color: Color(0xFF60A5FA),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          stock.name,
                          style: const TextStyle(
                              color: Color(0xFF4B5563), fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Price ──────────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: stock.currentPrice == 0
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        stock.isStock
                            ? (stock.currency == 'INR'
                                ? CurrencyFormatters.format(stock.currentPrice, formatter.currencyCode)
                                : CurrencyFormatters.formatUsd(stock.currentPrice, formatter.currencyCode))
                            : formatter.format(stock.currentPrice),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),

            // ── 24h % ──────────────────────────────────────────────────
            SizedBox(
              width: 70,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    stock.currentPrice == 0
                        ? '—'
                        : '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: stock.currentPrice == 0
                          ? const Color(0xFF6B7280)
                          : pctColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            // ── Leverage ───────────────────────────────────────────────
            SizedBox(
              width: 48,
              child: Text(
                stock.isStock ? '5x' : '100x',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: stock.isStock ? const Color(0xFF60A5FA) : AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POSITION CARD
