import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import '../signals/signals_screen.dart';
import '../stock_detail/stock_detail_screen.dart';
import '../../core/app_translations.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  String _query = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(marketModeProvider);
    final isStockMode = mode == MarketMode.stocks;
    final market = isStockMode ? ref.watch(stockMarketProvider) : ref.watch(marketProvider);
    final userState = ref.watch(userProvider);
    
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final sectors = isStockMode
        ? [
            'All',
            'Favorites',
            'US Tech',
            'Semiconductors',
            'Crypto & FinTech',
            'Finance & Banks',
            'Consumer',
            'Energy & Industrial',
            'Healthcare',
            'ETFs',
          ]
        : ['All', 'Favorites', 'Layer 1', 'Layer 2', 'DeFi', 'Meme', 'AI', 'Gaming'];
    final effectiveFilter = sectors.contains(_filter) ? _filter : 'All';
    final shownStocks = market.where((s) {
      final q = _query.toLowerCase();
      final matchesSearch = s.symbol.toLowerCase().contains(q) || s.name.toLowerCase().contains(q);
      
      bool matchesFilter = false;
      if (effectiveFilter == 'All') {
        matchesFilter = true;
      } else if (effectiveFilter == 'Favorites') {
        matchesFilter = userState.profile.watchlist.contains(s.symbol);
      } else {
        matchesFilter = s.category == effectiveFilter;
      }
      
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
            // Search Bar & AI Signals Button & Arena Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.subtle, size: 19),
                          hintText: isStockMode ? 'Search stocks (AAPL, RELIANCE...)' : 'Search coin pairs (BTC, ETH...)'.tr(),
                          hintStyle: TextStyle(color: AppColors.subtle, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const SignalsScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.outline, width: 0.9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF1D9BF0), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'AI Signals'.tr(),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // AI Signals Advisory Banner (Twitter / X Card Style)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const SignalsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.outline, width: 1),
                        ),
                        child: const Center(
                          child: Icon(Icons.auto_awesome, color: Color(0xFF1D9BF0), size: 19),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AI Trade Signals & Analytics'.tr(),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live Buy/Sell signals • Safe Leverage desk'.tr(),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Text(
                          'Explore'.tr(),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Categories (Twitter Topic Pills)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sectors.length,
                itemBuilder: (context, index) {
                  final s = sectors[index];
                  final isSelected = _filter == s;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.outline,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        s.tr(),
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppColors.subtle,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // Table Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text('Name'.tr(), style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Chart'.tr(), style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Text('Price / 24h %'.tr(), style: const TextStyle(color: Color(0xFF848E9C), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // Stock List
            Expanded(
              child: shownStocks.isEmpty
                  ? Center(child: Text('No pairs found'.tr(), style: const TextStyle(color: Color(0xFF848E9C))))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 800) {
                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 8,
                              mainAxisExtent: 72.0, // Match the original itemExtent
                            ),
                            itemCount: shownStocks.length,
                            itemBuilder: (context, index) {
                              return _SpotRow(
                                stock: shownStocks[index],
                                formatter: formatter,
                                watched: userState.profile.watchlist.contains(shownStocks[index].symbol),
                                onWatch: () => ref.read(userProvider.notifier).toggleWatchlist(shownStocks[index].symbol),
                              );
                            },
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: shownStocks.length,
                          itemExtent: 72.0, // Dramatically improves scroll performance
                          itemBuilder: (context, index) {
                            return _SpotRow(
                              stock: shownStocks[index],
                              formatter: formatter,
                              watched: userState.profile.watchlist.contains(shownStocks[index].symbol),
                              onWatch: () => ref.read(userProvider.notifier).toggleWatchlist(shownStocks[index].symbol),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.stock, required this.formatter, required this.watched, required this.onWatch});
  final dynamic stock;
  final AppCurrencyFormatter formatter;
  final bool watched;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;
    
    // Safety check for empty history to prevent crashes
    final rawHistory = stock.history as List<double>;
    final history = rawHistory.length > 30 ? rawHistory.sublist(rawHistory.length - 30) : rawHistory;
    final hasHistory = history.isNotEmpty;
    
    double minPrice = 0;
    double maxPrice = 1;
    List<FlSpot> spots = [];

    if (hasHistory) {
      minPrice = history.reduce(min);
      maxPrice = history.reduce(max);
      if (minPrice == maxPrice) {
        minPrice -= 1;
        maxPrice += 1;
      }
      spots = history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StockDetailScreen(stockSymbol: stock.symbol)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Name Column
            SizedBox(
              width: 130,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onWatch,
                    child: Icon(watched ? Icons.star : Icons.star_border, size: 16, color: watched ? Colors.amber : const Color(0xFF848E9C)),
                  ),
                  const SizedBox(width: 8),
                  CoinIcon(symbol: stock.symbol, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                stock.symbol,
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (stock is Stock && stock.isStock) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: stock.isMarketOpen ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stock is Stock && stock.isStock ? stock.name : 'Vol ${NumberFormat.compact().format(stock.volume)}',
                          style: const TextStyle(color: Color(0xFF848E9C), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Sparkline Chart Column
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 30,
                child: hasHistory ? LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (history.length - 1).toDouble(),
                    minY: minPrice,
                    maxY: maxPrice,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.15,
                        color: color,
                        barWidth: 1.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ) : const SizedBox(),
              ),
            ),

            // Price Column
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stock is Stock && stock.isStock
                        ? '${stock.currency == "INR" ? "₹" : "\$"}${stock.currentPrice.toStringAsFixed(2)}'
                        : formatter.format(stock.currentPrice),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
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
}
