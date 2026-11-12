import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/coin_icon.dart';
import '../../data/market_provider.dart';
import '../../data/stock_market_provider.dart';
import '../../data/market_mode_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_pro_screen.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../home/home_shell.dart';
import '../../core/widgets/arena_switcher.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  int _selectedTab = 0; // 0: Overview, 1: Spot, 2: Futures, 3: Orders, 4: History
  int _touchedSectionIndex = -1;
  bool _hideBalance = false;

  Color _getCoinColor(String symbol, int index) {
    final s = symbol.toUpperCase();
    if (s.contains('BTC')) return const Color(0xFFF7931A); // Bitcoin Orange
    if (s.contains('ETH')) return const Color(0xFF627EEA); // Ethereum Blue
    if (s.contains('SOL')) return const Color(0xFF14F195); // Solana Green
    if (s.contains('BNB')) return const Color(0xFFF3BA2F); // Binance Gold
    if (s.contains('XRP')) return const Color(0xFF00AAE4); // Ripple Blue
    if (s.contains('DOGE')) return const Color(0xFFC2A633); // Doge Gold
    if (s.contains('ADA')) return const Color(0xFF0033AD); // Cardano Blue
    if (s.contains('AVAX')) return const Color(0xFFE84142); // Avalanche Red
    if (s.contains('DOT')) return const Color(0xFFE6007A); // Polkadot Pink
    if (s.contains('LINK')) return const Color(0xFF375BD2); // Chainlink Blue
    if (s.contains('TON')) return const Color(0xFF0098EA); // TON Cyan
    if (s.contains('WIF')) return const Color(0xFFE08B58); // WIF Tan
    if (s.contains('BONK')) return const Color(0xFFFF9500); // BONK Orange
    if (s.contains('PEPE')) return const Color(0xFF55A947); // PEPE Green
    if (s.contains('SUI')) return const Color(0xFF2A82E4); // Sui Blue
    if (s.contains('CASH')) return const Color(0xFF00D09C); // Mint Teal

    final palette = [
      const Color(0xFF00D09C),
      const Color(0xFF38BDF8),
      const Color(0xFF818CF8),
      const Color(0xFFA78BFA),
      const Color(0xFFF472B6),
      const Color(0xFFFB923C),
      const Color(0xFFFBBF24),
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(marketModeProvider);
    final isStockMode = mode == MarketMode.stocks;
    final stockMarket = ref.watch(stockMarketProvider);
    final cryptoMarket = ref.watch(marketProvider);
    final market = isStockMode ? stockMarket : cryptoMarket;

    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final cryptoMap = {for (final s in cryptoMarket) s.symbol: s};
    final stockMap = {for (final s in stockMarket) s.symbol: s};
    final stockSymbols = kStockAssets.map((a) => a.symbol).toSet();

    bool isStockSymbol(String sym) {
      final clean = sym.replaceAll(' PERP', '').replaceAll('.P', '').replaceAll('/USD', '').trim();
      return sym.endsWith('.NS') ||
          sym.endsWith('.BO') ||
          sym.startsWith('^') ||
          stockSymbols.contains(clean) ||
          stockSymbols.contains(sym);
    }

    // Filter active holdings based on active mode
    final displayedHoldings = isStockMode
        ? userState.holdings.where((h) => isStockSymbol(h.symbol)).toList()
        : userState.holdings.where((h) => !isStockSymbol(h.symbol)).toList();

    // Filter trades based on active mode
    final displayedTrades = isStockMode
        ? userState.trades.where((t) => isStockSymbol(t.symbol)).toList()
        : userState.trades.where((t) => !isStockSymbol(t.symbol)).toList();

    double spotPortfolioValue = 0;
    double spotInvestedValue = 0;
    final Map<String, double> assetValues = {};

    // 1. Calculate Spot Assets
    for (final holding in displayedHoldings) {
      final stock = stockMap[holding.symbol] ?? cryptoMap[holding.symbol] ?? Stock(
        symbol: holding.symbol,
        name: holding.symbol,
        category: isStockMode ? 'Stocks' : 'Crypto',
        currentPrice: holding.averagePrice,
        previousClose: holding.averagePrice,
        dayHigh: holding.averagePrice,
        dayLow: holding.averagePrice,
        volume: 0,
        history: [],
        candleHistory: [],
        about: '',
        supply: 0.0,
        rank: 0,
      );
      final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
      final priceUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
      final avgUsd = holding.averagePrice;
      final value = priceUsd * holding.quantity;
      spotPortfolioValue += value;
      spotInvestedValue += avgUsd * holding.quantity;
      assetValues[holding.symbol] = value;
    }

    // 2. Calculate Futures / Margin Positions
    final allFutures = isStockMode
        ? userState.futuresPositions.where((p) => isStockSymbol(p.symbol)).toList()
        : userState.futuresPositions.where((p) => !isStockSymbol(p.symbol)).toList();

    final activeFutures = allFutures.where((pos) {
      final s = stockMap[pos.symbol] ?? cryptoMap[pos.symbol];
      if (s == null) return true;
      final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
      final priceUsd = s.currency == 'INR' ? (s.currentPrice / inrRate) : s.currentPrice;
      return !pos.isLiquidated(priceUsd);
    }).toList();

    double totalFuturesMargin = 0;
    double totalFuturesPnl = 0;
    for (final pos in activeFutures) {
      final stock = stockMap[pos.symbol] ?? cryptoMap[pos.symbol] ?? Stock(
        symbol: pos.symbol,
        name: pos.symbol,
        category: isStockMode ? 'Stocks' : 'Crypto',
        currentPrice: pos.entryPrice,
        previousClose: pos.entryPrice,
        dayHigh: pos.entryPrice,
        dayLow: pos.entryPrice,
        volume: 0,
        history: [],
        candleHistory: [],
        about: '',
        supply: 0.0,
        rank: 0,
      );
      final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
      final priceUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
      final isLong = pos.side == OrderSide.buy;
      final priceDiff = priceUsd - pos.entryPrice;
      final posPnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;

      totalFuturesMargin += pos.margin;
      totalFuturesPnl += posPnl;

      final currentValue = pos.margin + posPnl;
      final safeValue = currentValue > 0 ? currentValue : 0.0;
      final assetKey = isStockMode ? '${pos.symbol} (Margin)' : '${pos.symbol} (Futures)';
      assetValues[assetKey] = (assetValues[assetKey] ?? 0) + safeValue;
    }

    final cash = userState.profile.virtualBalance;
    final totalNetWorth = spotPortfolioValue + totalFuturesMargin + totalFuturesPnl + cash;
    final totalInvested = spotInvestedValue + totalFuturesMargin;
    final totalPnl = (spotPortfolioValue - spotInvestedValue) + totalFuturesPnl;
    final totalPnlPercent = totalInvested == 0 ? 0.0 : (totalPnl / totalInvested) * 100;

    assetValues['CASH'] = cash;

    final sortedAssets = assetValues.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final pendingOrdersCount = userState.spotLimitOrders.where((o) => o.status == 'pending').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Portfolio'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
            ),
            const SizedBox(width: 10),
            const ArenaSwitcher(compact: true),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _hideBalance ? 'Show balance' : 'Hide balance',
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
            icon: Icon(
              _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                // ── Hero Valuation Card ──────────────────────────────────────
                _buildHeroCard(
                  totalNetWorth: totalNetWorth,
                  totalPnl: totalPnl,
                  totalPnlPercent: totalPnlPercent,
                  cash: cash,
                  spotValue: spotPortfolioValue,
                  futuresMargin: totalFuturesMargin,
                  futuresPnl: totalFuturesPnl,
                  formatter: formatter,
                ),

                const SizedBox(height: 18),

                // ── Segmented Navigation Tabs ────────────────────────────────
                _buildSegmentedTabs(
                  isStockMode: isStockMode,
                  holdingsCount: displayedHoldings.length,
                  futuresCount: activeFutures.length,
                  ordersCount: isStockMode
                      ? userState.amoOrders.where((o) => o.status == 'queued').length
                      : pendingOrdersCount,
                  tradesCount: displayedTrades.length,
                ),

                const SizedBox(height: 20),

                // ── Tab Content Views ────────────────────────────────────────
                if (_selectedTab == 0)
                  _buildOverviewTab(
                    totalNetWorth: totalNetWorth,
                    sortedAssets: sortedAssets,
                    userState: userState,
                    market: market,
                    formatter: formatter,
                    isStockMode: isStockMode,
                    displayedHoldings: displayedHoldings,
                    activeFutures: activeFutures,
                  )
                else if (_selectedTab == 1)
                  _buildHoldingsTab(
                    holdings: displayedHoldings,
                    market: market,
                    formatter: formatter,
                    isStockMode: isStockMode,
                  )
                else if (_selectedTab == 2)
                  _buildFuturesTab(
                    positions: activeFutures,
                    market: market,
                    formatter: formatter,
                    isStockMode: isStockMode,
                  )
                else if (_selectedTab == 3)
                  isStockMode
                      ? _buildAmoOrdersTab(
                          orders: userState.amoOrders,
                          formatter: formatter,
                        )
                      : _buildOrdersTab(
                          orders: userState.spotLimitOrders.where((o) => o.status == 'pending').toList(),
                          formatter: formatter,
                        )
                else
                  _buildHistoryTab(
                    trades: displayedTrades,
                    formatter: formatter,
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. HERO VALUATION CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildHeroCard({
    required double totalNetWorth,
    required double totalPnl,
    required double totalPnlPercent,
    required double cash,
    required double spotValue,
    required double futuresMargin,
    required double futuresPnl,
    required AppCurrencyFormatter formatter,
  }) {
    final isProfitable = totalPnl >= 0;
    final formattedPnl = '${isProfitable ? '+' : ''}${formatter.format(totalPnl)}';
    final formattedPercent = '${isProfitable ? '+' : ''}${totalPnlPercent.toStringAsFixed(2)}%';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? null : AppColors.surface,
        gradient: AppColors.isDarkMode
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF22262B),
                  Color(0xFF181B1E),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDarkMode ? 0.45 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF94A3B8), size: 15),
                  SizedBox(width: 6),
                  Text(
                    'NET WORTH',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: AppColors.profit),
                    SizedBox(width: 5),
                    Text(
                      'LIVE FEED',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _hideBalance ? '••••••••' : formatter.format(totalNetWorth),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isProfitable ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfitable ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isProfitable ? AppColors.profit : AppColors.loss,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _hideBalance ? '••••' : '$formattedPnl ($formattedPercent)',
                      style: TextStyle(
                        color: isProfitable ? AppColors.profit : AppColors.loss,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Today\'s P&L'.tr(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.outline),
          const SizedBox(height: 16),

          // 4-Stat Sub-Matrix
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Free Cash'.tr(),
                  value: _hideBalance ? '••••' : formatter.format(cash),
                  accentColor: const Color(0xFF00D09C),
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.outline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _buildMetricTile(
                    label: 'Spot Assets'.tr(),
                    value: _hideBalance ? '••••' : formatter.format(spotValue),
                    accentColor: const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Futures Margin'.tr(),
                  value: _hideBalance ? '••••' : formatter.format(futuresMargin),
                  accentColor: const Color(0xFFF3BA2F),
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.outline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _buildMetricTile(
                    label: 'Futures P&L'.tr(),
                    value: _hideBalance ? '••••' : '${futuresPnl >= 0 ? '+' : ''}${formatter.format(futuresPnl)}',
                    accentColor: futuresPnl >= 0 ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color accentColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor)),
            const SizedBox(width: 6),
            Text(label.tr(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. SEGMENTED TABS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSegmentedTabs({
    bool isStockMode = false,
    required int holdingsCount,
    required int futuresCount,
    required int ordersCount,
    required int tradesCount,
  }) {
    final tabs = [
      {'title': 'Overview', 'count': null},
      {'title': isStockMode ? 'Holdings' : 'Spot', 'count': holdingsCount},
      {'title': isStockMode ? 'Positions' : 'Futures', 'count': futuresCount},
      {'title': isStockMode ? 'Queued AMOs' : 'Orders', 'count': ordersCount},
      {'title': 'History', 'count': tradesCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          final item = tabs[index];
          final count = item['count'] as int?;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (AppColors.isDarkMode ? const Color(0xFF262B32) : AppColors.surface)
                      : (AppColors.isDarkMode ? const Color(0xFF16191D) : AppColors.surfaceAlt),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outline,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (item['title'] as String).tr(),
                      style: TextStyle(
                        color: isSelected ? AppColors.textPrimary : AppColors.subtle,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (count != null && count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (AppColors.isDarkMode ? const Color(0xFF38404B) : AppColors.outline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (AppColors.isDarkMode ? Colors.white : AppColors.textPrimary),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. OVERVIEW TAB (Donut Chart + Asset Distribution + Previews)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab({
    required double totalNetWorth,
    required List<MapEntry<String, double>> sortedAssets,
    required UserState userState,
    required List<Stock> market,
    required AppCurrencyFormatter formatter,
    bool isStockMode = false,
    required List<Holding> displayedHoldings,
    required List<FuturesPosition> activeFutures,
  }) {
    final pieSections = List.generate(sortedAssets.length, (i) {
      final isTouched = i == _touchedSectionIndex;
      final radius = isTouched ? 38.0 : 30.0;
      final asset = sortedAssets[i];
      final color = _getCoinColor(asset.key, i);

      return PieChartSectionData(
        color: color,
        value: asset.value,
        showTitle: false,
        radius: radius,
      );
    });

    MapEntry<String, double>? activeAsset;
    if (_touchedSectionIndex >= 0 && _touchedSectionIndex < sortedAssets.length) {
      activeAsset = sortedAssets[_touchedSectionIndex];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Asset Allocation Donut ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Asset Allocation'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tap slice to inspect'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedSectionIndex = -1;
                                return;
                              }
                              _touchedSectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 56,
                        sections: pieSections,
                      ),
                    ),
                    // Dynamic Center Info Widget
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activeAsset != null) ...[
                          if (activeAsset.key != 'CASH') ...[
                            CoinIcon(symbol: activeAsset.key.replaceAll(' (Futures)', '').replaceAll(' (Margin)', ''), size: 22),
                            const SizedBox(height: 3),
                          ],
                          Text(
                            activeAsset.key,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalNetWorth == 0
                                ? '0%'
                                : '${((activeAsset.value / totalNetWorth) * 100).toStringAsFixed(1)}%',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            _hideBalance ? '••••' : formatter.format(activeAsset.value),
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ] else ...[
                          const Text(
                            'PORTFOLIO',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sortedAssets.length}',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          const Text(
                            'Assets',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Interactive Distribution Rows
              ...List.generate(min(5, sortedAssets.length), (i) {
                final asset = sortedAssets[i];
                final color = _getCoinColor(asset.key, i);
                final percent = totalNetWorth == 0 ? 0.0 : (asset.value / totalNetWorth) * 100;
                final isSelected = _touchedSectionIndex == i;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _touchedSectionIndex = (_touchedSectionIndex == i) ? -1 : i;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (asset.key == 'CASH')
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.account_balance_wallet_rounded, size: 12, color: color),
                          )
                        else
                          CoinIcon(symbol: asset.key.replaceAll(' (Futures)', '').replaceAll(' (Margin)', ''), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            asset.key,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (percent / 100).clamp(0.0, 1.0),
                              backgroundColor: AppColors.surfaceAlt,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${percent.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hideBalance ? '••••' : formatter.format(asset.value),
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Quick Spot / Stock Holdings Preview ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isStockMode ? 'Stock Holdings' : 'Active Spot Holdings',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedTab = 1),
              child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (displayedHoldings.isEmpty)
          _buildEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            message: isStockMode ? 'No stock holdings yet.' : 'No Spot tokens yet.',
            actionLabel: isStockMode ? 'Explore Stocks' : 'Explore Spot Markets',
            onAction: () => ref.read(homeTabProvider.notifier).state = 1,
          )
        else
          ...displayedHoldings.take(3).map((h) => _buildSpotCard(h, market, formatter)),

        const SizedBox(height: 20),

        // ── Quick Futures / Margin Positions Preview ──────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isStockMode ? 'Open Margin Positions' : 'Open Futures Positions',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedTab = 2),
              child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeFutures.isEmpty)
          _buildEmptyState(
            icon: Icons.bolt_outlined,
            message: isStockMode ? 'No open margin positions.' : 'No open futures contracts.',
            actionLabel: isStockMode ? 'Trade 5x Margin' : 'Trade 100x Futures',
            onAction: () => ref.read(homeTabProvider.notifier).state = isStockMode ? 1 : 2,
          )
        else
          Column(
            children: activeFutures.take(3).map((pos) => _buildFuturesCard(pos, market, formatter)).toList(),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. HOLDINGS TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildHoldingsTab({
    required List<Holding> holdings,
    required List<Stock> market,
    required AppCurrencyFormatter formatter,
    bool isStockMode = false,
  }) {
    if (holdings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: isStockMode ? 'No stock holdings found.' : 'No crypto holdings found.',
        actionLabel: isStockMode ? 'Explore Stocks' : 'Buy Spot Crypto',
        onAction: () => ref.read(homeTabProvider.notifier).state = 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${holdings.length} Assets Held',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              'Holdings / P&L'.tr(),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...holdings.map((h) => _buildSpotCard(h, market, formatter)),
      ],
    );
  }

  Widget _buildSpotCard(Holding h, List<Stock> market, AppCurrencyFormatter formatter) {
    final stock = market.firstWhere(
      (s) => s.symbol == h.symbol,
      orElse: () => Stock(
        symbol: h.symbol,
        name: h.symbol,
        category: 'Crypto',
        currentPrice: h.averagePrice,
        previousClose: h.averagePrice,
        dayHigh: h.averagePrice,
        dayLow: h.averagePrice,
        volume: 0,
        history: [],
        candleHistory: [],
        about: '',
        supply: 0.0,
        rank: 0,
      ),
    );

    final currentVal = stock.currentPrice * h.quantity;
    final invested = h.averagePrice * h.quantity;
    final returnVal = currentVal - invested;
    final isProfitable = returnVal >= 0;
    final returnPercent = invested == 0 ? 0.0 : (returnVal / invested) * 100;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(stockSymbol: stock.symbol)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline, width: 1.0),
        ),
        child: Row(
          children: [
            // Coin Icon
            CoinIcon(symbol: stock.symbol, size: 42),
            const SizedBox(width: 14),
            // Name & Quantity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stock.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262B32),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF3B414B), width: 0.8),
                        ),
                        child: const Text(
                          'DELIVERY',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.0, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${h.quantity} ${stock.symbol} • Avg ${formatter.format(h.averagePrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Value & Return
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _hideBalance ? '••••' : formatter.format(currentVal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isProfitable ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _hideBalance
                          ? '••••'
                          : '${isProfitable ? '+' : ''}${formatter.format(returnVal)} (${returnPercent.toStringAsFixed(1)}%)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isProfitable ? AppColors.profit : AppColors.loss,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. FUTURES / MARGIN TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildFuturesTab({
    required List<FuturesPosition> positions,
    required List<Stock> market,
    required AppCurrencyFormatter formatter,
    bool isStockMode = false,
  }) {
    if (positions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bolt_outlined,
        message: isStockMode ? 'No open margin positions.' : 'No open futures positions.',
        actionLabel: isStockMode ? 'Trade 5x Margin' : 'Launch Futures Pro',
        onAction: () => ref.read(homeTabProvider.notifier).state = 2,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isStockMode ? '${positions.length} Active Margin Positions' : '${positions.length} Active Contracts',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              'Unrealized P&L / ROE%'.tr(),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...positions.map((pos) => _buildFuturesCard(pos, market, formatter)),
      ],
    );
  }

  Widget _buildFuturesCard(FuturesPosition pos, List<Stock> market, AppCurrencyFormatter formatter) {
    final stock = market.firstWhere(
      (s) => s.symbol == pos.symbol,
      orElse: () => Stock(
        symbol: pos.symbol,
        name: pos.symbol,
        category: 'Crypto',
        currentPrice: pos.entryPrice,
        previousClose: pos.entryPrice,
        dayHigh: pos.entryPrice,
        dayLow: pos.entryPrice,
        volume: 0,
        history: [],
        candleHistory: [],
        about: '',
        supply: 0.0,
        rank: 0,
      ),
    );

    final isLong = pos.side == OrderSide.buy;
    final priceDiff = stock.currentPrice - pos.entryPrice;
    final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
    final isProfitable = pnl >= 0;
    final roePercent = (pnl / pos.margin) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline, width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CoinIcon(symbol: pos.symbol, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pos.symbol.endsWith('.NS') || pos.symbol.endsWith('.BO') || pos.symbol.contains('/') || !pos.symbol.endsWith('USDT')
                      ? pos.symbol
                      : '${pos.symbol}-PERP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${pos.leverage}X ${isLong ? 'LONG' : 'SHORT'}',
                  style: TextStyle(
                    color: isLong ? AppColors.profit : AppColors.loss,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isProfitable ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _hideBalance ? '••••' : '${isProfitable ? '+' : ''}${roePercent.toStringAsFixed(2)}% ROE',
                  style: TextStyle(
                    color: isProfitable ? AppColors.profit : AppColors.loss,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildCompactMetric('Entry Price', formatter.format(pos.entryPrice)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetric('Mark Price', formatter.format(stock.currentPrice), alignment: CrossAxisAlignment.end),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactMetric('Margin', formatter.format(pos.margin)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactMetric(
                  'Unrealized P&L',
                  _hideBalance ? '••••' : '${isProfitable ? '+' : ''}${formatter.format(pnl)}',
                  valueColor: isProfitable ? AppColors.profit : AppColors.loss,
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.outline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(userProvider.notifier).closeFuturesPosition(pos, stock.currentPrice);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text('Position for ${pos.symbol} closed at market price.', style: TextStyle(color: AppColors.textPrimary)),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('Close Position', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final isStock = pos.symbol.endsWith('.NS') ||
                        pos.symbol.endsWith('.BO') ||
                        kStockAssets.any((a) => a.symbol == pos.symbol);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isStock
                            ? StockDetailScreen(stockSymbol: pos.symbol)
                            : FuturesProScreen(stockSymbol: pos.symbol),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.isDarkMode
                        ? const Color(0xFF1E293B)
                        : AppColors.primary.withValues(alpha: 0.14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Trade in Chart', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(
    String label,
    String value, {
    Color? valueColor,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.end ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5b. QUEUED AFTER-MARKET ORDERS TAB (AMO)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildAmoOrdersTab({
    required List<AmoOrder> orders,
    required AppCurrencyFormatter formatter,
  }) {
    final queued = orders.where((o) => o.status == 'queued').toList();
    if (queued.isEmpty) {
      return _buildEmptyState(
        icon: Icons.nightlight_outlined,
        message: 'No queued After-Market Orders (AMOs).',
        actionLabel: 'Browse Stocks',
        onAction: () => ref.read(homeTabProvider.notifier).state = 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${queued.length} Queued After-Market Orders',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...queued.map((order) {
          final isBuy = order.side == OrderSide.buy;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🌙', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBuy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBuy ? 'AMO BUY' : 'AMO SELL',
                              style: TextStyle(
                                color: isBuy ? AppColors.profit : AppColors.loss,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.symbol,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          if (order.leverage > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3BA2F).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${order.leverage}x Margin',
                                style: const TextStyle(color: Color(0xFFF3BA2F), fontSize: 9.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Qty: ${order.quantity} shares • Reserved: \$${order.reservedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final success = ref.read(userProvider.notifier).cancelAmoOrder(order.id);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('After-Market Order cancelled & funds refunded.'),
                          backgroundColor: Color(0xFFF3BA2F),
                        ),
                      );
                    }
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. ORDERS TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOrdersTab({
    required List<SpotLimitOrder> orders,
    required AppCurrencyFormatter formatter,
  }) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pending_actions_rounded,
        message: 'No pending limit orders.',
        actionLabel: 'Place a Spot Limit Order',
        onAction: () => ref.read(homeTabProvider.notifier).state = 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${orders.length} Open Orders',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...orders.map((order) {
          final isBuy = order.side == OrderSide.buy;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                CoinIcon(symbol: order.symbol, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBuy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBuy ? 'LIMIT BUY' : 'LIMIT SELL',
                              style: TextStyle(
                                color: isBuy ? AppColors.profit : AppColors.loss,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(order.symbol, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Target ${formatter.format(order.targetPrice)} • Qty ${order.quantity}',
                        style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final success = ref.read(userProvider.notifier).cancelSpotLimitOrder(order.id);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Limit order cancelled & funds refunded.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 7. HISTORY TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryTab({
    required List<Trade> trades,
    required AppCurrencyFormatter formatter,
  }) {
    if (trades.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        message: 'No trade transactions recorded yet.',
        actionLabel: 'Execute First Trade',
        onAction: () => ref.read(homeTabProvider.notifier).state = 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${trades.length} Completed Trades',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...trades.map((t) {
          final isBuy = t.side == OrderSide.buy;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                CoinIcon(symbol: t.symbol, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBuy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBuy ? 'BUY' : 'SELL',
                              style: TextStyle(
                                color: isBuy ? AppColors.profit : AppColors.loss,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.symbol,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${t.time.day}/${t.time.month}/${t.time.year} ${t.time.hour}:${t.time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatter.format(t.price),
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text('${t.quantity} qty', style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 8. EMPTY STATE COMPONENT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF262B32),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF64748B), size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
