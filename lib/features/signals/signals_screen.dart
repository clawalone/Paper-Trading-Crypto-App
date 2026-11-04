import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../core/signal_engine.dart';
import '../../core/trading_view_chart.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_trade_sheet.dart';
import '../market/spot_trade_sheet.dart';
import '../profile/request_money_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum ChartMode { tradingView, candle }

class SignalsScreen extends ConsumerStatefulWidget {
  final String initialSymbol;

  const SignalsScreen({
    super.key,
    this.initialSymbol = 'BTC',
  });

  @override
  ConsumerState<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends ConsumerState<SignalsScreen> {
  late String _selectedSymbol;
  int _activeTab = 0; // 0: Spot, 1: Futures
  String _tvInterval = '60'; // '15', '60', '240', 'D'
  ChartMode _chartMode = ChartMode.tradingView;
  bool _isLoadingCandles = false;
  List<StockCandle>? _customCandles;
  double _chartHeight = 260.0;
  bool _isResizingChart = false;
  late ZoomPanBehavior _zoomPanBehavior;
  StreamSubscription<List<PurchaseDetails>>? _iapSub;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.xy,
    );
    _selectedSymbol = widget.initialSymbol.replaceAll('USDT', '');
    _fetchKlines(_selectedSymbol, _tvInterval);
    _iapSub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseStream,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    super.dispose();
  }

  Future<void> _handlePurchaseStream(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == 'pro_pack_500' ||
            purchase.productID == 'pro-pack-500' ||
            purchase.productID == 'pro_pack_50' ||
            purchase.productID == 'pro-pack-50') {
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          final paymentId = purchase.purchaseID ?? 'IAP_${DateTime.now().millisecondsSinceEpoch}';
          await ref.read(userProvider.notifier).unlockAiSignals(
                paymentId: paymentId,
                inrAmount: 4225.0,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.profit,
                content: Text('🎉 AI Signals & Safe Leverage Desk Unlocked! Lifetime access active.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _fetchKlines(String symbol, String interval) async {
    setState(() => _isLoadingCandles = true);
    final clean = symbol.replaceAll('USDT', '').toUpperCase();
    String binanceInterval = '1h';
    int limit = 96;

    switch (interval) {
      case '15':
        binanceInterval = '15m';
        limit = 96;
        break;
      case '60':
        binanceInterval = '1h';
        limit = 96;
        break;
      case '240':
        binanceInterval = '4h';
        limit = 80;
        break;
      case 'D':
        binanceInterval = '1d';
        limit = 60;
        break;
    }

    try {
      final res = await http.get(Uri.parse(
        'https://api.binance.com/api/v3/klines?symbol=${clean}USDT&interval=$binanceInterval&limit=$limit',
      ));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final candles = data.map((d) => StockCandle(
          date: DateTime.fromMillisecondsSinceEpoch(d[0] as int),
          open: double.parse(d[1].toString()) * CurrencyFormatters.usdToInr,
          high: double.parse(d[2].toString()) * CurrencyFormatters.usdToInr,
          low: double.parse(d[3].toString()) * CurrencyFormatters.usdToInr,
          close: double.parse(d[4].toString()) * CurrencyFormatters.usdToInr,
          volume: double.parse(d[5].toString()),
        )).toList();

        if (mounted) {
          setState(() {
            _customCandles = candles;
            _isLoadingCandles = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingCandles = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCandles = false);
    }
  }

  void _onSelectCoin(Stock stock) {
    final clean = stock.symbol.replaceAll('USDT', '');
    setState(() {
      _selectedSymbol = clean;
      _customCandles = null;
    });
    _fetchKlines(clean, _tvInterval);
  }

  void _showCoinPicker(List<Stock> market) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CoinPickerSheet(
        stocks: market,
        currentSymbol: _selectedSymbol,
        onSelected: (stock) {
          Navigator.pop(ctx);
          _onSelectCoin(stock);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final userState = ref.watch(userProvider);
    final isUnlocked = userState.profile.isAiSignalsUnlocked;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    // Resolve current selected stock
    final clean = _selectedSymbol.toUpperCase();
    final stock = market.firstWhere(
      (s) => s.symbol.toUpperCase() == clean || s.symbol.toUpperCase().startsWith(clean),
      orElse: () => market.isNotEmpty ? market.first : const Stock(
        symbol: 'BTC',
        name: 'Bitcoin',
        category: 'Layer 1',
        currentPrice: 0.0,
        previousClose: 0.0,
        dayHigh: 0.0,
        dayLow: 0.0,
        volume: 0,
        history: [],
        candleHistory: [],
        about: '',
        supply: 0,
        rank: 1,
      ),
    );

    // Run technical analysis engine
    final analysis = SignalEngine.analyze(stock, customCandles: _customCandles);
    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () => _showCoinPicker(market),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoinIcon(symbol: stock.symbol, size: 24),
                const SizedBox(width: 8),
                Text(
                  stock.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          // Currency picker pill
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PRICE HEADER ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatter.format(stock.currentPrice),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '24h Vol: ${NumberFormat.compact().format(stock.volume)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // AI Confidence pill / Pro Unlock status
                  InkWell(
                    onTap: isUnlocked ? null : () => _showUnlockModal(context, formatter),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isUnlocked
                              ? [
                                  AppColors.primary.withValues(alpha: 0.25),
                                  const Color(0xFF9945FF).withValues(alpha: 0.25),
                                ]
                              : [
                                  const Color(0xFFFFB800).withValues(alpha: 0.25),
                                  const Color(0xFFFF6B00).withValues(alpha: 0.25),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUnlocked
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : const Color(0xFFFFB800),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUnlocked ? Icons.workspace_premium_rounded : Icons.lock_rounded,
                            color: isUnlocked ? AppColors.primary : const Color(0xFFFFB800),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isUnlocked ? 'PRO UNLOCKED ⚡' : 'PRO LOCKED • \$50',
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : const Color(0xFFFFB800),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── CHART SECTION ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildIntervalBtn('15m', '15'),
                  _buildIntervalBtn('1H', '60'),
                  _buildIntervalBtn('4H', '240'),
                  _buildIntervalBtn('1D', 'D'),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _chartMode = _chartMode == ChartMode.tradingView
                            ? ChartMode.candle
                            : ChartMode.tradingView;
                      });
                    },
                    icon: Icon(
                      _chartMode == ChartMode.tradingView ? Icons.candlestick_chart : Icons.show_chart,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    tooltip: 'Toggle Chart Engine',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => TradingViewFullScreenPage(
                            symbol: stock.symbol,
                            initialInterval: _tvInterval,
                            isFutures: _activeTab == 1,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 22),
                    tooltip: 'Fullscreen / Expand Chart',
                  ),
                ],
              ),
            ),

            Container(
              height: _chartHeight,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141A21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildChart(stock),
            ),

            // Draggable Chart Height Resize Handle
            _buildChartResizeHandle(),

            const SizedBox(height: 6),

            // ── MODE SELECTOR: SPOT VS FUTURES ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF181F28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: _activeTab == 0
                                ? LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.9),
                                      const Color(0xFF00C087),
                                    ],
                                  )
                                : null,
                            color: _activeTab == 0 ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeTab == 0
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.currency_bitcoin_rounded,
                                size: 18,
                                color: _activeTab == 0 ? Colors.black : Colors.white60,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Spot Advice',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: _activeTab == 0 ? Colors.black : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: _activeTab == 1
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF9945FF),
                                      Color(0xFF14F195),
                                    ],
                                  )
                                : null,
                            color: _activeTab == 1 ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeTab == 1
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF9945FF).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: _activeTab == 1 ? Colors.black : Colors.white60,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Futures Advice',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: _activeTab == 1 ? Colors.black : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── ADVISORY CONTENT ────────────────────────────────────────────
            if (!isUnlocked)
              _buildProPaywallCard(stock, analysis, formatter)
            else if (_activeTab == 0)
              _buildSpotAdviceSection(stock, analysis, formatter)
            else
              _buildFuturesAdviceSection(stock, analysis, formatter),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── PRO PAYWALL CARD ($50 UNLOCK) ─────────────────────────────────────────

  Widget _buildProPaywallCard(Stock stock, TechnicalAnalysisResult analysis, AppCurrencyFormatter formatter) {
    final localizedPrice = formatter.format(50.0 * CurrencyFormatters.usdToInr);
    final userCurrency = ref.read(userProvider).profile.preferredCurrency;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E192B), Color(0xFF141A21), Color(0xFF1B1B15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB800).withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Crown
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB800), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'PRO TRADER FEATURE 🔒',
                          style: TextStyle(
                            color: Color(0xFFFFB800),
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'AI Signals & Safe Leverage Desk',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Price Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'One-Time Unlock Fee',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                '\$50 USD',
                                style: TextStyle(
                                  color: Color(0xFFFFB800),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (userCurrency != 'USD') ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(~$localizedPrice)',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.profit.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.profit.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'LIFETIME ACCESS',
                      style: TextStyle(
                        color: AppColors.profit,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Get institutional-grade technical algorithmic trading insights on every coin:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),

            const SizedBox(height: 12),

            _buildBenefitRow('⚡ Safe Leverage Advisor', 'Dynamic ATR-based safe leverage advice to avoid liquidation crashes.'),
            _buildBenefitRow('🎯 Spot Buy & Sell Signals', 'Algorithm calculates precise entry ranges, take profit, and stop loss.'),
            _buildBenefitRow('📈 Futures Long & Short Bias', 'Multi-timeframe RSI, EMA 20/50 golden cross & MACD surge filtering.'),
            _buildBenefitRow('🛡️ Real-Time Liquidation Buffer', 'Instant mathematical distance buffer to your liquidation price.'),
            _buildBenefitRow('🌐 All 50+ Global Crypto Pairs', 'Unlock full unrestricted access across all markets with zero recurring subscription.'),

            const SizedBox(height: 20),

            // Unlock Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _showUnlockModal(context, formatter),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: const Color(0xFFFFB800).withValues(alpha: 0.5),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB800), Color(0xFFFF8A00)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Unlock Pro Access — \$50 USD',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  TextButton(
                    onPressed: () => _restorePurchase(context),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text(
                      'Restore Purchase',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text('•', style: TextStyle(color: Colors.white24)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RequestMoneyScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text(
                      'Get with \$50 Pro Pack (+1M balance) →',
                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
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

  Widget _buildBenefitRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFFFFB800), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, height: 1.35),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(
                    text: desc,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchase(BuildContext context) async {
    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (available) {
        await iap.restorePurchases();
      }
    } catch (_) {}

    final isProfileUnlocked = ref.read(userProvider).profile.isAiSignalsUnlocked;
    if (isProfileUnlocked) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.profit,
            content: Text('Purchase verified! AI Signals & Safe Leverage Desk are unlocked.'),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('No previous active \$50 purchase was found on this account.'),
          ),
        );
      }
    }
  }

  void _showUnlockModal(BuildContext context, AppCurrencyFormatter formatter) {
    final localizedPrice = formatter.format(50.0 * CurrencyFormatters.usdToInr);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _UnlockSignalsSheet(
        formatter: formatter,
        localizedPrice: localizedPrice,
        onUnlocked: () async {
          await ref.read(userProvider.notifier).unlockAiSignals();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.profit,
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎉 AI Signals & Safe Leverage Desk Unlocked! Lifetime access active.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }

  // ── SPOT ADVICE SECTION ───────────────────────────────────────────────────

  Widget _buildSpotAdviceSection(Stock stock, TechnicalAnalysisResult analysis, AppCurrencyFormatter formatter) {
    final advice = analysis.spotAdvice;
    final isBuy = advice.action == SignalAction.strongBuy || advice.action == SignalAction.buy;
    final isSell = advice.action == SignalAction.strongSell || advice.action == SignalAction.sell;

    final Color badgeColor = isBuy
        ? AppColors.profit
        : (isSell ? AppColors.loss : AppColors.warning);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Core Signal Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            advice.title,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${advice.confidenceScore.toStringAsFixed(0)}% Confidence',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  advice.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Price Strategy Breakdown Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Spot Price Targets',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Optimal Entry Zone',
                        value: '${formatter.format(advice.entryZoneLow)} - ${formatter.format(advice.entryZoneHigh)}',
                        icon: Icons.login_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Take Profit Target',
                        value: '${formatter.format(advice.targetPrice)} (+${advice.targetGainPct.toStringAsFixed(1)}%)',
                        icon: Icons.flag_rounded,
                        color: AppColors.profit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Stop Loss Target',
                        value: '${formatter.format(advice.stopLossPrice)} (-${advice.stopLossPct.toStringAsFixed(1)}%)',
                        icon: Icons.shield_rounded,
                        color: AppColors.loss,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Technical Indicator Confluence
          _buildIndicatorBreakdown(analysis),

          const SizedBox(height: 24),

          // 4. Action Buttons
          Row(
            children: [
              Expanded(
                flex: isBuy ? 6 : 4,
                child: FilledButton(
                  onPressed: () => _openSpotSheet(stock, OrderSide.buy, suggestedPrice: advice.entryZoneHigh),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.profit,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Buy ${stock.symbol} Spot',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isSell ? 6 : 4,
                child: FilledButton(
                  onPressed: () => _openSpotSheet(stock, OrderSide.sell),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.loss,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sell_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Sell ${stock.symbol} Spot',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FUTURES ADVICE SECTION ────────────────────────────────────────────────

  Widget _buildFuturesAdviceSection(Stock stock, TechnicalAnalysisResult analysis, AppCurrencyFormatter formatter) {
    final advice = analysis.futuresAdvice;
    final isLong = advice.bias == FuturesBias.long;
    final isShort = advice.bias == FuturesBias.short;

    final Color directionColor = isLong
        ? AppColors.profit
        : (isShort ? AppColors.loss : AppColors.warning);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Bias & Direction Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: directionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: directionColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isLong
                          ? Icons.arrow_circle_up_rounded
                          : (isShort ? Icons.arrow_circle_down_rounded : Icons.pause_circle_rounded),
                      color: directionColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLong
                            ? 'RECOMMENDED: GO LONG'
                            : (isShort ? 'RECOMMENDED: GO SHORT' : 'BIAS: NEUTRAL / WAIT'),
                        style: TextStyle(
                          color: directionColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${advice.confidenceScore.toStringAsFixed(0)}% Score',
                      style: TextStyle(
                        color: directionColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isLong
                      ? 'Upward trend continuation detected. Bulls in control with favorable asymmetric upside.'
                      : (isShort
                          ? 'Bearish breakdown or rejection from key resistance. Shorting favored with tight stops.'
                          : 'Market is in chop/consolidation. Wait for a high-volume breakout before entering futures.'),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Safe Leverage Recommendation Card (Crucial User Requirement!)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1B2E), Color(0xFF141A21)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF9945FF).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: Color(0xFF9945FF), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Safe Leverage Advisor',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9945FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9945FF)),
                      ),
                      child: Text(
                        '⚡ ${advice.recommendedLeverage}x REC.',
                        style: const TextStyle(
                          color: Color(0xFF9945FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  advice.leverageRationale,
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.health_and_safety_outlined, color: AppColors.profit, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Est. Liquidation Distance: ~${advice.liquidationDistancePct.toStringAsFixed(1)}% safe buffer (${formatter.format(advice.estimatedLiquidationPrice)})',
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Futures Execution Targets Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Order Parameters',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'R:R = 1 : ${advice.riskRewardRatio}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Entry Reference',
                        value: formatter.format(advice.entryPrice),
                        icon: Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Take Profit 1 (Scalp)',
                        value: formatter.format(advice.targetPrice1),
                        icon: Icons.looks_one_rounded,
                        color: AppColors.profit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Take Profit 2 (Swing)',
                        value: formatter.format(advice.targetPrice2),
                        icon: Icons.looks_two_rounded,
                        color: AppColors.profit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Stop Loss (Invalidation)',
                        value: formatter.format(advice.stopLossPrice),
                        icon: Icons.cancel_outlined,
                        color: AppColors.loss,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Indicator Confluence
          _buildIndicatorBreakdown(analysis),

          const SizedBox(height: 24),

          // 5. One-Tap Futures Action Button
          FilledButton(
            onPressed: () => _openFuturesSheet(
              stock,
              isShort ? OrderSide.sell : OrderSide.buy,
              advice.recommendedLeverage,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isShort ? AppColors.loss : AppColors.profit,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Open ${advice.recommendedLeverage}x ${isShort ? "SHORT" : "LONG"} Position',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────

  Widget _buildParameterTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorBreakdown(TechnicalAnalysisResult analysis) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Technical Indicators',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildIndicatorMiniCard(
                  'RSI (14)',
                  analysis.rsi.toStringAsFixed(1),
                  analysis.rsi < 35
                      ? 'Oversold (Rebound)'
                      : (analysis.rsi > 65 ? 'Overbought (Caution)' : 'Healthy Zone'),
                  analysis.rsi < 45 ? AppColors.profit : (analysis.rsi > 65 ? AppColors.loss : Colors.white70),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIndicatorMiniCard(
                  'MACD',
                  analysis.macdHist >= 0 ? '+Bullish' : '-Bearish',
                  analysis.macdHist >= 0 ? 'Expanding upward' : 'Downward velocity',
                  analysis.macdHist >= 0 ? AppColors.profit : AppColors.loss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildIndicatorMiniCard(
                  'EMA 20 / 50',
                  analysis.ema20 >= analysis.ema50 ? 'Golden Trend' : 'Death Trend',
                  analysis.ema20 >= analysis.ema50 ? 'EMA 20 > EMA 50' : 'EMA 20 < EMA 50',
                  analysis.ema20 >= analysis.ema50 ? AppColors.profit : AppColors.loss,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIndicatorMiniCard(
                  'ATR Volatility',
                  '${analysis.atrPct.toStringAsFixed(1)}%',
                  analysis.atrPct > 4 ? 'High Fluctuations' : 'Steady Consolidation',
                  analysis.atrPct > 4 ? Colors.orangeAccent : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorMiniCard(String title, String mainVal, String subVal, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            mainVal,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: accent),
          ),
          const SizedBox(height: 2),
          Text(
            subVal,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalBtn(String label, String interval) {
    final isSelected = _tvInterval == interval;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() => _tvInterval = interval);
          _fetchKlines(_selectedSymbol, interval);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2B3139) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.white60,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(Stock stock) {
    if (_chartMode == ChartMode.tradingView) {
      return TradingViewChart(
        key: ValueKey('tv_signals_${stock.symbol}_${_activeTab == 1}_$_tvInterval'),
        symbol: stock.symbol,
        isFutures: _activeTab == 1,
        initialInterval: _tvInterval,
        chartStyle: '1',
        enableDrawingToolbar: false,
        showTopToolbar: false,
        showDateRanges: false,
        showRsi: false,
        showFullscreenAction: false,
        onToggleNative: () => setState(() => _chartMode = ChartMode.candle),
      );
    }

    final candles = _customCandles ?? stock.candleHistory;
    if (candles.isEmpty || _isLoadingCandles) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      );
    }

    return SfCartesianChart(
      zoomPanBehavior: _zoomPanBehavior,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      primaryXAxis: const DateTimeAxis(
        isVisible: true,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
        majorGridLines: MajorGridLines(width: 0),
        axisLine: AxisLine(width: 0),
      ),
      primaryYAxis: const NumericAxis(
        isVisible: true,
        opposedPosition: true,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
        majorGridLines: MajorGridLines(width: 0.5, color: Colors.white10),
        axisLine: AxisLine(width: 0),
      ),
      series: <CartesianSeries<StockCandle, DateTime>>[
        CandleSeries<StockCandle, DateTime>(
          dataSource: candles,
          xValueMapper: (s, _) => s.date,
          lowValueMapper: (s, _) => s.low,
          highValueMapper: (s, _) => s.high,
          openValueMapper: (s, _) => s.open,
          closeValueMapper: (s, _) => s.close,
          bullColor: AppColors.profit,
          bearColor: AppColors.loss,
          enableSolidCandles: true,
        ),
      ],
    );
  }

  Widget _buildChartResizeHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => setState(() => _isResizingChart = true),
      onVerticalDragEnd: (_) => setState(() => _isResizingChart = false),
      onVerticalDragCancel: () => setState(() => _isResizingChart = false),
      onVerticalDragUpdate: (details) {
        setState(() {
          _chartHeight = (_chartHeight + details.delta.dy).clamp(180.0, 580.0);
        });
      },
      onDoubleTap: () {
        setState(() {
          _chartHeight = 260.0;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(
          width: double.infinity,
          height: 24,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isResizingChart ? 56 : 40,
            height: _isResizingChart ? 5 : 4,
            decoration: BoxDecoration(
              color: _isResizingChart ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
              boxShadow: _isResizingChart
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  void _openSpotSheet(Stock stock, OrderSide side, {double? suggestedPrice}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpotTradeSheet(
        stock: stock,
        initialSide: side,
        suggestedLimitPrice: suggestedPrice,
      ),
    );
  }

  void _openFuturesSheet(Stock stock, OrderSide side, int leverage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FuturesTradeSheet(
        stock: stock,
        initialSide: side,
        initialLeverage: leverage,
      ),
    );
  }
}

// ── COIN PICKER MODAL SHEET ─────────────────────────────────────────────────

class _CoinPickerSheet extends StatefulWidget {
  final List<Stock> stocks;
  final String currentSymbol;
  final ValueChanged<Stock> onSelected;

  const _CoinPickerSheet({
    required this.stocks,
    required this.currentSymbol,
    required this.onSelected,
  });

  @override
  State<_CoinPickerSheet> createState() => _CoinPickerSheetState();
}

class _CoinPickerSheetState extends State<_CoinPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.stocks.where((s) {
      final q = _search.toLowerCase();
      return s.symbol.toLowerCase().contains(q) || s.name.toLowerCase().contains(q);
    }).toList();

    return Material(
      color: const Color(0xFF141A21),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Crypto Pair',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          TextField(
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              hintText: 'Search coin or symbol (e.g. BTC, ETH, SOL)...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  final isSelected = s.symbol.toUpperCase().startsWith(widget.currentSymbol.toUpperCase());
                  final good = s.changePercentage >= 0;
                  return ListTile(
                    leading: CoinIcon(symbol: s.symbol, size: 28),
                    title: Row(
                      children: [
                        Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(width: 8),
                        Text(s.category, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    subtitle: Text(s.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (good ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${good ? '+' : ''}${s.changePercentage.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: good ? AppColors.profit : AppColors.loss,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                        ],
                      ],
                    ),
                    onTap: () => widget.onSelected(s),
                  );
                },
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

// ── UNLOCK SIGNALS MODAL SHEET ($50) ────────────────────────────────────────

class _UnlockSignalsSheet extends ConsumerStatefulWidget {
  final AppCurrencyFormatter formatter;
  final String localizedPrice;
  final VoidCallback onUnlocked;

  const _UnlockSignalsSheet({
    required this.formatter,
    required this.localizedPrice,
    required this.onUnlocked,
  });

  @override
  ConsumerState<_UnlockSignalsSheet> createState() => _UnlockSignalsSheetState();
}

class _UnlockSignalsSheetState extends ConsumerState<_UnlockSignalsSheet> {
  bool _isProcessing = false;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSub;

  @override
  void initState() {
    super.initState();
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (_) {
        if (mounted) setState(() => _isProcessing = false);
      },
    );
  }

  @override
  void dispose() {
    _purchaseSub.cancel();
    super.dispose();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        if (mounted) {
          setState(() => _isProcessing = false);
          widget.onUnlocked();
        }
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.loss,
              content: Text('Payment Error: ${purchase.error?.message ?? "Cancelled"}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _buyWithPlay() async {
    setState(() => _isProcessing = true);
    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      debugPrint('[Play Billing] isAvailable: $available');

      if (!available) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showUnavailableDialog(
            title: 'Play Billing Unavailable',
            message: 'Google Play Billing service could not be connected. Please verify that Google Play Services and the Play Store app are installed and active on this device.',
            canSimulateInDebug: kDebugMode,
          );
        }
        return;
      }

      final response = await iap.queryProductDetails({
        'pro_pack_500',
        'pro-pack-500',
        'pro_pack_50',
        'pro-pack-50',
      });
      debugPrint('[Play Billing] Query products: found=${response.productDetails.map((p) => p.id).toList()}, notFound=${response.notFoundIDs}, error=${response.error?.message}');

      if (response.productDetails.isNotEmpty) {
        ProductDetails selectedProduct = response.productDetails.first;
        for (final p in response.productDetails) {
          if (p.id == 'pro_pack_500' ||
              p.id == 'pro-pack-500' ||
              p.id == 'pro_pack_50' ||
              p.id == 'pro-pack-50') {
            selectedProduct = p;
            break;
          }
        }
        final purchaseParam = PurchaseParam(productDetails: selectedProduct);
        await iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
          final errorDetail = response.error != null
              ? 'Play Store reported error: ${response.error!.message} (${response.error!.code})'
              : 'Product "pro_pack_500" was not returned by Google Play Store (IDs not found: ${response.notFoundIDs}).\n\n'
                'Please ensure:\n'
                '1. The in-app product "pro_pack_500" is set to "Active" in Google Play Console.\n'
                '2. Your Google account is added under "License Testing".\n'
                '3. You accepted the Internal Testing opt-in invitation on this device.';

          _showUnavailableDialog(
            title: 'Product Unavailable in Play Store',
            message: errorDetail,
            canSimulateInDebug: kDebugMode,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('[Play Billing] Exception during purchase: $e\n$stack');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showUnavailableDialog(
          title: 'Billing Error',
          message: 'An unexpected error occurred while communicating with Google Play Billing:\n$e',
          canSimulateInDebug: kDebugMode,
        );
      }
    }
  }

  void _showUnavailableDialog({
    required String title,
    required String message,
    bool canSimulateInDebug = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFB800)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          if (canSimulateInDebug)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onUnlocked();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFB800),
                side: const BorderSide(color: Color(0xFFFFB800)),
              ),
              child: const Text('DEV: Simulate Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: Colors.black,
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141A21),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB800), size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unlock AI Signals & Safe Leverage Desk',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'One-time payment of \$50 USD (~${widget.localizedPrice}) for lifetime access across all crypto pairs.',
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Primary: Google Play Checkout ($50 USD)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _buyWithPlay,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.payment_rounded, color: Colors.black),
              label: Text(
                _isProcessing ? 'Connecting...' : 'Pay with Google Play (\$50 USD)',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary: Get via $50 Pro Trader Pack
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestMoneyScreen()),
                );
              },
              icon: const Icon(Icons.stars_rounded, color: AppColors.primary, size: 18),
              label: const Text(
                'Get with Pro Trader Pack (\$50) + \$1M Capital →',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
