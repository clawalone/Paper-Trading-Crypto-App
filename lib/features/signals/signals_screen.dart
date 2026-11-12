import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../core/currency_picker.dart';
import '../../core/signal_engine.dart';
import '../../core/trading_view_chart.dart';
import '../../core/rewarded_ad_manager.dart';
import '../../data/market_provider.dart';
import '../../data/stock_market_provider.dart';
import '../../data/market_mode_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_trade_sheet.dart';
import '../market/spot_trade_sheet.dart';
import '../stock_detail/stock_trade_sheet.dart';
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
  static final Set<String> _sessionUnlockedSymbols = {};
  bool _isWatchingAd = false;
  late String _selectedSymbol;
  int _mainTab = 0; // 0: AI Setup, 1: Market Scanner, 2: Track Record
  int _activeTab = 0; // 0: Spot, 1: Futures
  String _scannerFilter = 'All';
  String _trackFilter = 'All'; // 'All', 'Selected', 'Wins', 'Losses'
  bool _isLoadingTrackAudit = false;
  final Map<String, List<StockCandle>> _stockBacktestCandles = {};
  final Map<String, List<StockCandle>> _cryptoBacktestCandles = {};
  DateTime? _stockBacktestFetchedAt;
  DateTime? _cryptoBacktestFetchedAt;
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
    final initialMode = ref.read(marketModeProvider);
    if (widget.initialSymbol == 'BTC' && initialMode == MarketMode.stocks) {
      final stocks = ref.read(stockMarketProvider);
      _selectedSymbol = stocks.isNotEmpty ? stocks.first.symbol : 'NVDA';
    } else {
      _selectedSymbol = widget.initialSymbol.replaceAll('USDT', '');
    }
    _fetchKlines(_selectedSymbol, _tvInterval);
    _iapSub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseStream,
      onError: (_) {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userState = ref.read(userProvider);
      if (!userState.profile.isAiSignalsUnlocked) {
        RewardedAdManager.instance.preload();
      }
    });
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

  Future<void> _watchAdToUnlockSignal(String symbol) async {
    if (_isWatchingAd) return;
    final cleanSym = symbol.replaceAll('USDT', '').toUpperCase();
    setState(() => _isWatchingAd = true);

    final success = await RewardedAdManager.instance.playRewardedSequence(
      context: context,
      requiredAds: 1,
      onProgress: (current, total) {},
    );

    if (!mounted) return;
    setState(() => _isWatchingAd = false);

    if (success) {
      setState(() {
        _sessionUnlockedSymbols.add(cleanSym);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🎉 $cleanSym AI Signal unlocked for this session!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00C087),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final lastCode = RewardedAdManager.instance.lastLoadErrorCode;
      final String errorMsg;
      if (lastCode == 3) {
        errorMsg = 'No ad available right now. Google AdMob is filling inventory. Please try again shortly.';
      } else {
        errorMsg = 'Ad was not completed. Signal remains locked.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.loss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static const List<String> _auditStockSymbols = [
    'AAPL', 'NVDA', 'TSLA', 'MSFT', 'AMZN',
    'GOOGL', 'META', 'AMD', 'NFLX', 'SPY',
    'QQQ', 'COIN', 'PLTR', 'JPM', 'AVGO',
  ];

  static const List<String> _auditCryptoSymbols = [
    'BTC', 'ETH', 'SOL', 'BNB', 'XRP',
    'ADA', 'AVAX', 'DOGE', 'LINK', 'SUI',
    'NEAR', 'LTC', 'UNI', 'APT', 'DOT',
  ];

  Future<List<StockCandle>?> _fetchYahooCandles(
    String symbol, {
    required String yInterval,
    required String yRange,
  }) async {
    try {
      final querySym = symbol == 'SQ' ? 'XYZ' : symbol;
      final url =
          'https://query1.finance.yahoo.com/v8/finance/chart/$querySym?interval=$yInterval&range=$yRange';
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = json['chart']?['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final data = result[0] as Map<String, dynamic>;
      final timestamps = (data['timestamp'] as List?)?.cast<int>() ?? [];
      final quote = data['indicators']?['quote']?[0] as Map<String, dynamic>?;
      if (quote == null || timestamps.isEmpty) return null;

      final opens = quote['open'] as List?;
      final highs = quote['high'] as List?;
      final lows = quote['low'] as List?;
      final closes = quote['close'] as List?;
      final volumes = quote['volume'] as List?;

      final List<StockCandle> candles = [];
      final count = min(timestamps.length, closes?.length ?? 0);
      for (int i = 0; i < count; i++) {
        final c = (closes?[i] as num?)?.toDouble();
        if (c == null || c.isNaN) continue;
        final o = (opens != null && opens.length > i && opens[i] != null)
            ? (opens[i] as num).toDouble()
            : c;
        final h = (highs != null && highs.length > i && highs[i] != null)
            ? (highs[i] as num).toDouble()
            : max(o, c);
        final l = (lows != null && lows.length > i && lows[i] != null)
            ? (lows[i] as num).toDouble()
            : min(o, c);
        final v = (volumes != null && volumes.length > i && volumes[i] != null)
            ? (volumes[i] as num).toDouble()
            : 10000.0;
        candles.add(
          StockCandle(
            date: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
            open: o,
            high: h,
            low: l,
            close: c,
            volume: v,
          ),
        );
      }
      return candles.isNotEmpty ? candles : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<StockCandle>?> _fetchBinanceCandles(
    String cleanSymbol, {
    required String interval,
    required int limit,
  }) async {
    const hosts = ['data-api.binance.vision', 'api.binance.com'];
    for (final host in hosts) {
      try {
        final uri = Uri.parse(
          'https://$host/api/v3/klines?symbol=${cleanSymbol}USDT&interval=$interval&limit=$limit',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          final candles = data
              .map(
                (d) => StockCandle(
                  date: DateTime.fromMillisecondsSinceEpoch(d[0] as int),
                  open: double.parse(d[1].toString()) * CurrencyFormatters.usdToInr,
                  high: double.parse(d[2].toString()) * CurrencyFormatters.usdToInr,
                  low: double.parse(d[3].toString()) * CurrencyFormatters.usdToInr,
                  close: double.parse(d[4].toString()) * CurrencyFormatters.usdToInr,
                  volume: double.parse(d[5].toString()),
                ),
              )
              .toList();
          if (candles.isNotEmpty) return candles;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _fetchKlines(String symbol, String interval) async {
    setState(() => _isLoadingCandles = true);
    final clean = symbol.replaceAll('USDT', '').toUpperCase();

    final isStock = symbol.endsWith('.NS') ||
        symbol.endsWith('.BO') ||
        symbol.startsWith('^') ||
        kStockAssets.any((a) => a.symbol == symbol || a.symbol == clean);

    if (isStock) {
      String yInterval = '60m';
      String yRange = '1mo';
      switch (interval) {
        case '15':
          yInterval = '15m';
          yRange = '5d';
          break;
        case '60':
          yInterval = '60m';
          yRange = '1mo';
          break;
        case '240':
          yInterval = '60m';
          yRange = '3mo';
          break;
        case 'D':
          yInterval = '1d';
          yRange = '1y';
          break;
      }

      final candles = await _fetchYahooCandles(
        symbol,
        yInterval: yInterval,
        yRange: yRange,
      );
      if (candles != null && candles.isNotEmpty && mounted) {
        setState(() {
          _customCandles = candles;
          if (interval == '60') {
            _stockBacktestCandles[clean] = candles;
          }
          _isLoadingCandles = false;
        });
        return;
      }

      // Fallback to stock's own candleHistory from stockMarketProvider
      final stockMarket = ref.read(stockMarketProvider);
      final s = stockMarket.where((item) => item.symbol == symbol).firstOrNull;
      if (mounted) {
        setState(() {
          _customCandles = s?.candleHistory;
          _isLoadingCandles = false;
        });
      }
      return;
    }

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

    final candles = await _fetchBinanceCandles(
      clean,
      interval: binanceInterval,
      limit: limit,
    );
    if (mounted) {
      setState(() {
        if (candles != null && candles.isNotEmpty) {
          _customCandles = candles;
        }
        _isLoadingCandles = false;
      });
    }
  }

  Future<void> _ensureTrackRecordCandles({
    required bool isStock,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingTrackAudit) return;

    final lastFetched =
        isStock ? _stockBacktestFetchedAt : _cryptoBacktestFetchedAt;
    final cache = isStock ? _stockBacktestCandles : _cryptoBacktestCandles;
    final selectedClean = _selectedSymbol.replaceAll('USDT', '').toUpperCase();
    final needsSelected = selectedClean.isNotEmpty && !cache.containsKey(selectedClean);

    if (!forceRefresh &&
        lastFetched != null &&
        cache.length >= 10 &&
        !needsSelected &&
        DateTime.now().difference(lastFetched) < const Duration(minutes: 5)) {
      return;
    }

    setState(() => _isLoadingTrackAudit = true);

    try {
      final baseList = isStock ? _auditStockSymbols : _auditCryptoSymbols;
      final targets = <String>{...baseList};
      if (selectedClean.isNotEmpty) targets.add(selectedClean);
      final symbols = targets.toList();

      const batchSize = 8;
      for (int start = 0; start < symbols.length; start += batchSize) {
        final batch = symbols.skip(start).take(batchSize).toList();
        final results = await Future.wait(
          batch.map((sym) async {
            if (!forceRefresh && (cache[sym]?.length ?? 0) >= 55) {
              return MapEntry<String, List<StockCandle>?>(sym, cache[sym]);
            }
            final candles = isStock
                ? await _fetchYahooCandles(sym, yInterval: '1h', yRange: '1mo')
                : await _fetchBinanceCandles(sym, interval: '1h', limit: 200);
            return MapEntry(sym, candles);
          }),
        );
        for (final entry in results) {
          if (entry.value != null && entry.value!.isNotEmpty) {
            cache[entry.key] = entry.value!;
          }
        }
      }

      if (isStock) {
        _stockBacktestFetchedAt = DateTime.now();
      } else {
        _cryptoBacktestFetchedAt = DateTime.now();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrackAudit = false);
      }
    }
  }

  void _onSelectCoin(Stock stock) {
    final clean = stock.symbol.replaceAll('USDT', '');
    setState(() {
      _selectedSymbol = clean;
      _customCandles = null;
    });
    _fetchKlines(clean, _tvInterval);
    if (_mainTab == 2) {
      _ensureTrackRecordCandles(isStock: ref.read(marketModeProvider) == MarketMode.stocks);
    }
  }

  void _showCoinPicker(List<Stock> market, {bool isStock = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CoinPickerSheet(
        stocks: market,
        currentSymbol: _selectedSymbol,
        isStock: isStock,
        onSelected: (stock) {
          Navigator.pop(ctx);
          _onSelectCoin(stock);
        },
      ),
    );
  }

  String _formatPrice(double price, Stock stock, AppCurrencyFormatter formatter) {
    if (stock.isStock) {
      final String sym = stock.currency == 'INR' ? '₹' : (stock.currency == 'USD' ? '\$' : stock.currency);
      final fmt = NumberFormat(price >= 100 ? '#,##0.00' : '#,##0.00##', 'en_US');
      return '$sym${fmt.format(price)}';
    }
    return formatter.format(price);
  }

  String _formatAuditPrice(
    double price,
    bool isStock,
    String assetCurrency,
    AppCurrencyFormatter formatter,
  ) {
    if (isStock) {
      final sym = assetCurrency == 'INR' ? '₹' : '\$';
      final digits = price.abs() < 1.0 ? 4 : 2;
      final fmt = NumberFormat(digits == 4 ? '#,##0.0000' : '#,##0.00', 'en_US');
      return '$sym${fmt.format(price)}';
    }
    final converted = CurrencyFormatters.convert(price, formatter.currencyCode).abs();
    final digits = converted < 1.0 ? 4 : (converted < 10.0 ? 3 : 2);
    return CurrencyFormatters.format(price, formatter.currencyCode, decimalDigits: digits);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(marketModeProvider);
    final isStockMode = mode == MarketMode.stocks;
    final market = ref.watch(marketProvider);
    final stockMarket = ref.watch(stockMarketProvider);
    final activeMarket = isStockMode ? stockMarket : market;
    final allMarket = [...stockMarket, ...market];
    final userState = ref.watch(userProvider);
    final isLifetimePro = userState.profile.isAiSignalsUnlocked;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    ref.listen<MarketMode>(marketModeProvider, (prev, next) {
      if (prev != next) {
        final isStock = next == MarketMode.stocks;
        final list = isStock ? ref.read(stockMarketProvider) : ref.read(marketProvider);
        if (list.isNotEmpty) {
          final newSym = list.first.symbol.replaceAll('USDT', '');
          setState(() {
            _selectedSymbol = newSym;
            _customCandles = null;
          });
          _fetchKlines(newSym, _tvInterval);
          if (_mainTab == 2) {
            _ensureTrackRecordCandles(isStock: isStock);
          }
        }
      }
    });

    // Resolve current selected stock
    final clean = _selectedSymbol.toUpperCase();
    final isCoinUnlocked = isLifetimePro || _sessionUnlockedSymbols.contains(clean);
    final stock = activeMarket.firstWhere(
      (s) => s.symbol.toUpperCase() == clean || s.symbol.toUpperCase().startsWith(clean),
      orElse: () => allMarket.firstWhere(
        (s) => s.symbol.toUpperCase() == clean || s.symbol.toUpperCase().startsWith(clean),
        orElse: () => activeMarket.isNotEmpty ? activeMarket.first : (allMarket.isNotEmpty ? allMarket.first : const Stock(
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
        )),
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
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () => _showCoinPicker(activeMarket, isStock: isStockMode),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoinIcon(symbol: stock.symbol, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    stock.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.subtle, size: 16),
              ],
            ),
          ),
        ),
        actions: [
          // Currency picker pill
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: InkWell(
                onTap: () {
                  CurrencyPicker.show(
                    context,
                    currentCode: userState.profile.preferredCurrency,
                    onSelected: (code) {
                      if (code == userState.profile.preferredCurrency) return;
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (context.mounted) {
                          ref.read(userProvider.notifier).updateProfileSettings(currency: code);
                        }
                      });
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
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
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
            // ── TOP NAVIGATION SEGMENTS (Twitter / X Style) ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: Row(
                  children: [
                    _buildMainTabItem(0, 'AI Setup'.tr(), Icons.radar_rounded),
                    _buildMainTabItem(
                      1,
                      'Scanner'.tr(),
                      Icons.travel_explore_rounded,
                      isLocked: !isLifetimePro,
                      onLockedTap: () => _showUnlockModal(context, formatter),
                    ),
                    _buildMainTabItem(
                      2,
                      'Track Record'.tr(),
                      Icons.insights_rounded,
                      isLocked: !isLifetimePro,
                      onLockedTap: () => _showUnlockModal(context, formatter),
                    ),
                  ],
                ),
              ),
            ),

            if (_mainTab == 1)
              (isLifetimePro
                  ? _buildMarketScannerView(activeMarket, formatter, isStock: isStockMode)
                  : _buildLockedScannerPaywall(context, formatter))
            else if (_mainTab == 2)
              (isLifetimePro
                  ? _buildTrackRecordView(activeMarket, formatter, isStock: isStockMode)
                  : _buildLockedTrackRecordPaywall(context, formatter))
            else ...[
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
                        _formatPrice(stock.currentPrice, stock, formatter),
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.textPrimary),
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
                            style: TextStyle(color: AppColors.subtle, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // AI Confidence pill / Pro Unlock status
                  InkWell(
                    onTap: isLifetimePro ? null : () => _showUnlockModal(context, formatter, currentSymbol: stock.symbol),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLifetimePro
                              ? [
                                  AppColors.primary.withValues(alpha: 0.25),
                                  const Color(0xFF9945FF).withValues(alpha: 0.25),
                                ]
                              : (isCoinUnlocked
                                  ? [
                                      const Color(0xFF00C087).withValues(alpha: 0.25),
                                      const Color(0xFF00C087).withValues(alpha: 0.15),
                                    ]
                                  : [
                                      const Color(0xFFFFB800).withValues(alpha: 0.25),
                                      const Color(0xFFFF6B00).withValues(alpha: 0.25),
                                    ]),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLifetimePro
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : (isCoinUnlocked ? const Color(0xFF00C087) : const Color(0xFFFFB800)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLifetimePro
                                ? Icons.workspace_premium_rounded
                                : (isCoinUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded),
                            color: isLifetimePro
                                ? AppColors.primary
                                : (isCoinUnlocked ? const Color(0xFF00C087) : const Color(0xFFFFB800)),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isLifetimePro
                                ? 'PRO UNLOCKED ⚡'
                                : (isCoinUnlocked ? '${stock.symbol} PASS ACTIVE' : 'PRO LOCKED • \$50'),
                            style: TextStyle(
                              color: isLifetimePro
                                  ? AppColors.textPrimary
                                  : (isCoinUnlocked ? const Color(0xFF00C087) : const Color(0xFFFFB800)),
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
                    icon: Icon(Icons.fullscreen, color: AppColors.textPrimary, size: 22),
                    tooltip: 'Fullscreen / Expand Chart',
                  ),
                ],
              ),
            ),

            Container(
              height: _chartHeight,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildChart(stock),
            ),

            // Draggable Chart Height Resize Handle
            _buildChartResizeHandle(),

            if (isCoinUnlocked) ...[
              if (!isLifetimePro)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF00C087), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${stock.symbol} Signal Unlocked via Video',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showUnlockModal(context, formatter, currentSymbol: stock.symbol),
                        child: const Text(
                          'Unlock All →',
                          style: TextStyle(color: Color(0xFFFFB800), fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              // ── AI SENTIMENT SPEEDOMETER GAUGE ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSignalGauge(analysis, color),
              ),

              const SizedBox(height: 14),

              // ── MULTI-TIMEFRAME CONFLUENCE RADAR ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMultiTimeframeMatrix(stock, analysis),
              ),

              const SizedBox(height: 14),

              // ── MODE SELECTOR: SPOT VS FUTURES ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline, width: 1),
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
                                  isStockMode ? Icons.account_balance_rounded : Icons.currency_bitcoin_rounded,
                                  size: 18,
                                  color: _activeTab == 0 ? Colors.black : AppColors.subtle,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isStockMode ? 'Equity Delivery' : 'Spot Analysis',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: _activeTab == 0 ? Colors.black : AppColors.subtle,
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
                                  color: _activeTab == 1 ? Colors.black : AppColors.subtle,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isStockMode ? '5x Margin Model' : 'Futures Model',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: _activeTab == 1 ? Colors.black : AppColors.subtle,
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
              if (_activeTab == 0)
                _buildSpotAdviceSection(stock, analysis, formatter)
              else
                _buildFuturesAdviceSection(stock, analysis, formatter),
            ] else ...[
              const SizedBox(height: 16),
              // ── PRO PAYWALL CARD ($50 UNLOCK) ───────────────────────────────
              _buildProPaywallCard(stock, analysis, formatter),
            ],
          ],

          const SizedBox(height: 12),
          _buildStatutoryDisclaimer(),
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

            const SizedBox(height: 12),

            // Watch Ad Button directly below One-Time Access box
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isWatchingAd ? null : () => _watchAdToUnlockSignal(stock.symbol),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C087),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isWatchingAd
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Watch 1 Ad to Unlock ${stock.symbol} Signal Free',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Get institutional-grade technical algorithmic trading insights on every coin:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),

            const SizedBox(height: 12),

            _buildBenefitRow('⚡ Safe Leverage Model', 'Dynamic ATR-based simulated leverage models to manage simulated liquidation risk.'),
            _buildBenefitRow('🎯 Spot Buy & Sell Signals', 'Algorithm calculates precise entry ranges, take profit, and stop loss.'),
            _buildBenefitRow('📈 Futures Long & Short Bias', 'Multi-timeframe RSI, EMA 20/50 golden cross & MACD surge filtering.'),
            _buildBenefitRow('🛡️ Real-Time Liquidation Buffer', 'Instant mathematical distance buffer to your liquidation price.'),
            _buildBenefitRow('🌐 All 50+ Global Crypto Pairs', 'Unlock full unrestricted access across all markets with zero recurring subscription.'),

            const SizedBox(height: 18),

            // Bottom Action: Unlock All 50+ Pairs Lifetime
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showUnlockModal(context, formatter, currentSymbol: stock.symbol),
                icon: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Unlock All 50+ Pairs Lifetime — \$50 USD',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
          SnackBar(
            backgroundColor: AppColors.surface,
            content: const Text('No previous active \$50 purchase was found on this account.'),
          ),
        );
      }
    }
  }

  void _showUnlockModal(BuildContext context, AppCurrencyFormatter formatter, {String? currentSymbol}) {
    final localizedPrice = formatter.format(50.0 * CurrencyFormatters.usdToInr);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _UnlockSignalsSheet(
        formatter: formatter,
        localizedPrice: localizedPrice,
        currentSymbol: currentSymbol,
        onWatchAd: currentSymbol != null ? () => _watchAdToUnlockSignal(currentSymbol) : null,
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

  // ── STATUTORY DISCLAIMER ────────────────────────────────────────────────
  Widget _buildStatutoryDisclaimer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? const Color(0xFF14171E) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Educational & CFTC Rule 4.41 Notice: All algorithmic signals, indicators, and leverage models are generated mathematically for educational paper-trading simulation purposes only. PaperTrading - Crypto & Stocks is NOT a registered investment advisor, commodity trading advisor, or broker. This does not constitute financial, legal, or investment advice. Simulated results have inherent limitations, are prepared with the benefit of hindsight, and do not guarantee real-world trading performance.',
              style: GoogleFonts.inter(
                color: AppColors.subtle,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Risk/Reward Asymmetry Bar
          _buildRiskRewardVisualizer(
            entry: (advice.entryZoneLow + advice.entryZoneHigh) / 2,
            target1: advice.targetPrice,
            target2: advice.targetPrice,
            stopLoss: advice.stopLossPrice,
            rRatio: advice.stopLossPct > 0 ? (advice.targetGainPct / advice.stopLossPct) : 2.5,
            formatter: formatter,
            isLong: isBuy,
            stock: stock,
          ),

          const SizedBox(height: 16),

          // 3. Price Strategy Breakdown Card
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
                    const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Spot Price Targets',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Optimal Entry Zone',
                        value: '${_formatPrice(advice.entryZoneLow, stock, formatter)} - ${_formatPrice(advice.entryZoneHigh, stock, formatter)}',
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
                        value: '${_formatPrice(advice.targetPrice, stock, formatter)} (+${advice.targetGainPct.toStringAsFixed(1)}%)',
                        icon: Icons.flag_rounded,
                        color: AppColors.profit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Stop Loss Target',
                        value: '${_formatPrice(advice.stopLossPrice, stock, formatter)} (-${advice.stopLossPct.toStringAsFixed(1)}%)',
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
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Safe Leverage Recommendation Card (Crucial User Requirement!)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.isDarkMode
                  ? const LinearGradient(
                      colors: [Color(0xFF1F1B2E), Color(0xFF141A21)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: AppColors.isDarkMode ? null : AppColors.surface,
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
                    Expanded(
                      child: Text(
                        'Safe Leverage Model',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5),
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.health_and_safety_outlined, color: AppColors.profit, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Est. Liquidation Distance: ~${advice.liquidationDistancePct.toStringAsFixed(1)}% safe buffer (${_formatPrice(advice.estimatedLiquidationPrice, stock, formatter)})',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Risk/Reward Asymmetry Bar
          _buildRiskRewardVisualizer(
            entry: advice.entryPrice,
            target1: advice.targetPrice1,
            target2: advice.targetPrice2,
            stopLoss: advice.stopLossPrice,
            rRatio: advice.riskRewardRatio,
            formatter: formatter,
            isLong: isLong,
            stock: stock,
          ),

          const SizedBox(height: 16),

          // 4. Futures Execution Targets Card
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
                    Expanded(
                      child: Text(
                        'Order Parameters',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
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
                        value: _formatPrice(advice.entryPrice, stock, formatter),
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Take Profit 1 (Scalp)',
                        value: _formatPrice(advice.targetPrice1, stock, formatter),
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
                        value: _formatPrice(advice.targetPrice2, stock, formatter),
                        icon: Icons.looks_two_rounded,
                        color: AppColors.profit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildParameterTile(
                        label: 'Stop Loss (Invalidation)',
                        value: _formatPrice(advice.stopLossPrice, stock, formatter),
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
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
                  style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w500),
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

  Widget _buildMainTabItem(
    int index,
    String title,
    IconData icon, {
    bool isLocked = false,
    VoidCallback? onLockedTap,
  }) {
    final isSelected = _mainTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mainTab = index);
          if (isLocked) {
            onLockedTap?.call();
          } else if (index == 2) {
            _ensureTrackRecordCandles(
              isStock: ref.read(marketModeProvider) == MarketMode.stocks,
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isLocked ? const Color(0xFF26200A) : const Color(0xFF1D9BF0))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected && isLocked
                ? Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.6), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocked ? Icons.lock_rounded : icon,
                size: 13,
                color: isSelected
                    ? (isLocked ? const Color(0xFFFFB800) : Colors.white)
                    : (isLocked ? const Color(0xFFFFB800) : AppColors.subtle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected
                          ? (isLocked ? const Color(0xFFFFB800) : Colors.white)
                          : (isLocked ? const Color(0xFFFFB800) : AppColors.subtle),
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalGauge(TechnicalAnalysisResult analysis, Color themeColor) {
    final score = analysis.compositeScore;
    final Color gaugeColor = score > 40
        ? AppColors.profit
        : (score < -40
            ? AppColors.loss
            : (score > 10
                ? const Color(0xFF00D09C)
                : (score < -10 ? const Color(0xFFFF7A00) : const Color(0xFFF0B90B))));

    final String label = score > 50
        ? 'STRONG BUY'
        : (score > 15
            ? 'BUY'
            : (score < -50
                ? 'STRONG SELL'
                : (score < -15 ? 'SELL' : 'NEUTRAL')));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: Color(0xFF1D9BF0), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Sentiment Gauge',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gaugeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gaugeColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  '${analysis.spotAdvice.confidenceScore.toStringAsFixed(0)}% ${'Conviction'.tr()}',
                  style: TextStyle(color: gaugeColor, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _SignalGaugePainter(
                score: score.toDouble(),
                activeColor: gaugeColor,
              ),
              child: Align(
                alignment: const Alignment(0, 0.65),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score >= 0 ? "+" : ""}$score',
                      style: TextStyle(
                        color: gaugeColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: gaugeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Strong Sell', style: TextStyle(color: Color(0xFFF6465D), fontSize: 10, fontWeight: FontWeight.w700)),
              Text('Neutral', style: TextStyle(color: Color(0xFFF0B90B), fontSize: 10, fontWeight: FontWeight.w700)),
              Text('Strong Buy', style: TextStyle(color: Color(0xFF0ECB81), fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiTimeframeMatrix(Stock stock, TechnicalAnalysisResult analysis) {
    final confluences = SignalEngine.getMultiTimeframeConfluence(stock, analysis);
    final bullishCount = confluences.where((c) => c.trend == 'Bullish').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF1D9BF0), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Multi-Timeframe Confluence'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (bullishCount >= 3 ? AppColors.profit : AppColors.warning).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (bullishCount >= 3 ? AppColors.profit : AppColors.warning).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$bullishCount/4 ${'Aligned'.tr()}',
                  style: TextStyle(
                    color: bullishCount >= 3 ? AppColors.profit : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: confluences.map((tf) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tf.color.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tf.label,
                        style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tf.trend,
                        style: TextStyle(color: tf.color, fontSize: 12, fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tf.confidence.toStringAsFixed(0)}%',
                        style: TextStyle(color: AppColors.subtle, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskRewardVisualizer({
    required double entry,
    required double target1,
    required double target2,
    required double stopLoss,
    required double rRatio,
    required AppCurrencyFormatter formatter,
    required bool isLong,
    required Stock stock,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.balance_rounded, color: Color(0xFF1D9BF0), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Risk / Reward Asymmetry',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.profit.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.profit.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  '1 : ${rRatio.toStringAsFixed(1)} R:R',
                  style: const TextStyle(color: AppColors.profit, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: 10,
                  child: Container(
                    height: 8,
                    color: AppColors.loss,
                  ),
                ),
                Container(width: 3, height: 14, color: AppColors.textPrimary),
                Expanded(
                  flex: (rRatio * 10).clamp(10.0, 45.0).toInt(),
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.profit],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stop-Loss', style: TextStyle(color: AppColors.loss, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_formatPrice(stopLoss, stock, formatter), style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Entry Reference', style: TextStyle(color: AppColors.subtle, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_formatPrice(entry, stock, formatter), style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Target (Max)', style: TextStyle(color: AppColors.profit, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_formatPrice(target2, stock, formatter), style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockedScannerPaywall(BuildContext context, AppCurrencyFormatter formatter) {
    final userCurrency = ref.watch(userProvider).profile.preferredCurrency;
    final localizedPrice = formatter.format(50.0 * CurrencyFormatters.usdToInr);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF181508), Color(0xFF0F1117)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB800).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFFFB800), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI MARKET SCANNER',
                        style: TextStyle(
                          color: Color(0xFFFFB800),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pro Algorithmic Radar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Real-time automated scanning across all 70+ crypto assets. Get instant confluence signals, recommended leverage, and entry/exit targets.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            _buildBenefitRow('⚡ 70+ Crypto Markets Scanned Live', 'Every candle is evaluated with multi-timeframe RSI, EMA, and MACD.'),
            _buildBenefitRow('🎯 Bullish / Bearish / Safe Futures', 'Instant filtering for high-conviction breakout and reversal setups.'),
            _buildBenefitRow('🛡️ Safe Leverage & R:R Engine', 'Automated ATR-based risk calculation and liquidation buffers.'),
            _buildBenefitRow('💎 Lifetime Unlocked Access', 'No recurring subscription. Pay once and own permanent access.'),
            const SizedBox(height: 20),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_open_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            userCurrency == 'USD'
                                ? 'Unlock Market Scanner — \$50 USD'
                                : 'Unlock Market Scanner — \$50 (~$localizedPrice)',
                            style: const TextStyle(
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
          ],
        ),
      ),
    );
  }

  Widget _buildLockedTrackRecordPaywall(BuildContext context, AppCurrencyFormatter formatter) {
    final userCurrency = ref.watch(userProvider).profile.preferredCurrency;
    final localizedPrice = formatter.format(50.0 * CurrencyFormatters.usdToInr);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF181508), Color(0xFF0F1117)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB800).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFFFB800), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI AUDIT & TRACK RECORD',
                        style: TextStyle(
                          color: Color(0xFFFFB800),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Verified Performance Logs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Audit every past signal triggered by the Sentinel algorithm. Review win rates, risk-to-reward metrics, and exact target hit history.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            _buildBenefitRow('📊 Live Walk-Forward Win Rate Audit', 'Win rate, profit ratio, and returns computed from real historical market candles.'),
            _buildBenefitRow('📝 Historical Target 1 & 2 Executions', 'Exact timestamps, PnL percentages, and exit points for each setup.'),
            _buildBenefitRow('🛡️ Independent Confluence Backtests', 'Full statistical proof of the ATR & MACD confluence engine.'),
            _buildBenefitRow('💎 Lifetime Unlocked Access', 'One-time \$50 unlock gives permanent access to all signals and audits.'),
            const SizedBox(height: 20),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_open_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            userCurrency == 'USD'
                                ? 'Unlock Track Record — \$50 USD'
                                : 'Unlock Track Record — \$50 (~$localizedPrice)',
                            style: const TextStyle(
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
          ],
        ),
      ),
    );
  }

  Widget _buildMarketScannerView(List<Stock> market, AppCurrencyFormatter formatter, {bool isStock = false}) {
    final scannedItems = SignalEngine.scanMarket(market);
    final marginFilterLabel = isStock ? '⚡ 5x Margin' : '⚡ Safe Futures';
    final filters = ['All', '🔥 Bullish', '⚠️ Bearish', marginFilterLabel];

    final filtered = scannedItems.where((item) {
      if (_scannerFilter == '🔥 Bullish') {
        return item.analysis.compositeScore > 20;
      } else if (_scannerFilter == '⚠️ Bearish') {
        return item.analysis.compositeScore < -20;
      } else if (_scannerFilter == '⚡ Safe Futures' || _scannerFilter == '⚡ 5x Margin' || _scannerFilter == marginFilterLabel) {
        return item.analysis.futuresAdvice.confidenceScore >= 70 &&
            item.analysis.futuresAdvice.recommendedLeverage >= 2;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = _scannerFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _scannerFilter = filter),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1D9BF0) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1D9BF0) : AppColors.outline,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.subtle,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Active AI ${isStock ? "Stock" : "Confluence"} Setups (${filtered.length})',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Center(
                child: Text(
                  'No setups matching this filter right now.',
                  style: TextStyle(color: AppColors.subtle),
                ),
              ),
            )
          else
            ...filtered.map((item) => _buildScannerCard(item, formatter)),
        ],
      ),
    );
  }

  Widget _buildScannerCard(MarketSignalItem item, AppCurrencyFormatter formatter) {
    final stock = item.stock;
    final analysis = item.analysis;
    final badgeColor = analysis.compositeScore > 35
        ? AppColors.profit
        : (analysis.compositeScore < -35 ? AppColors.loss : AppColors.warning);
    final actionTitle = analysis.spotAdvice.title;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CoinIcon(symbol: stock.symbol, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            stock.name,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '\$${stock.symbol}',
                          style: TextStyle(color: AppColors.subtle, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatPrice(stock.currentPrice, stock, formatter)} · ${stock.changePercentage >= 0 ? "+" : ""}${stock.changePercentage.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: stock.changePercentage >= 0 ? AppColors.profit : AppColors.loss,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  actionTitle,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confidence', style: TextStyle(color: AppColors.subtle, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${analysis.spotAdvice.confidenceScore.toStringAsFixed(0)}% Score',
                      style: TextStyle(color: badgeColor, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Safe Leverage', style: TextStyle(color: AppColors.subtle, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${analysis.futuresAdvice.recommendedLeverage}x REC.',
                      style: const TextStyle(color: Color(0xFF9945FF), fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('R:R Potential', style: TextStyle(color: AppColors.subtle, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '1 : ${analysis.futuresAdvice.riskRewardRatio}',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedSymbol = stock.symbol;
                  _mainTab = 0;
                });
                _fetchKlines(stock.symbol, _tvInterval);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1D9BF0), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar_rounded, size: 16, color: Color(0xFF1D9BF0)),
                  const SizedBox(width: 6),
                  Text(
                    'Inspect AI Setup & Chart'.tr(),
                    style: const TextStyle(color: Color(0xFF1D9BF0), fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTradeDuration(Duration d) {
    if (d.inDays >= 1) {
      final remHours = d.inHours % 24;
      return remHours > 0 ? '${d.inDays}d ${remHours}h' : '${d.inDays}d';
    }
    if (d.inHours >= 1) return '${d.inHours}h';
    final mins = max(15, d.inMinutes);
    return '${mins}m';
  }

  Widget _buildTrackRecordView(
    List<Stock> activeMarket,
    AppCurrencyFormatter formatter, {
    bool isStock = false,
  }) {
    final backtestCache =
        isStock ? _stockBacktestCandles : _cryptoBacktestCandles;
    final lastFetched =
        isStock ? _stockBacktestFetchedAt : _cryptoBacktestFetchedAt;

    if (lastFetched == null && !_isLoadingTrackAudit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureTrackRecordCandles(isStock: isStock);
        }
      });
    }

    final selectedClean = _selectedSymbol.replaceAll('USDT', '').toUpperCase();
    final baseReport = SignalEngine.runTrackRecordBacktest(
      market: activeMarket,
      isStock: isStock,
      extendedCandles: backtestCache,
      symbolFilter: _trackFilter == 'Selected' ? selectedClean : null,
    );

    final List<SignalTrackRecordItem> displayedRecords;
    if (_trackFilter == 'Wins') {
      displayedRecords = baseReport.records.where((r) => r.isWin).toList();
    } else if (_trackFilter == 'Losses') {
      displayedRecords = baseReport.records.where((r) => !r.isWin).toList();
    } else {
      displayedRecords = baseReport.records;
    }

    final String profitRatioText = baseReport.totalTrades == 0
        ? '--'
        : (baseReport.winCount == 0
            ? '--'
            : (baseReport.lossCount > 0
                ? '1 : ${baseReport.profitRatio.toStringAsFixed(1)}'
                : 'All Wins'));
    final String winRateText = baseReport.totalTrades > 0
        ? '${baseReport.winRatePct.toStringAsFixed(1)}%'
        : '--';
    final String avgWinText = baseReport.winCount > 0
        ? '+${baseReport.avgWinPct.toStringAsFixed(1)}%'
        : '--';
    final String windowText = (baseReport.periodStart != null && baseReport.periodEnd != null)
        ? '${DateFormat('MMM d').format(baseReport.periodStart!)} – ${DateFormat('MMM d').format(baseReport.periodEnd!)}'
        : (isStock ? '1M · 1H Bars' : '8D · 1H Bars');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights_rounded, color: Color(0xFF1D9BF0), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isStock
                            ? 'AI Stocks Track Record'.tr()
                            : 'AI Sentinel Track Record'.tr(),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_isLoadingTrackAudit)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1D9BF0),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _ensureTrackRecordCandles(
                          isStock: isStock,
                          forceRefresh: true,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: AppColors.subtle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isStock
                      ? 'Walk-forward backtest across ${baseReport.assetsAudited > 0 ? baseReport.assetsAudited : 15} US ${baseReport.assetsAudited == 1 ? "stock/ETF" : "stocks & ETFs"} ($windowText).'
                      : 'Walk-forward confluence backtest across ${baseReport.assetsAudited > 0 ? baseReport.assetsAudited : 15} crypto ${baseReport.assetsAudited == 1 ? "pair" : "pairs"} ($windowText).',
                  style: TextStyle(color: AppColors.subtle, fontSize: 12.5),
                ),
                if (baseReport.totalTrades > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${baseReport.totalTrades} closed ${baseReport.totalTrades == 1 ? "setup" : "setups"} (${baseReport.winCount}W / ${baseReport.lossCount}L)'
                    '${baseReport.lossCount > 0 ? ' · Avg Loss -${baseReport.avgLossPct.toStringAsFixed(1)}%' : ''}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            'WIN RATE'.tr(),
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            winRateText,
                            style: TextStyle(
                              color: baseReport.winRatePct >= 50
                                  ? AppColors.profit
                                  : AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 32, color: AppColors.outline),
                      Column(
                        children: [
                          Text(
                            'PROFIT RATIO'.tr(),
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profitRatioText,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 32, color: AppColors.outline),
                      Column(
                        children: [
                          Text(
                            'AVG WIN'.tr(),
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            avgWinText,
                            style: const TextStyle(
                              color: AppColors.profit,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTrackFilterChip('All', 'All Assets'),
                _buildTrackFilterChip('Selected', selectedClean),
                _buildTrackFilterChip('Wins', 'Wins Only'),
                _buildTrackFilterChip('Losses', 'Losses Only'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Signal Executions'.tr(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                displayedRecords.length > 30
                    ? 'Latest 30 of ${displayedRecords.length}'
                    : '${displayedRecords.length} shown',
                style: TextStyle(
                  color: AppColors.subtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingTrackAudit && displayedRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF1D9BF0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Auditing live historical candles...',
                    style: TextStyle(color: AppColors.subtle, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (displayedRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline),
              ),
              child: Center(
                child: Text(
                  _trackFilter == 'Selected'
                      ? 'No closed confluence setups triggered for $selectedClean in this audit window.'
                      : 'No closed setups found for this filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
              ),
            )
          else
            ...displayedRecords.take(30).map((rec) {
              final isWin = rec.isWin;
              final recColor = isWin ? AppColors.profit : AppColors.loss;
              final entryFmt = _formatAuditPrice(
                rec.entryPrice,
                rec.isStock,
                rec.currency,
                formatter,
              );
              final exitFmt = _formatAuditPrice(
                rec.exitPrice,
                rec.isStock,
                rec.currency,
                formatter,
              );
              final held = _formatTradeDuration(rec.date.difference(rec.entryDate));
              final matchedStock = activeMarket.where(
                (s) => s.symbol.replaceAll('USDT', '').toUpperCase() == rec.symbol,
              ).firstOrNull;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: matchedStock == null
                      ? null
                      : () {
                          _onSelectCoin(matchedStock);
                          setState(() => _mainTab = 0);
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CoinIcon(symbol: rec.symbol, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rec.symbol,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        rec.type,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.subtle,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                rec.targetHit,
                                style: TextStyle(
                                  color: recColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$entryFmt → $exitFmt · Held $held',
                                style: TextStyle(
                                  color: AppColors.subtle,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${rec.returnPct >= 0 ? "+" : ""}${rec.returnPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: recColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, HH:mm').format(rec.date),
                              style: TextStyle(color: AppColors.subtle, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrackFilterChip(String key, String label) {
    final isSelected = _trackFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _trackFilter = key),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D9BF0) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF1D9BF0) : AppColors.outline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.subtle,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorBreakdown(TechnicalAnalysisResult analysis) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: Color(0xFF1D9BF0), size: 18),
              const SizedBox(width: 8),
              Text(
                'Technical Indicators Telemetry',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
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
                      : (analysis.rsi > 65 ? 'Overbought (Caution)' : 'Healthy Momentum'),
                  analysis.rsi < 45 ? AppColors.profit : (analysis.rsi > 65 ? AppColors.loss : AppColors.subtle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIndicatorMiniCard(
                  'MACD Histogram',
                  analysis.macdHist >= 0 ? '+Bullish Expansion' : '-Bearish Velocity',
                  analysis.macdHist >= 0 ? 'Expanding upward' : 'Downward momentum',
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
                  'EMA 20 / 50 Cross',
                  analysis.ema20 >= analysis.ema50 ? 'Golden Trend Active' : 'Death Trend Active',
                  analysis.ema20 >= analysis.ema50 ? 'EMA 20 > EMA 50' : 'EMA 20 < EMA 50',
                  analysis.ema20 >= analysis.ema50 ? AppColors.profit : AppColors.loss,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIndicatorMiniCard(
                  'ATR Volatility',
                  '${analysis.atrPct.toStringAsFixed(1)}%',
                  analysis.atrPct > 4 ? 'High Fluctuations' : 'Low Noise Buffer',
                  analysis.atrPct > 4 ? Colors.orangeAccent : const Color(0xFF1D9BF0),
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            mainVal,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: accent),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subVal,
            style: TextStyle(color: AppColors.subtle, fontSize: 10),
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
            color: isSelected
                ? (AppColors.isDarkMode ? const Color(0xFF2B3139) : AppColors.surfaceAlt)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.subtle,
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
        key: ValueKey('tv_signals_${stock.symbol}_${_activeTab == 1}_${_tvInterval}_${AppColors.isDarkMode}'),
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

    DateTime? nativeVisibleMin;
    DateTime? nativeVisibleMax;
    if (candles.length > 35) {
      nativeVisibleMin = candles[candles.length - 35].date;
      final lastDate = candles.last.date;
      final secondLastDate = candles[candles.length - 2].date;
      final diffMin = lastDate.difference(secondLastDate).inMinutes.clamp(1, 1440);
      nativeVisibleMax = lastDate.add(Duration(minutes: diffMin * 4));
    }

    return SfCartesianChart(
      zoomPanBehavior: _zoomPanBehavior,
      plotAreaBorderWidth: 0,
      plotAreaBackgroundColor: AppColors.surface,
      backgroundColor: AppColors.surface,
      margin: EdgeInsets.zero,
      primaryXAxis: DateTimeAxis(
        isVisible: true,
        initialVisibleMinimum: nativeVisibleMin,
        initialVisibleMaximum: nativeVisibleMax,
        labelStyle: TextStyle(color: AppColors.subtle, fontSize: 10),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
      ),
      primaryYAxis: NumericAxis(
        isVisible: true,
        opposedPosition: true,
        labelStyle: TextStyle(color: AppColors.subtle, fontSize: 10),
        majorGridLines: MajorGridLines(width: 0.5, color: AppColors.outline),
        axisLine: const AxisLine(width: 0),
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
              color: _isResizingChart ? AppColors.primary : AppColors.subtle.withValues(alpha: 0.4),
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
    final mode = ref.read(marketModeProvider);
    final isStock = mode == MarketMode.stocks ||
        stock.symbol.endsWith('.NS') ||
        stock.symbol.endsWith('.BO') ||
        stock.symbol.startsWith('^') ||
        kStockAssets.any((a) => a.symbol == stock.symbol);

    if (isStock) {
      StockTradeSheet.show(context, stock, side);
      return;
    }

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
    final mode = ref.read(marketModeProvider);
    final isStock = mode == MarketMode.stocks ||
        stock.symbol.endsWith('.NS') ||
        stock.symbol.endsWith('.BO') ||
        stock.symbol.startsWith('^') ||
        kStockAssets.any((a) => a.symbol == stock.symbol);

    if (isStock) {
      StockTradeSheet.show(context, stock, side);
      return;
    }

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

class _SignalGaugePainter extends CustomPainter {
  final double score; // -100 to 100
  final Color activeColor;

  _SignalGaugePainter({required this.score, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.88);
    final radius = min(size.width * 0.44, size.height * 0.76);
    const strokeWidth = 12.0;

    // Track arc from 180° (pi) to 360° (2*pi)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.outline;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      trackPaint,
    );

    // Segmented colored background arcs
    final segments = [
      (0.0, 0.2, const Color(0xFFF6465D)), // Strong Sell
      (0.2, 0.4, const Color(0xFFFF7A00)), // Sell
      (0.4, 0.6, const Color(0xFFF0B90B)), // Neutral
      (0.6, 0.8, const Color(0xFF00D09C)), // Buy
      (0.8, 1.0, const Color(0xFF0ECB81)), // Strong Buy
    ];

    for (final seg in segments) {
      final startAngle = pi + (seg.$1 * pi);
      final sweepAngle = (seg.$2 - seg.$1) * pi;
      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 4
        ..strokeCap = StrokeCap.butt
        ..color = seg.$3.withValues(alpha: 0.35);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        segPaint,
      );
    }

    // Active progress arc up to current score
    final progress = ((score + 100) / 200).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = activeColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      progress * pi,
      false,
      activePaint,
    );

    // Needle indicator bead
    final needleAngle = pi + (progress * pi);
    final needleRadius = radius - strokeWidth / 2;
    final needleX = center.dx + needleRadius * cos(needleAngle);
    final needleY = center.dy + needleRadius * sin(needleAngle);

    final needlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, needleY), 6.5, needlePaint);

    final needleBorder = Paint()
      ..color = activeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(needleX, needleY), 6.5, needleBorder);
  }

  @override
  bool shouldRepaint(covariant _SignalGaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.activeColor != activeColor;
}

// ── COIN PICKER MODAL SHEET ─────────────────────────────────────────────────

class CoinPickerSheet extends StatefulWidget {
  final List<Stock> stocks;
  final String currentSymbol;
  final bool isStock;
  final ValueChanged<Stock> onSelected;

  const CoinPickerSheet({
    super.key,
    required this.stocks,
    required this.currentSymbol,
    this.isStock = false,
    required this.onSelected,
  });

  @override
  State<CoinPickerSheet> createState() => _CoinPickerSheetState();
}

class _CoinPickerSheetState extends State<CoinPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.stocks.where((s) {
      final q = _search.toLowerCase();
      return s.symbol.toLowerCase().contains(q) || s.name.toLowerCase().contains(q);
    }).toList();

    return Material(
      color: AppColors.surface,
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
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isStock ? 'Select Stock Asset' : 'Select Crypto Pair',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          TextField(
            autofocus: false,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: AppColors.subtle),
              hintText: widget.isStock
                  ? 'Search US stocks (e.g. AAPL, NVDA, TSLA)...'
                  : 'Search coin or symbol (e.g. BTC, ETH, SOL)...',
              hintStyle: TextStyle(color: AppColors.subtle),
              filled: true,
              fillColor: AppColors.surfaceAlt,
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
                separatorBuilder: (_, __) => Divider(color: AppColors.outline, height: 1),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  final isSelected = s.symbol.toUpperCase().startsWith(widget.currentSymbol.toUpperCase());
                  final good = s.changePercentage >= 0;
                  return ListTile(
                    leading: CoinIcon(symbol: s.symbol, size: 28),
                    title: Row(
                      children: [
                        Text(s.symbol, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        Text(s.category, style: TextStyle(color: AppColors.subtle, fontSize: 11)),
                      ],
                    ),
                    subtitle: Text(s.name, style: TextStyle(color: AppColors.subtle, fontSize: 12)),
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
  final String? currentSymbol;
  final VoidCallback? onWatchAd;

  const _UnlockSignalsSheet({
    required this.formatter,
    required this.localizedPrice,
    required this.onUnlocked,
    this.currentSymbol,
    this.onWatchAd,
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
        backgroundColor: AppColors.surface,
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
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
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
          Text(
            'Unlock AI Signals & Safe Leverage Desk',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'One-time payment of \$50 USD (~${widget.localizedPrice}) for lifetime access across all crypto pairs.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Free Video Option: 1-Coin Pass
          if (widget.currentSymbol != null && widget.onWatchAd != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onWatchAd!();
                },
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.black),
                label: Text(
                  'Watch 1 Ad to Unlock ${widget.currentSymbol} Free',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C087),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.outline)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR GET LIFETIME', style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Divider(color: AppColors.outline)),
              ],
            ),
            const SizedBox(height: 12),
          ],

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
