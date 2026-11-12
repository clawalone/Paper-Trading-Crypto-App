import 'dart:async';
import 'dart:math';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/app_theme.dart';
import '../../core/app_review_manager.dart';
import '../../core/coin_icon.dart';
import '../../core/currency_formatters.dart';
import '../../data/market_provider.dart';
import '../../data/stock_market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';
import 'futures_position_card.dart';
import '../../core/trading_view_chart.dart';
import '../../data/order_book_provider.dart';

class FuturesProScreen extends ConsumerStatefulWidget {
  final String stockSymbol;
  const FuturesProScreen({required this.stockSymbol, super.key});

  @override
  ConsumerState<FuturesProScreen> createState() => _FuturesProScreenState();
}

class _FuturesProScreenState extends ConsumerState<FuturesProScreen> {
  int _selectedTab = 0; // 0: Trade, 1: Positions, 2: Orders
  bool _useTradingView = true;
  double _chartHeight = 300.0;
  bool _isResizingChart = false;
  OrderSide _side = OrderSide.buy;
  double _leverage = 1;
  String _orderType = 'Market';
  final _qtyController = TextEditingController();
  final _limitPriceController = TextEditingController();
  bool _isInrInput = false; // false = input in coin, true = input in INR
  late ZoomPanBehavior _zoomPanBehavior;
  DateTimeAxisController? _xAxisController;
  NumericAxisController? _yAxisController;
  Timer? _candleTimeoutTimer;
  bool _candleTimedOut = false;

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
    _startCandleTimeout();
  }

  void _startCandleTimeout() {
    _candleTimeoutTimer?.cancel();
    _candleTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _candleTimedOut = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _candleTimeoutTimer?.cancel();
    _qtyController.dispose();
    _limitPriceController.dispose();
    super.dispose();
  }

  void _showOrderTypeSheet(BuildContext context, Stock stock) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Type',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: AppColors.subtle, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildOrderTypeOption(
                ctx,
                type: 'Market',
                title: 'Market Order',
                subtitle: 'Executes immediately at best available live price',
                icon: Icons.bolt,
              ),
              const SizedBox(height: 10),
              _buildOrderTypeOption(
                ctx,
                type: 'Limit',
                title: 'Limit Order',
                subtitle: 'Executes when market reaches your target price',
                icon: Icons.tune,
                stockPrice: stock.currentPrice,
              ),
              const SizedBox(height: 10),
              _buildOrderTypeOption(
                ctx,
                type: 'Stop-Limit',
                title: 'Stop-Limit Order',
                subtitle: 'Triggers a limit order once stop price is reached',
                icon: Icons.shield_outlined,
                stockPrice: stock.currentPrice,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderTypeOption(
    BuildContext ctx, {
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    double? stockPrice,
  }) {
    final isSelected = _orderType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _orderType = type;
          if (type != 'Market' && stockPrice != null && (_limitPriceController.text.isEmpty || double.tryParse(_limitPriceController.text) == 0)) {
            _limitPriceController.text = stockPrice.toStringAsFixed(2);
          }
        });
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceAlt : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.subtle, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppColors.subtle, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  void _showLeverageSheet(BuildContext context) {
    double tempLeverage = _leverage;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isHighRisk = tempLeverage > 20;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Adjust Leverage',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${tempLeverage.toInt()}x',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick preset chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 5, 10, 20, 25, 50, 75, 100].map((lev) {
                      final isSel = tempLeverage.toInt() == lev;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => tempLeverage = lev.toDouble());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSel ? AppColors.primary : AppColors.outline),
                          ),
                          child: Text(
                            '${lev}x',
                            style: TextStyle(
                              color: isSel ? Colors.black : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Fine slider
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.outline,
                      thumbColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: tempLeverage,
                      min: 1,
                      max: 100,
                      onChanged: (v) {
                        setModalState(() => tempLeverage = v);
                      },
                    ),
                  ),

                  if (isHighRisk) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.loss.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.loss, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'High Leverage Alert: Higher leverage increases liquidation risk.',
                              style: TextStyle(color: AppColors.loss, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          _leverage = tempLeverage;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'Confirm ${tempLeverage.toInt()}x Leverage',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double get _inputVal => double.tryParse(_qtyController.text) ?? 0.0;



  void _setPercent(double pct, double balance, double price) {
    final maxInr = balance;
    if (_isInrInput) {
      _qtyController.text = (maxInr * pct).toStringAsFixed(2);
    } else {
      _qtyController.text = ((maxInr * pct) / price).toStringAsFixed(4);
    }
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    final cryptoMarket = ref.watch(marketProvider);
    final stockMarket = ref.watch(stockMarketProvider);
    final userState = ref.watch(userProvider);
    final cleanTarget = CoinIcon.cleanSymbol(widget.stockSymbol);

    final allMarket = [...stockMarket, ...cryptoMarket];
    final market = allMarket;
    final stock = allMarket.firstWhere(
      (s) {
        if (s.symbol.toUpperCase() == widget.stockSymbol.toUpperCase()) return true;
        final cleanS = CoinIcon.cleanSymbol(s.symbol);
        if (cleanS == cleanTarget) return true;
        if (cleanS.replaceAll('1000', '') == cleanTarget.replaceAll('1000', '')) return true;
        if (s.name.toUpperCase() == cleanTarget) return true;
        if (s.name.toUpperCase() == widget.stockSymbol.toUpperCase()) return true;
        if (s.symbol.toUpperCase().replaceAll('.NS', '') == widget.stockSymbol.toUpperCase().replaceAll('.NS', '')) return true;
        return false;
      },
      orElse: () {
        final meta = kStockAssets.cast<StockAssetMeta?>().firstWhere(
          (m) => m != null && (m.symbol.toUpperCase() == widget.stockSymbol.toUpperCase() || CoinIcon.cleanSymbol(m.symbol) == cleanTarget),
          orElse: () => null,
        );
        if (meta != null) {
          return Stock(
            symbol: meta.symbol,
            name: meta.name,
            category: meta.category,
            currentPrice: meta.defaultPrice,
            previousClose: meta.defaultPrice,
            dayHigh: meta.defaultPrice * 1.02,
            dayLow: meta.defaultPrice * 0.98,
            volume: 1000000,
            history: const [],
            candleHistory: const [],
            about: meta.name,
            supply: 10000000,
            rank: 99,
            isStock: true,
            currency: meta.currency,
          );
        }
        return Stock(
          symbol: widget.stockSymbol,
          name: widget.stockSymbol,
          category: 'Crypto',
          currentPrice: 100.0 * CurrencyFormatters.usdToInr,
          previousClose: 100.0 * CurrencyFormatters.usdToInr,
          dayHigh: 105.0 * CurrencyFormatters.usdToInr,
          dayLow: 95.0 * CurrencyFormatters.usdToInr,
          volume: 150000,
          history: const [],
          candleHistory: const [],
          about: '',
          supply: 1000000,
          rank: 999,
        );
      },
    );
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);
    final good = stock.changePercentage >= 0;
    final isWatched = userState.profile.watchlist.contains(stock.symbol);

    final effectiveCandles = stock.candleHistory.isNotEmpty
        ? stock.candleHistory
        : (stock.history.length >= 2
            ? stock.history.asMap().entries.map((e) => StockCandle(
                date: DateTime.now().subtract(Duration(hours: stock.history.length - e.key)),
                open: e.value,
                high: e.value * 1.002,
                low: e.value * 0.998,
                close: e.value,
                volume: 1000,
              )).toList()
            : (stock.currentPrice > 0 ? MarketNotifier.generateFallbackCandles(stock.currentPrice) : const <StockCandle>[]));

    if (effectiveCandles.isEmpty && stock.currentPrice <= 0) {
      if (!_candleTimedOut) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Text('${stock.symbol}-PERP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                const SizedBox(height: 16),
                Text('Loading ${stock.symbol} chart...', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text('${stock.symbol}-PERP', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
                  'Unable to load ${stock.symbol}-PERP chart',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Market candle data is slow to respond or unavailable. Please check your connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _candleTimedOut = false;
                      _startCandleTimeout();
                    });
                    ref.read(marketProvider.notifier).refresh();
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

    final minPrice = effectiveCandles.isEmpty ? 0.0 : effectiveCandles.map((c) => c.low).reduce(min);
    final maxPrice = effectiveCandles.isEmpty ? 0.0 : effectiveCandles.map((c) => c.high).reduce(max);

    DateTime? nativeVisibleMin;
    DateTime? nativeVisibleMax;
    if (effectiveCandles.length > 35) {
      nativeVisibleMin = effectiveCandles[effectiveCandles.length - 35].date;
      final lastDate = effectiveCandles.last.date;
      final secondLastDate = effectiveCandles[effectiveCandles.length - 2].date;
      final diffMin = lastDate.difference(secondLastDate).inMinutes.clamp(1, 1440);
      nativeVisibleMax = lastDate.add(Duration(minutes: diffMin * 4));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            CoinIcon(symbol: stock.symbol, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                stock.isStock ? '${stock.symbol} Margin' : '${stock.symbol}-PERP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: (good ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text('${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%', style: TextStyle(color: good ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(userProvider.notifier).toggleWatchlist(stock.symbol);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isWatched
                        ? 'Removed ${stock.symbol} from Watchlist'
                        : 'Added ${stock.symbol} to Watchlist',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              isWatched ? Icons.star : Icons.star_border,
              color: isWatched ? Colors.amber : AppColors.subtle,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'contract_info') {
                _showContractInfoSheet(context, stock, formatter);
              } else if (value == 'share') {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${stock.symbol}-PERP: ${formatter.format(stock.currentPrice)} (${good ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%)'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (value == 'reset_zoom') {
                _zoomPanBehavior.reset();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'contract_info',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF848E9C), size: 20),
                    const SizedBox(width: 12),
                    Text('Contract Info', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_zoom',
                child: Row(
                  children: [
                    const Icon(Icons.center_focus_strong, color: Color(0xFF848E9C), size: 20),
                    const SizedBox(width: 12),
                    Text('Reset Chart Zoom', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.share, color: Color(0xFF848E9C), size: 20),
                    const SizedBox(width: 12),
                    Text('Share Details', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          final chartWidget = Column(
            children: [
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: AppColors.surfaceAlt,
                child: Row(
                  children: [
                    _buildFuturesChartToggle(
                      title: 'TradingView',
                      active: _useTradingView,
                      badge: 'TV',
                      onTap: () => setState(() => _useTradingView = true),
                    ),
                    const SizedBox(width: 6),
                    _buildFuturesChartToggle(
                      title: 'Original',
                      active: !_useTradingView,
                      onTap: () => setState(() => _useTradingView = false),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: AppColors.textPrimary, size: 18),
                      tooltip: 'Fullscreen Chart',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => TradingViewFullScreenPage(
                              symbol: stock.symbol,
                              initialInterval: '15',
                              isFutures: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _useTradingView
                    ? TradingViewChart(
                        key: ValueKey('futures_tv_${stock.symbol}_${AppColors.isDarkMode}'),
                        symbol: stock.symbol,
                        isFutures: true,
                        enableDrawingToolbar: false,
                        showTopToolbar: false,
                        showDateRanges: false,
                        showRsi: false,
                        showFullscreenAction: false,
                        onToggleNative: () => setState(() => _useTradingView = false),
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: SfCartesianChart(
                              trackballBehavior: TrackballBehavior(
                                enable: true,
                                activationMode: ActivationMode.singleTap,
                                tooltipSettings: InteractiveTooltip(enable: true, color: AppColors.surface),
                              ),
                              zoomPanBehavior: _zoomPanBehavior,
                              plotAreaBorderWidth: 0,
                              margin: EdgeInsets.zero,
                              primaryXAxis: DateTimeAxis(
                                onRendererCreated: (controller) => _xAxisController = controller,
                                isVisible: true,
                                initialVisibleMinimum: nativeVisibleMin,
                                initialVisibleMaximum: nativeVisibleMax,
                                majorGridLines: const MajorGridLines(width: 0),
                              ),
                              primaryYAxis: NumericAxis(
                                onRendererCreated: (controller) => _yAxisController = controller,
                                isVisible: true,
                                opposedPosition: true,
                                minimum: minPrice * 0.99,
                                maximum: maxPrice * 1.01,
                                majorGridLines: MajorGridLines(width: 0.5, color: AppColors.outline),
                              ),
                              axes: <ChartAxis>[
                                NumericAxis(
                                  name: 'VolumeAxis',
                                  opposedPosition: true,
                                  isVisible: false,
                                  minimum: 0,
                                  maximum: effectiveCandles.isEmpty ? 100 : effectiveCandles.map((c) => c.volume).reduce(max) * 4,
                                )
                              ],
                              series: <CartesianSeries>[
                                ColumnSeries<StockCandle, DateTime>(
                                  dataSource: effectiveCandles,
                                  xValueMapper: (data, _) => data.date,
                                  yValueMapper: (data, _) => data.volume,
                                  yAxisName: 'VolumeAxis',
                                  pointColorMapper: (data, _) => data.close >= data.open ? AppColors.profit.withValues(alpha: 0.5) : AppColors.loss.withValues(alpha: 0.5),
                                ),
                                CandleSeries<StockCandle, DateTime>(
                                  dataSource: effectiveCandles,
                                  xValueMapper: (data, _) => data.date,
                                  lowValueMapper: (data, _) => data.low,
                                  highValueMapper: (data, _) => data.high,
                                  openValueMapper: (data, _) => data.open,
                                  closeValueMapper: (data, _) => data.close,
                                  bearColor: AppColors.loss,
                                  bullColor: AppColors.profit,
                                  enableSolidCandles: true,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 36,
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
                              child: Container(
                                alignment: Alignment.center,
                                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2))),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: 50,
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
            ],
          );

          final activePositionsCount = userState.futuresPositions.where((pos) {
            final stockIdx = market.indexWhere((s) => s.symbol == pos.symbol);
            if (stockIdx < 0) return true;
            return !pos.isLiquidated(market[stockIdx].currentPrice);
          }).length;
          final pendingOrdersCount = userState.futuresLimitOrders.where((o) => o.status == 'pending').length;

          if (isDesktop) {
            return Container(
              color: AppColors.background, // Global dark background
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        Expanded(flex: 6, child: _PanelCard(child: chartWidget)),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 4,
                          child: _PanelCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outline))),
                                  child: Row(
                                    children: [
                                      _buildTab(1, 'Positions ($activePositionsCount)'),
                                      _buildTab(2, 'Orders ($pendingOrdersCount)'),
                                    ],
                                  ),
                                ),
                                Expanded(child: _selectedTab == 2 ? _buildOrdersTab(userState, market, formatter) : _buildPositionsTab(userState, market, formatter)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _PanelCard(
                      child: _buildOrderBookPanel(stock, formatter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _PanelCard(
                      child: _buildTradeFormPanel(stock, userState, formatter),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              SizedBox(height: _chartHeight, child: chartWidget),
              _buildChartResizeHandle(),
              Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outline))),
                child: Row(
                  children: [
                    _buildTab(0, 'Trade'),
                    _buildTab(1, 'Positions ($activePositionsCount)'),
                    _buildTab(2, 'Orders ($pendingOrdersCount)'),
                  ],
                ),
              ),
              Expanded(
                child: _selectedTab == 0
                    ? _buildTradeInterface(stock, userState, formatter)
                    : (_selectedTab == 2
                        ? _buildOrdersTab(userState, market, formatter)
                        : _buildPositionsTab(userState, market, formatter)),
              ),
            ],
          );
        },
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
          _chartHeight = (_chartHeight + details.delta.dy).clamp(180.0, 550.0);
        });
      },
      onDoubleTap: () {
        setState(() {
          _chartHeight = 300.0;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(
          width: double.infinity,
          height: 20,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isResizingChart ? 64 : 48,
            height: _isResizingChart ? 6 : 5,
            decoration: BoxDecoration(
              color: _isResizingChart
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: AppColors.isDarkMode ? 0.40 : 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isResizingChart
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: AppColors.isDarkMode ? 0.85 : 0.70),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: _isResizingChart ? 0.5 : 0.18),
                  blurRadius: _isResizingChart ? 8 : 4,
                  spreadRadius: _isResizingChart ? 1 : 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFuturesChartToggle({
    required String title,
    required bool active,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: active ? Border.all(color: AppColors.outline) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2962FF),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            Text(
              title,
              style: TextStyle(
                color: active ? AppColors.textPrimary : AppColors.subtle,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.textPrimary : AppColors.subtle,
          ),
        ),
      ),
    );
  }

  Widget _buildTradeInterface(Stock stock, UserState userState, AppCurrencyFormatter formatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: _buildOrderBookPanel(stock, formatter)),
          Expanded(flex: 5, child: _buildTradeFormPanel(stock, userState, formatter)),
        ],
      ),
    );
  }

  Widget _buildOrderBookPanel(Stock stock, AppCurrencyFormatter formatter) {
    final orderBookAsync = ref.watch(
      orderBookProvider(OrderBookParams(symbol: stock.symbol, isFutures: true)),
    );
    final orderBook = orderBookAsync.value;

    final List<OrderBookEntry> asks;
    final List<OrderBookEntry> bids;
    final double maxQty;

    if (orderBook != null && orderBook.bids.isNotEmpty && orderBook.asks.isNotEmpty) {
      // Top 5 asks: reversed so lowest ask is closest to center current price
      asks = orderBook.asks.take(5).toList().reversed.toList();
      bids = orderBook.bids.take(5).toList();
      maxQty = orderBook.maxQty;
    } else {
      // Graceful fallback while connecting
      asks = List.generate(5, (i) {
        final price = stock.currentPrice * (1 + 0.0005 * (5 - i));
        final amount = (stock.volume * 0.01) * (1 + sin(i));
        return OrderBookEntry(price: price, rawPrice: price / CurrencyFormatters.usdToInr, qty: amount);
      });
      bids = List.generate(5, (i) {
        final price = stock.currentPrice * (1 - 0.0005 * (i + 1));
        final amount = (stock.volume * 0.01) * (1 + cos(i));
        return OrderBookEntry(price: price, rawPrice: price / CurrencyFormatters.usdToInr, qty: amount);
      });
      maxQty = [...bids.map((b) => b.qty), ...asks.map((a) => a.qty)].reduce(max);
    }

    final isLive = orderBook?.isLive ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isLive ? AppColors.profit : Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Price', style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              Text('Amount', style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          // Asks (Red)
          ...asks.map((ask) => _buildOrderRow(ask, AppColors.loss, formatter, maxQty, true)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatter.format(stock.currentPrice),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: stock.changePercentage >= 0 ? AppColors.profit : AppColors.loss,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  stock.changePercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 15,
                  color: stock.changePercentage >= 0 ? AppColors.profit : AppColors.loss,
                ),
              ],
            ),
          ),
          // Bids (Green)
          ...bids.map((bid) => _buildOrderRow(bid, AppColors.profit, formatter, maxQty, false)),
        ],
      ),
    );
  }

  Widget _buildTradeFormPanel(Stock stock, UserState userState, AppCurrencyFormatter formatter) {
    final isMarketOnline = ref.watch(marketOnlineProvider);
    final currSym = CurrencyFormatters.getSymbol(userState.profile.preferredCurrency);
    final customLimitPrice = _orderType != 'Market' ? double.tryParse(_limitPriceController.text) : null;
    final targetPrice = (_orderType != 'Market' && customLimitPrice != null && customLimitPrice > 0)
        ? customLimitPrice
        : stock.currentPrice;
    final quantity = _isInrInput ? (_inputVal > 0 ? _inputVal / targetPrice : 0.0) : _inputVal;
    final marginRequired = (quantity > 0) ? (quantity * targetPrice) / _leverage : 0.0;
    final hasValidPrice = _orderType == 'Market' || (customLimitPrice != null && customLimitPrice > 0);
    final isLimitPlausible = _orderType == 'Market' || (
      targetPrice >= stock.currentPrice * 0.70 && targetPrice <= stock.currentPrice * 1.30
    );
    final canExecute = isMarketOnline && stock.isLive && stock.currentPrice > 0 && quantity > 0 && marginRequired <= userState.profile.virtualBalance && hasValidPrice && isLimitPlausible;
    final isLong = _side == OrderSide.buy;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Long / Short Toggle
            Container(
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.buy),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isLong ? AppColors.surfaceAlt : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isLong ? Border.all(color: AppColors.outline) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text('Long', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isLong ? AppColors.profit : AppColors.subtle)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _side = OrderSide.sell),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isLong ? AppColors.surfaceAlt : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: !isLong ? Border.all(color: AppColors.outline) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text('Short', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: !isLong ? AppColors.loss : AppColors.subtle)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Order Type / Leverage Row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showOrderTypeSheet(context, stock),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _orderType,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showLeverageSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${_leverage.toInt()}x',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_orderType != 'Market') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Limit Price ($currSym)', style: TextStyle(fontSize: 12, color: AppColors.subtle, fontWeight: FontWeight.w600)),
                  GestureDetector(
                    onTap: () => setState(() => _limitPriceController.text = stock.currentPrice.toStringAsFixed(2)),
                    child: const Text('Use Last Price', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _limitPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: stock.currentPrice.toStringAsFixed(2),
                  hintStyle: TextStyle(color: AppColors.subtle, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.outline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.outline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isLong ? AppColors.profit : AppColors.loss, width: 1.5)),
                  suffixText: currSym,
                  suffixStyle: TextStyle(color: AppColors.subtle, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            // Slider for Leverage
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.outline,
                thumbColor: AppColors.primary,
              ),
              child: Slider(
                value: _leverage,
                min: 1, max: 100,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.outline,
                onChanged: (v) => setState(() => _leverage = v),
              ),
            ),
            const SizedBox(height: 16),
            // Size Input Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isInrInput ? 'Size ($currSym)' : 'Size (${stock.symbol})',
                  style: TextStyle(fontSize: 12, color: AppColors.subtle, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _isInrInput = !_isInrInput;
                    _qtyController.clear();
                  }),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _isInrInput ? 'Switch to ${stock.symbol}' : 'Switch to $currSym',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Size Input
            TextField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintText: _isInrInput ? 'Enter amount in $currSym' : 'Enter qty in ${stock.symbol}',
                hintStyle: TextStyle(color: AppColors.subtle, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.outline)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.outline)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: isLong ? AppColors.profit : AppColors.loss, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                suffixText: _isInrInput ? currSym : stock.symbol,
                suffixStyle: TextStyle(color: AppColors.subtle, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Preview
            if (_inputVal > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isInrInput
                            ? '≈ ${(_inputVal / targetPrice).toStringAsFixed(6)} ${stock.symbol}'
                            : '≈ ${formatter.format(_inputVal * targetPrice)}',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Quick % buttons
            Row(
              children: [25, 50, 75, 100].map((pct) {
                final label = pct == 100 ? 'MAX' : '$pct%';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _setPercent(pct / 100, userState.profile.virtualBalance, targetPrice),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.outline),
                        ),
                        alignment: Alignment.center,
                        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Margin Required', style: TextStyle(fontSize: 12, color: AppColors.subtle)),
                const SizedBox(height: 4),
                Text(
                  formatter.format(marginRequired),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available Balance', style: TextStyle(fontSize: 12, color: AppColors.subtle)),
                const SizedBox(height: 4),
                Text(
                  formatter.format(userState.profile.virtualBalance),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!isMarketOnline || !stock.isLive)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6465D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF6465D).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem_rounded, color: Color(0xFFF6465D), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        !isMarketOnline
                            ? 'Connecting to live market. Futures trading locked.'
                            : 'Syncing real-time futures price for ${stock.symbol}...',
                        style: const TextStyle(color: Color(0xFFF6465D), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton(
              onPressed: canExecute ? () {
                if (_orderType == 'Market') {
                  final success = ref.read(userProvider.notifier).openFuturesPosition(
                    stock,
                    _side,
                    _leverage.toInt(),
                    quantity,
                    orderType: 'Market',
                  );
                  if (success) {
                    _qtyController.clear();
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Market Position opened successfully!'),
                        backgroundColor: AppColors.profit,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  final target = customLimitPrice ?? stock.currentPrice;
                  final success = ref.read(userProvider.notifier).placeFuturesLimitOrder(
                    stock: stock,
                    side: _side,
                    leverage: _leverage.toInt(),
                    quantity: quantity,
                    targetPrice: target,
                    orderType: _orderType,
                  );
                  if (success) {
                    _qtyController.clear();
                    final isMarketable = (_side == OrderSide.buy && target >= stock.currentPrice) ||
                                         (_side == OrderSide.sell && target <= stock.currentPrice);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isMarketable
                              ? '$_orderType Order executed at market price ${formatter.format(stock.currentPrice)}!'
                              : '$_orderType Order placed @ ${formatter.format(target)}! View in Orders tab.',
                        ),
                        backgroundColor: AppColors.profit,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: (!isMarketOnline || !stock.isLive || stock.currentPrice <= 0 || !isLimitPlausible)
                    ? const Color(0xFF2B3139)
                    : (isLong ? AppColors.profit : AppColors.loss),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                (!isMarketOnline || !stock.isLive || stock.currentPrice <= 0)
                    ? 'Syncing Live Price...'
                    : (!isLimitPlausible
                        ? 'Limit Price Out of Range'
                        : (isLong ? 'Buy / Long' : 'Sell / Short')),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: (!canExecute || !isMarketOnline || !stock.isLive || stock.currentPrice <= 0) ? AppColors.subtle : Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildOrderRow(OrderBookEntry entry, Color color, AppCurrencyFormatter formatter, double maxQty, bool isAsk) {
    final fraction = maxQty > 0 ? (entry.qty / maxQty).clamp(0.04, 1.0) : 0.05;
    final qtyStr = _formatFuturesAmount(entry.qty);

    return InkWell(
      onTap: () {
        setState(() {
          _limitPriceController.text = entry.price.toStringAsFixed(2);
        });
      },
      child: Container(
        height: 24,
        margin: const EdgeInsets.only(bottom: 2),
        child: Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatter.format(entry.price),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                  Text(
                    qtyStr,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFuturesAmount(double amount) {
    if (amount >= 10000) return '${(amount / 1000).toStringAsFixed(1)}K';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(2)}K';
    if (amount >= 100) return amount.toStringAsFixed(1);
    if (amount >= 1) return amount.toStringAsFixed(2);
    return amount.toStringAsFixed(4);
  }

  Widget _buildPositionsTab(UserState userState, List<Stock> market, AppCurrencyFormatter formatter) {
    final activePositions = userState.futuresPositions.where((pos) {
      final stockIdx = market.indexWhere((s) => s.symbol == pos.symbol);
      if (stockIdx < 0) return true;
      return !pos.isLiquidated(market[stockIdx].currentPrice);
    }).toList();

    if (activePositions.isEmpty) {
      return Center(child: Text('No open positions.', style: TextStyle(color: AppColors.subtle)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activePositions.length,
      itemBuilder: (context, index) {
        final pos = activePositions[index];
        final stock = market.firstWhere((s) => s.symbol == pos.symbol, orElse: () => market.first);
        final isLong = pos.side == OrderSide.buy;
        final priceDiff = stock.currentPrice - pos.entryPrice;
        final pnl = isLong ? priceDiff * pos.quantity : -priceDiff * pos.quantity;
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
            ref.read(userProvider.notifier).closeFuturesPosition(pos, stock.currentPrice);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Position closed. P&L: ${pnl >= 0 ? '+' : ''}${formatter.format(pnl)}'),
                backgroundColor: pnl >= 0 ? AppColors.profit : AppColors.loss,
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
    );
  }

  Widget _buildOrdersTab(UserState userState, List<Stock> market, AppCurrencyFormatter formatter) {
    final pendingOrders = userState.futuresLimitOrders.where((o) => o.status == 'pending').toList();
    if (pendingOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.subtle),
              const SizedBox(height: 10),
              Text(
                'No open futures orders',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Placed limit and stop-limit orders waiting for market trigger will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.subtle, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingOrders.length,
      itemBuilder: (context, index) {
        final order = pendingOrders[index];
        final isLong = order.side == OrderSide.buy;
        final stock = market.firstWhere((s) => s.symbol == order.symbol, orElse: () => market.first);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isLong ? 'Long' : 'Short'} ${order.leverage}x',
                          style: TextStyle(
                            color: isLong ? AppColors.profit : AppColors.loss,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order.symbol}-PERP',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          order.orderType,
                          style: const TextStyle(color: AppColors.subtle, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final success = ref.read(userProvider.notifier).cancelFuturesLimitOrder(order.id);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Order cancelled. Margin refunded.'),
                            backgroundColor: AppColors.surfaceAlt,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      side: BorderSide(color: AppColors.loss.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.loss, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildOrderStat('Target Price', formatter.format(order.targetPrice)),
                  _buildOrderStat('Market Price', formatter.format(stock.currentPrice)),
                  _buildOrderStat('Qty', '${order.quantity.toStringAsFixed(4)} ${order.symbol}'),
                  _buildOrderStat('Margin', formatter.format(order.reservedMargin)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.subtle, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  void _showContractInfoSheet(BuildContext context, Stock stock, AppCurrencyFormatter formatter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CoinIcon(symbol: stock.symbol, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    '${stock.symbol}-PERP Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildContractInfoRow('Contract Type', 'Perpetual Linear USDT-M'),
              _buildContractInfoRow('Index Price', formatter.format(stock.currentPrice)),
              _buildContractInfoRow('24h High', formatter.format(stock.dayHigh)),
              _buildContractInfoRow('24h Low', formatter.format(stock.dayLow)),
              _buildContractInfoRow('Funding Rate / Countdown', '+0.0100% / 03:42:15'),
              _buildContractInfoRow('Max Leverage', '100x'),
              _buildContractInfoRow('Maintenance Margin Rate', '0.50%'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContractInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF848E9C), fontSize: 14)),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;
  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}
