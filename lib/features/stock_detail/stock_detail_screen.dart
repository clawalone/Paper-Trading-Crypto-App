import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/app_theme.dart';
import '../../core/app_review_manager.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import '../futures/futures_trade_sheet.dart';
import '../signals/signals_screen.dart';
import '../../core/coin_icon.dart';
import '../../core/trading_view_chart.dart';
import '../../data/order_book_provider.dart';

enum ChartViewMode { tradingView, candle, line }

class StockDetailScreen extends ConsumerStatefulWidget {
  final String stockSymbol;
  final bool isFutures;
  const StockDetailScreen({required this.stockSymbol, this.isFutures = false, super.key});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  String _range = '1D';
  String _tvInterval = '15';
  String _chartStyle = '1';
  ChartViewMode _chartMode = ChartViewMode.tradingView;
  double _chartHeight = 260.0;
  bool _isResizingChart = false;
  int _selectedTab = 0;
  late ZoomPanBehavior _zoomPanBehavior;
  DateTimeAxisController? _xAxisController;
  NumericAxisController? _yAxisController;
  
  List<StockCandle>? _rangeCandles;
  bool _isLoadingRange = false;
  Timer? _historyTimeoutTimer;
  bool _historyTimedOut = false;

  static const _binanceHosts = [
    'api.binance.com',
    'data-api.binance.vision',
    'api3.binance.com',
    'api1.binance.com',
  ];

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.xy,
    );
    _startHistoryTimeoutTimer();
    _fetchRangeData('1D', widget.stockSymbol);
  }

  void _startHistoryTimeoutTimer() {
    _historyTimeoutTimer?.cancel();
    _historyTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _historyTimedOut = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _historyTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRangeData(String range, String symbol) async {
    setState(() { _isLoadingRange = true; _range = range; });
    String interval = '15m';
    int limit = 96;
    switch(range) {
      case '1D': interval = '15m'; limit = 96; break;
      case '1W': interval = '2h'; limit = 84; break;
      case '1M': interval = '8h'; limit = 90; break;
      case '1Y': interval = '1d'; limit = 365; break;
      case '5Y': interval = '1w'; limit = 260; break;
    }
    final cleanSym = symbol.toUpperCase().replaceAll('USDT', '');
    final pair = '${cleanSym}USDT';
    for (final host in _binanceHosts) {
      try {
        final res = await http.get(Uri.parse(
          'https://$host/api/v3/klines?symbol=$pair&interval=$interval&limit=$limit'
        )).timeout(const Duration(seconds: 4));
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
          if (candles.isNotEmpty) {
            if (mounted) {
              setState(() {
                _rangeCandles = candles;
                _isLoadingRange = false;
                _historyTimedOut = false;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _isLoadingRange = false; });
  }

  /// Returns a round interval that gives ~5 gridlines across [lo..hi].
  double _computeYInterval(double lo, double hi) {
    final range = hi - lo;
    if (range <= 0) return 1;
    final rawStep = range / 5;
    final magnitude = pow(10, (log(rawStep) / ln10).floor()).toDouble();
    final normalised = rawStep / magnitude;
    final double nice;
    if (normalised < 1.5) {
      nice = 1;
    } else if (normalised < 3) {
      nice = 2;
    } else if (normalised < 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketProvider);
    final userState = ref.watch(userProvider);
    final cleanTarget = CoinIcon.cleanSymbol(widget.stockSymbol);
    final stock = market.firstWhere(
      (s) {
        final cleanS = CoinIcon.cleanSymbol(s.symbol);
        if (s.symbol.toUpperCase() == widget.stockSymbol.toUpperCase()) return true;
        if (cleanS == cleanTarget) return true;
        if (cleanS.replaceAll('1000', '') == cleanTarget.replaceAll('1000', '')) return true;
        if (s.name.toUpperCase() == cleanTarget) return true;
        if (s.symbol.toUpperCase().startsWith(cleanTarget)) return true;
        return false;
      },
      orElse: () => market.isNotEmpty ? market.first : const Stock(
        symbol: 'BTCUSDT',
        name: 'Bitcoin',
        category: 'Crypto',
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
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final isWatched = userState.profile.watchlist.contains(stock.symbol);
    final holding = userState.holdings.firstWhere((h) => h.symbol == stock.symbol, orElse: () => Holding(symbol: stock.symbol, quantity: 0, averagePrice: 0));

    final good = stock.changePercentage >= 0;
    final color = good ? AppColors.profit : AppColors.loss;

    // Use fetched candles or fallback to cache / synthetic generation
    List<StockCandle> activeCandles = _rangeCandles ?? stock.candleHistory;
    if (activeCandles.length < 2 && stock.history.length >= 2) {
      activeCandles = stock.history.asMap().entries.map((e) => StockCandle(
        date: DateTime.now().subtract(Duration(hours: stock.history.length - e.key)),
        open: e.value,
        high: e.value * 1.002,
        low: e.value * 0.998,
        close: e.value,
        volume: 1000,
      )).toList();
    }
    if (activeCandles.length < 2 && stock.currentPrice > 0) {
      activeCandles = MarketNotifier.generateFallbackCandles(stock.currentPrice);
    }
    final hasEnoughHistory = activeCandles.length >= 2;

    // Show loading / error state only if history hasn't loaded yet
    if (!hasEnoughHistory) {
      if (!_historyTimedOut) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: Text(stock.symbol),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                const SizedBox(height: 16),
                Text(
                  'Loading ${stock.name} data...',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(stock.symbol),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: AppColors.loss, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Unable to load ${stock.name} data',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Could not fetch recent price history. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _historyTimedOut = false;
                      _startHistoryTimeoutTimer();
                    });
                    ref.read(marketProvider.notifier).refresh();
                    _fetchRangeData(_range, widget.stockSymbol);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final spots = activeCandles.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList();
    
    final minPrice = activeCandles.isEmpty ? stock.currentPrice : activeCandles.map((c) => c.low).reduce(min);
    final maxPrice = activeCandles.isEmpty ? stock.currentPrice : activeCandles.map((c) => c.high).reduce(max);
    
    final sliverAppBar = SliverAppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      pinned: true,
      title: Row(
        children: [
          CoinIcon(symbol: stock.symbol, size: 28),
          const SizedBox(width: 10),
          Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(width: 6),
          Text(stock.name, style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'AI Trade Signals & Advisor',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => SignalsScreen(initialSymbol: stock.symbol),
              ),
            );
          },
          icon: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
        ),
        IconButton(
          onPressed: () => ref.read(userProvider.notifier).toggleWatchlist(stock.symbol),
          icon: Icon(isWatched ? Icons.star : Icons.star_border, color: isWatched ? Colors.amber : Colors.white38),
        ),
      ],
    );

    // 24h high/low from active candles
    final high24h = activeCandles.isEmpty ? stock.currentPrice : activeCandles.map((c) => c.high).reduce(max);
    final low24h  = activeCandles.isEmpty ? stock.currentPrice : activeCandles.map((c) => c.low).reduce(min);

    final headerWidget = Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price row
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatter.format(stock.currentPrice),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 24h High / Low
          Row(
            children: [
              _HighLowBadge(label: '24H H', value: formatter.format(high24h), color: AppColors.profit),
              const SizedBox(width: 10),
              _HighLowBadge(label: '24H L', value: formatter.format(low24h), color: AppColors.loss),
            ],
          ),
        ],
      ),
    );

    final chartWidget = Column(
      children: [
        // CoinDCX Style Header: Timeframes (15m, 1H, 4H, 1D, 1W) + Candles/Line + Fullscreen
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(
            children: [
              // Timeframe Pills
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCoinDCXIntervalBtn('15m', '15'),
                      _buildCoinDCXIntervalBtn('1H', '60'),
                      _buildCoinDCXIntervalBtn('4H', '240'),
                      _buildCoinDCXIntervalBtn('1D', 'D'),
                      _buildCoinDCXIntervalBtn('1W', 'W'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Candle / Line Toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _chartStyle = _chartStyle == '1' ? '3' : '1';
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2329),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _chartStyle == '1' ? Icons.candlestick_chart : Icons.show_chart,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _chartStyle == '1' ? 'Candles' : 'Line',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Fullscreen Expand Button
              _ChartFullscreenButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => TradingViewFullScreenPage(
                        symbol: stock.symbol,
                        initialInterval: _tvInterval,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (_chartMode == ChartViewMode.tradingView)
          SizedBox(
            height: _chartHeight,
            child: TradingViewChart(
              key: ValueKey('stock_detail_tv_${stock.symbol}_${_tvInterval}_$_chartStyle'),
              symbol: stock.symbol,
              initialInterval: _tvInterval,
              chartStyle: _chartStyle,
              enableDrawingToolbar: false, // Clean CoinDCX: no squishing sidebar
              showTopToolbar: false, // Clean CoinDCX: no cut-off search bar
              showDateRanges: false, // Clean CoinDCX: no bottom date widget
              showRsi: false, // Clean CoinDCX: full height for candlesticks
              showFullscreenAction: false,
              onToggleNative: () => setState(() => _chartMode = ChartViewMode.candle),
            ),
          )
        else
          SizedBox(
            height: _chartHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _chartMode == ChartViewMode.candle ? SfCartesianChart(
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                    tooltipSettings: const InteractiveTooltip(
                      enable: true,
                      color: Color(0xFF2B3139),
                      textStyle: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  zoomPanBehavior: _zoomPanBehavior,
                  primaryXAxis: DateTimeAxis(
                    onRendererCreated: (controller) => _xAxisController = controller,
                    isVisible: true,
                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLine: const AxisLine(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    onRendererCreated: (controller) => _yAxisController = controller,
                    isVisible: true,
                    opposedPosition: true,
                    minimum: minPrice * 0.99,
                    maximum: maxPrice * 1.01,
                    interval: _computeYInterval(minPrice * 0.99, maxPrice * 1.01),
                    numberFormat: NumberFormat.compact(locale: 'en_IN'),
                    decimalPlaces: 1,
                    axisLabelFormatter: (AxisLabelRenderDetails details) {
                      final val = details.value.toDouble();
                      final conv = CurrencyFormatters.convert(val, userState.profile.preferredCurrency);
                      final sym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
                      final String label;
                      if (userState.profile.preferredCurrency == 'INR') {
                        if (conv >= 1e7) {
                          label = '$sym${(conv / 1e7).toStringAsFixed(1)}Cr';
                        } else if (conv >= 1e5) {
                          label = '$sym${(conv / 1e5).toStringAsFixed(1)}L';
                        } else if (conv >= 1e3) {
                          label = '$sym${(conv / 1e3).toStringAsFixed(1)}K';
                        } else {
                          label = '$sym${conv.toStringAsFixed(0)}';
                        }
                      } else {
                        if (conv >= 1e6) {
                          label = '$sym${(conv / 1e6).toStringAsFixed(1)}M';
                        } else if (conv >= 1e3) {
                          label = '$sym${(conv / 1e3).toStringAsFixed(1)}K';
                        } else if (conv >= 1) {
                          label = '$sym${conv.toStringAsFixed(conv >= 100 ? 0 : 1)}';
                        } else {
                          label = '$sym${conv.toStringAsFixed(2)}';
                        }
                      }
                      return ChartAxisLabel(label, const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500));
                    },
                    majorGridLines: const MajorGridLines(width: 0.5, color: Colors.white10),
                    axisLine: const AxisLine(width: 0),
                  ),
                  plotAreaBorderWidth: 0,
                  margin: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  series: <CartesianSeries<StockCandle, DateTime>>[
                    CandleSeries<StockCandle, DateTime>(
                      name: stock.symbol,
                      dataSource: activeCandles.isEmpty ? [StockCandle(date: DateTime.now(), open: stock.currentPrice, high: stock.currentPrice, low: stock.currentPrice, close: stock.currentPrice, volume: 0)] : activeCandles,
                      xValueMapper: (StockCandle s, _) => s.date,
                      lowValueMapper: (StockCandle s, _) => s.low,
                      highValueMapper: (StockCandle s, _) => s.high,
                      openValueMapper: (StockCandle s, _) => s.open,
                      closeValueMapper: (StockCandle s, _) => s.close,
                      bearColor: AppColors.loss,
                      bullColor: AppColors.profit,
                      enableSolidCandles: true,
                    )
                  ],
                ) : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 62,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                            final conv = CurrencyFormatters.convert(value, userState.profile.preferredCurrency);
                            final sym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
                            final String label;
                            if (userState.profile.preferredCurrency == 'INR') {
                              if (conv >= 1e7) {
                                label = '$sym${(conv / 1e7).toStringAsFixed(1)}Cr';
                              } else if (conv >= 1e5) {
                                label = '$sym${(conv / 1e5).toStringAsFixed(1)}L';
                              } else if (conv >= 1e3) {
                                label = '$sym${(conv / 1e3).toStringAsFixed(1)}K';
                              } else {
                                label = '$sym${conv.toStringAsFixed(0)}';
                              }
                            } else {
                              if (conv >= 1e6) {
                                label = '$sym${(conv / 1e6).toStringAsFixed(1)}M';
                              } else if (conv >= 1e3) {
                                label = '$sym${(conv / 1e3).toStringAsFixed(1)}K';
                              } else if (conv >= 1) {
                                label = '$sym${conv.toStringAsFixed(conv >= 100 ? 0 : 1)}';
                              } else {
                                label = '$sym${conv.toStringAsFixed(2)}';
                              }
                            }
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: minPrice * 0.99,
                    maxY: maxPrice * 1.01,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1E2329),
                        tooltipBorder: BorderSide(color: color.withValues(alpha: 0.4)),
                        getTooltipItems: (spots) => spots.map((s) {
                          if (activeCandles.isEmpty) return null;
                          final idx = s.x.toInt().clamp(0, activeCandles.length - 1);
                          final candle = activeCandles[idx];
                          final fmt = DateFormat('d MMM  HH:mm');
                          return LineTooltipItem(
                            '${formatter.format(s.y)}\n',
                            TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
                            children: [
                              TextSpan(
                                text: fmt.format(candle.date),
                                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w400),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((i) {
                        return TouchedSpotIndicatorData(
                          FlLine(color: color.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [4, 4]),
                          FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(radius: 5, color: color, strokeWidth: 2, strokeColor: Colors.white)),
                        );
                      }).toList(),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: color,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.25),
                              color.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoadingRange)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ),
                ),
              // Drag zones for zoom
              Positioned(
                bottom: 0, left: 0, right: 0, height: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (_xAxisController != null) {
                      double currentFactor = _xAxisController!.zoomFactor;
                      double currentPos = _xAxisController!.zoomPosition;
                      double rightEdge = currentPos + currentFactor;
                      double newFactor = currentFactor - (details.primaryDelta! * 0.005);
                      newFactor = newFactor.clamp(0.05, 1.0);
                      double newPos = rightEdge - newFactor;
                      newPos = newPos.clamp(0.0, 1.0 - newFactor);
                      _xAxisController!.zoomFactor = newFactor;
                      _xAxisController!.zoomPosition = newPos;
                    }
                  },
                ),
              ),
              Positioned(
                top: 0, bottom: 0, right: 0, width: 50,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (_yAxisController != null) {
                      double currentFactor = _yAxisController!.zoomFactor;
                      double currentPos = _yAxisController!.zoomPosition;
                      double center = currentPos + (currentFactor / 2);
                      double newFactor = currentFactor + (details.primaryDelta! * 0.005);
                      newFactor = newFactor.clamp(0.05, 1.0);
                      double newPos = center - (newFactor / 2);
                      newPos = newPos.clamp(0.0, 1.0 - newFactor);
                      _yAxisController!.zoomFactor = newFactor;
                      _yAxisController!.zoomPosition = newPos;
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (_chartMode != ChartViewMode.tradingView)
          // Range selector row — below chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: ['1D', '1W', '1M', '1Y', '5Y'].map((r) {
                      final isSelected = _range == r;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_range != r) _fetchRangeData(r, widget.stockSymbol);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              r,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? color : Colors.white38,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _chartMode = _chartMode == ChartViewMode.candle ? ChartViewMode.line : ChartViewMode.candle),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2329),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Icon(
                      _chartMode == ChartViewMode.candle ? Icons.show_chart : Icons.candlestick_chart,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Center resize notch handle to drag and resize graph height
        _buildChartResizeHandle(),
      ],
    );

    final tabsWidget = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            _buildTab(0, 'Order Book', color),
            const SizedBox(width: 24),
            _buildTab(1, 'Positions', color),
            const SizedBox(width: 24),
            _buildTab(2, 'Info', color),
          ],
        ),
      ),
    );

    final contentWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildTabContent(stock, holding, userState, formatter),
    );

    final buySellBar = ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.6),
                AppColors.background.withValues(alpha: 0.92),
              ],
            ),
            border: const Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openTradeSheet(context, stock, OrderSide.sell, widget.isFutures),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    foregroundColor: AppColors.loss,
                    side: const BorderSide(color: AppColors.loss, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: AppColors.loss.withValues(alpha: 0.07),
                  ),
                  child: Text(widget.isFutures ? 'SHORT' : 'SELL', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              // Centre price ticker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatter.format(stock.currentPrice),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                      style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () => _openTradeSheet(context, stock, OrderSide.buy, widget.isFutures),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppColors.profit,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(widget.isFutures ? 'LONG' : 'BUY', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: CustomScrollView(
                    slivers: [
                      sliverAppBar,
                      SliverToBoxAdapter(child: headerWidget),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(child: chartWidget),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              tabsWidget,
                              const SizedBox(height: 20),
                              contentWidget,
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                      buySellBar,
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  sliverAppBar,
                  SliverToBoxAdapter(child: headerWidget),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(child: chartWidget),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tabsWidget,
                          const SizedBox(height: 8),
                          contentWidget,
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: buySellBar,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openTradeSheet(BuildContext context, Stock stock, OrderSide side, bool isFutures) {
    if (isFutures) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FuturesTradeSheet(stock: stock, initialSide: side),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _TradeSheet(stock: stock, initialSide: side),
      );
    }
  }

  Widget _buildCoinDCXIntervalBtn(String label, String interval) {
    final isSelected = _tvInterval == interval;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _tvInterval = interval;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2B3139) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.6) : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
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

  Widget _buildTab(int index, String title, Color accentColor) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? accentColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(Stock stock, Holding holding, UserState userState, AppCurrencyFormatter formatter) {
    if (_selectedTab == 0) {
      return _OrderBookWidget(stock: stock);
    } else if (_selectedTab == 1) {
      final trades = userState.trades.where((t) => t.symbol == stock.symbol).toList();
      final pnl = (stock.currentPrice - holding.averagePrice) * holding.quantity;
      final pnlPct = holding.averagePrice > 0
          ? ((stock.currentPrice - holding.averagePrice) / holding.averagePrice) * 100
          : 0.0;
      final pnlColor = pnl >= 0 ? AppColors.profit : AppColors.loss;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (holding.quantity > 0) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141A21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Coloured left accent bar
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: pnlColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Owned', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                Text('${holding.quantity} ${stock.symbol}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Avg Buy Price', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                Text(formatter.format(holding.averagePrice), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Return', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                Row(
                                  children: [
                                    Text(
                                      formatter.format(pnl),
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: pnlColor),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: pnlColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${pnl >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                                        style: TextStyle(color: pnlColor, fontSize: 11, fontWeight: FontWeight.w700),
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
                  ],
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141A21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white38, size: 18),
                  SizedBox(width: 10),
                  Text('You have no open positions for this asset.', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          _OpenLimitOrdersWidget(symbol: stock.symbol),
          const SizedBox(height: 24),
          const Text('Trade History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          if (trades.isEmpty)
            const Text('No trades yet.', style: TextStyle(color: Colors.white54))
          else
            ...trades.reversed.map((t) => _TradeHistoryTile(t)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Market Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard('Market Cap', AppCompactCurrencyFormatter(userState.profile.preferredCurrency).format(stock.marketCap), Icons.bar_chart_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Volume (24h)', NumberFormat.compact().format(stock.volume), Icons.swap_horiz_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard('Circ. Supply', '${NumberFormat.compact().format(stock.supply)} ${stock.symbol}', Icons.currency_bitcoin_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard('Rank', '#${stock.rank}', Icons.emoji_events_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            stock.about,
            style: const TextStyle(color: Colors.white60, height: 1.6, fontSize: 14),
          ),
        ],
      );
    }
  }
}

class _OrderBookWidget extends ConsumerWidget {
  final Stock stock;
  const _OrderBookWidget({required this.stock});

  String _formatQty(double qty) {
    if (qty >= 10000) return '${(qty / 1000).toStringAsFixed(1)}K';
    if (qty >= 1000) return '${(qty / 1000).toStringAsFixed(2)}K';
    if (qty >= 100) return qty.toStringAsFixed(1);
    if (qty >= 1) return qty.toStringAsFixed(3);
    return qty.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final orderBookAsync = ref.watch(
      orderBookProvider(OrderBookParams(symbol: stock.symbol, isFutures: false)),
    );
    final orderBook = orderBookAsync.value;

    final List<OrderBookEntry> bids;
    final List<OrderBookEntry> asks;
    final double maxQty;

    if (orderBook != null && orderBook.bids.isNotEmpty && orderBook.asks.isNotEmpty) {
      bids = orderBook.bids.take(8).toList();
      asks = orderBook.asks.take(8).toList();
      maxQty = orderBook.maxQty;
    } else {
      // Graceful fallback while connecting or if pair not on Binance
      final random = Random(stock.currentPrice.toInt() + DateTime.now().second);
      asks = List.generate(8, (i) {
        final price = stock.currentPrice + (random.nextDouble() * stock.currentPrice * 0.001) + (i * stock.currentPrice * 0.0005);
        final qty = random.nextDouble() * 5 + 0.1;
        return OrderBookEntry(price: price, rawPrice: price / CurrencyFormatters.usdToInr, qty: qty);
      }).reversed.toList();

      bids = List.generate(8, (i) {
        final price = stock.currentPrice - (random.nextDouble() * stock.currentPrice * 0.001) - (i * stock.currentPrice * 0.0005);
        final qty = random.nextDouble() * 5 + 0.1;
        return OrderBookEntry(price: price, rawPrice: price / CurrencyFormatters.usdToInr, qty: qty);
      });
      maxQty = [...bids.map((b) => b.qty), ...asks.map((a) => a.qty)].reduce(max);
    }

    final isLive = orderBook?.isLive ?? false;

    return Column(
      children: [
        // Live status indicator bar
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isLive ? AppColors.profit : Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLive ? 'LIVE DEPTH (BINANCE)' : 'CONNECTING BINANCE...',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (orderBook?.lastUpdated != null)
                Text(
                  '${orderBook!.lastUpdated!.hour.toString().padLeft(2, '0')}:${orderBook.lastUpdated!.minute.toString().padLeft(2, '0')}:${orderBook.lastUpdated!.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
            ],
          ),
        ),
        // Header row
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bid Qty', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Bid Price', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ask Price', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Ask Qty', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Rows
        ...List.generate(min(bids.length, asks.length), (i) {
          final bid = bids[i];
          final ask = asks[i];
          final bidFraction = (bid.qty / maxQty).clamp(0.0, 1.0);
          final askFraction = (ask.qty / maxQty).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                // Bid side
                Expanded(
                  child: Stack(
                    children: [
                      // Depth bar
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor: bidFraction,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.profit.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatQty(bid.qty), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            Text(formatter.format(bid.price), style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Ask side
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: askFraction,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.loss.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formatter.format(ask.price), style: const TextStyle(color: AppColors.loss, fontWeight: FontWeight.w700, fontSize: 12)),
                            Text(_formatQty(ask.qty), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TradeHistoryTile extends ConsumerWidget {
  final Trade trade;
  const _TradeHistoryTile(this.trade);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final isBuy = trade.side == OrderSide.buy;
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: isBuy ? AppColors.profit : AppColors.loss, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isBuy ? 'Bought' : 'Sold', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(trade.time.toString().split('.')[0], style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatter.format(trade.price), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${trade.quantity} ${trade.symbol}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white38),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
        ],
      ),
    );
  }
}

class _TradeSheet extends ConsumerStatefulWidget {
  final Stock stock;
  final OrderSide initialSide;
  const _TradeSheet({required this.stock, required this.initialSide});

  @override
  ConsumerState<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends ConsumerState<_TradeSheet> {
  late OrderSide _side;
  String _orderType = 'Market'; // 'Market' or 'Limit'
  bool _isCryptoInput = true;
  final _inputController = TextEditingController();
  final _targetPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    _targetPriceController.text = widget.stock.currentPrice.toStringAsFixed(2);
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
  double get _targetPrice => _orderType == 'Limit' ? (double.tryParse(_targetPriceController.text) ?? _liveStock.currentPrice) : _liveStock.currentPrice;

  int get _cryptoQty => _isCryptoInput ? _inputVal.floor() : (_inputVal / _targetPrice).floor();
  double get _fiatAmount => _isCryptoInput ? (_inputVal * _targetPrice) : _inputVal;

  int _getOwnedQty(UserState state) {
    final h = state.holdings.firstWhere((e) => e.symbol == widget.stock.symbol, orElse: () => Holding(symbol: widget.stock.symbol, quantity: 0, averagePrice: 0));
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
                        child: Text('Buy', style: TextStyle(fontWeight: FontWeight.bold, color: isBuy ? Colors.white : Colors.white54)),
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
                        child: Text('Sell', style: TextStyle(fontWeight: FontWeight.bold, color: !isBuy ? Colors.white : Colors.white54)),
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
            const SizedBox(height: 20),

            // Target Price Input (If Limit Order)
            if (isLimit) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target Limit Price', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Market: ${formatter.format(widget.stock.currentPrice)}', style: const TextStyle(color: AppColors.subtle, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning),
                decoration: InputDecoration(
                  labelText: 'Target Price ($currSym)',
                  labelStyle: const TextStyle(fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.track_changes_rounded, color: AppColors.warning, size: 18),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isBuy ? 'Available: ${formatter.format(userState.profile.virtualBalance)}' : 'Available: $ownedQty ${widget.stock.symbol}', style: const TextStyle(color: Colors.white60)),
                GestureDetector(
                  onTap: () => setState(() {
                    _isCryptoInput = !_isCryptoInput;
                    _inputController.clear();
                  }),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(_isCryptoInput ? 'Input in $currSym' : 'Input in ${widget.stock.symbol}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isLimit ? 'Limit Target Price' : 'Market price', style: const TextStyle(color: Colors.white60)), Text(formatter.format(execPrice), style: TextStyle(fontWeight: FontWeight.bold, color: isLimit ? AppColors.warning : Colors.white))]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Estimated value', style: TextStyle(color: Colors.white60)), Text(formatter.format(totalCost), style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Est. Trading Fee (0.1%)', style: TextStyle(color: Colors.white60)), Text(formatter.format(fee), style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white10)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isLimit ? 'Total Reserved' : 'Total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(formatter.format(totalWithFee), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
                ],
              ),
            ),
            if (_inputVal > 0 && _cryptoQty <= 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Text('Minimum order is 1 ${widget.stock.symbol} (${formatter.format(execPrice)})', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600)),
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
              onPressed: canExecute ? () {
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
                      const SnackBar(content: Text('Order executed successfully!'), backgroundColor: AppColors.profit),
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
              } : null,
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
                    : (isLimit ? 'Place Limit ${isBuy ? "Buy" : "Sell"}' : (isBuy ? 'Confirm Buy' : 'Confirm Sell')),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
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

class _OpenLimitOrdersWidget extends ConsumerWidget {
  final String symbol;
  const _OpenLimitOrdersWidget({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final pendingOrders = userState.spotLimitOrders
        .where((o) => o.symbol == symbol && o.status == 'pending')
        .toList();

    if (pendingOrders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_rounded, color: AppColors.warning, size: 18),
                SizedBox(width: 6),
                Text('Open Limit Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${pendingOrders.length} ACTIVE',
                style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pendingOrders.map((order) {
          final isBuy = order.side == OrderSide.buy;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141A21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isBuy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isBuy ? 'LIMIT BUY' : 'LIMIT SELL',
                    style: TextStyle(
                      color: isBuy ? AppColors.profit : AppColors.loss,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target: ${formatter.format(order.targetPrice)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Qty: ${order.quantity} $symbol',
                        style: const TextStyle(color: AppColors.subtle, fontSize: 11),
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
                  child: const Text('Cancel', style: TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── High/Low badge widget ─────────────────────────────────────────────────────
class _HighLowBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HighLowBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ChartFullscreenButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ChartFullscreenButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Fullscreen Chart',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2329),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(Icons.fullscreen, color: Colors.white70, size: 18),
          ),
        ),
      ),
    );
  }
}

