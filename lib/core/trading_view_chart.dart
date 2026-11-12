import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_theme.dart';

/// Formats a raw crypto symbol (e.g. 'BTCUSDT', 'PEPEUSDT', or 'MKR - PERP') into
/// TradingView's official ticker format with accurate symbol mappings for delisted,
/// rebranded, and multiplier-based futures contracts (1000PEPE, POL, MKR, TON, etc.).
String formatTradingViewSymbol(String symbol, {bool isFutures = false}) {
  String clean = symbol.trim().toUpperCase().replaceAll('/', '').replaceAll('-', '').replaceAll(' ', '');
  if (clean.contains(':')) {
    clean = clean.split(':').last;
  }

  // Stock & Index symbols on TradingView
  const stockTvMap = {
    'AAPL': 'NASDAQ:AAPL',
    'NVDA': 'NASDAQ:NVDA',
    'TSLA': 'NASDAQ:TSLA',
    'MSFT': 'NASDAQ:MSFT',
    'AMZN': 'NASDAQ:AMZN',
    'GOOGL': 'NASDAQ:GOOGL',
    'GOOG': 'NASDAQ:GOOGL',
    'META': 'NASDAQ:META',
    'NFLX': 'NASDAQ:NFLX',
    'AMD': 'NASDAQ:AMD',
    'SPY': 'AMEX:SPY',
    'QQQ': 'NASDAQ:QQQ',
    'COIN': 'NASDAQ:COIN',
    'PLTR': 'NYSE:PLTR',

    // Expanded US Tech
    'ORCL': 'NYSE:ORCL',
    'CRM': 'NYSE:CRM',
    'ADBE': 'NASDAQ:ADBE',
    'UBER': 'NYSE:UBER',

    // Semiconductors & AI
    'AVGO': 'NASDAQ:AVGO',
    'TSM': 'NYSE:TSM',
    'QCOM': 'NASDAQ:QCOM',
    'INTC': 'NASDAQ:INTC',
    'ARM': 'NASDAQ:ARM',
    'MU': 'NASDAQ:MU',
    'SMCI': 'NASDAQ:SMCI',

    // Crypto & FinTech
    'MSTR': 'NASDAQ:MSTR',
    'HOOD': 'NASDAQ:HOOD',
    'MARA': 'NASDAQ:MARA',
    'RIOT': 'NASDAQ:RIOT',
    'CLSK': 'NASDAQ:CLSK',
    'SQ': 'NYSE:SQ',
    'PYPL': 'NASDAQ:PYPL',
    'V': 'NYSE:V',
    'MA': 'NYSE:MA',

    // Finance & Banks
    'JPM': 'NYSE:JPM',
    'BAC': 'NYSE:BAC',
    'GS': 'NYSE:GS',
    'MS': 'NYSE:MS',

    // Consumer & Retail
    'DIS': 'NYSE:DIS',
    'WMT': 'NYSE:WMT',
    'COST': 'NASDAQ:COST',
    'NKE': 'NYSE:NKE',
    'SBUX': 'NASDAQ:SBUX',
    'MCD': 'NYSE:MCD',
    'RIVN': 'NASDAQ:RIVN',
    'LCID': 'NASDAQ:LCID',
    'NIO': 'NYSE:NIO',

    // Aerospace, Industrial & Energy
    'BA': 'NYSE:BA',
    'LMT': 'NYSE:LMT',
    'GE': 'NYSE:GE',
    'CAT': 'NYSE:CAT',
    'XOM': 'NYSE:XOM',
    'CVX': 'NYSE:CVX',

    // Healthcare
    'LLY': 'NYSE:LLY',
    'NVO': 'NYSE:NVO',
    'JNJ': 'NYSE:JNJ',
    'PFE': 'NYSE:PFE',
    'UNH': 'NYSE:UNH',

    // ETFs
    'VOO': 'AMEX:VOO',
    'IWM': 'AMEX:IWM',
    'DIA': 'AMEX:DIA',
    'TQQQ': 'NASDAQ:TQQQ',
    'SQQQ': 'NASDAQ:SQQQ',
    'SOXX': 'NASDAQ:SOXX',
    'GLD': 'AMEX:GLD',
    'TLT': 'NASDAQ:TLT',

    // Indices (Use embed-permitted CFD feeds; cash indices SP:SPX, NASDAQ:IXIC, DJ:DJI are blocked on public TV widgets)
    '^GSPC': 'FOREXCOM:SPXUSD',
    'GSPC': 'FOREXCOM:SPXUSD',
    'SPX': 'FOREXCOM:SPXUSD',
    'SP500': 'FOREXCOM:SPXUSD',
    '^IXIC': 'FOREXCOM:NSXUSD',
    'IXIC': 'FOREXCOM:NSXUSD',
    'NASDAQ': 'FOREXCOM:NSXUSD',
    '^DJI': 'FOREXCOM:DJI',
    'DJI': 'FOREXCOM:DJI',
    'DOW': 'FOREXCOM:DJI',
  };

  if (stockTvMap.containsKey(clean)) {
    return stockTvMap[clean]!;
  }
  if (clean.endsWith('.NS')) {
    final bare = clean.replaceAll('.NS', '');
    return 'NSE:$bare';
  }

  final effectiveFutures = isFutures || clean.contains('PERP') || clean.endsWith('.P');
  final base = clean
      .replaceAll('PERP', '')
      .replaceAll('.P', '')
      .replaceAll('USDT', '')
      .replaceAll('USDC', '')
      .replaceAll('BUSD', '');

  if (effectiveFutures) {
    // 1,000x multiplier contracts on Binance Futures
    if (base == 'PEPE' || base == '1000PEPE') return 'BINANCE:1000PEPEUSDT.P';
    if (base == 'SHIB' || base == '1000SHIB') return 'BINANCE:1000SHIBUSDT.P';
    if (base == 'FLOKI' || base == '1000FLOKI') return 'BINANCE:1000FLOKIUSDT.P';
    if (base == 'BONK' || base == '1000BONK') return 'BINANCE:1000BONKUSDT.P';
    if (base == 'LUNC' || base == '1000LUNC') return 'BINANCE:1000LUNCUSDT.P';
    if (base == 'SATS' || base == '1000SATS') return 'BINANCE:1000SATSUSDT.P';
    if (base == 'RATS' || base == '1000RATS') return 'BINANCE:1000RATSUSDT.P';

    // Migrated / Rebranded tokens on Binance Futures
    if (base == 'MATIC' || base == 'POL') return 'BINANCE:POLUSDT.P';
    if (base == 'FTM' || base == 'SONIC' || base == 'S') return 'BINANCE:SUSDT.P';
    if (base == 'AGIX' || base == 'FET' || base == 'ASI') return 'BINANCE:FETUSDT.P';

    // Market symbols on Binance Futures
    if (base == 'MKR') return 'BINANCE:MKRUSDT.P';
    if (base == 'TON') return 'BINANCE:TONUSDT.P';

    return 'BINANCE:${base}USDT.P';
  }

  // Spot Symbols
  // Migrated / Rebranded tokens on Binance Spot
  if (base == 'MATIC' || base == 'POL') return 'BINANCE:POLUSDT';
  if (base == 'FTM' || base == 'SONIC' || base == 'S') return 'BINANCE:SUSDT';
  if (base == 'AGIX' || base == 'FET' || base == 'ASI') return 'BINANCE:FETUSDT';

  // Market symbols on Binance Spot
  if (base == 'MKR') return 'BINANCE:MKRUSDT';
  if (base == 'TON') return 'BINANCE:TONUSDT';

  // Meme tokens on Binance Spot (Spot uses standard PEPEUSDT, SHIBUSDT, FLOKIUSDT, etc.)
  if (base == '1000PEPE' || base == 'PEPE') return 'BINANCE:PEPEUSDT';
  if (base == '1000SHIB' || base == 'SHIB') return 'BINANCE:SHIBUSDT';
  if (base == '1000FLOKI' || base == 'FLOKI') return 'BINANCE:FLOKIUSDT';
  if (base == '1000BONK' || base == 'BONK') return 'BINANCE:BONKUSDT';
  if (base == '1000LUNC' || base == 'LUNC') return 'BINANCE:LUNCUSDT';
  if (base == '1000SATS' || base == 'SATS') return 'BINANCE:1000SATSUSDT';

  if (clean.endsWith('USDT') || clean.endsWith('USDC') || clean.endsWith('BUSD')) {
    return 'BINANCE:$clean';
  }
  return 'BINANCE:${clean}USDT';
}

/// Embedded Official TradingView Advanced Chart widget.
///
/// Features:
/// - Real-time cloud data feed from Binance/TradingView
/// - Full interactive candlestick and technical indicators (MA, RSI, MACD, Volume)
/// - Drawing tools & trendlines
/// - Quick timeframe switching (1m, 5m, 15m, 1h, 4h, 1D, 1W)
/// - Fullscreen modal view with landscape orientation support
class TradingViewChart extends StatefulWidget {
  final String symbol;
  final String initialInterval;
  final String chartStyle; // "1" for candles, "3" for area/line
  final bool enableDrawingToolbar;
  final bool showTopToolbar;
  final bool showDateRanges;
  final bool showRsi;
  final bool showFullscreenAction;
  final bool isFullScreen;
  final bool isFutures;
  final VoidCallback? onToggleNative;
  final double? livePrice;

  const TradingViewChart({
    super.key,
    required this.symbol,
    this.initialInterval = '15',
    this.chartStyle = '1',
    this.enableDrawingToolbar = false, // Clean CoinDCX layout by default
    this.showTopToolbar = false,
    this.showDateRanges = false,
    this.showRsi = false,
    this.showFullscreenAction = false,
    this.isFullScreen = false,
    this.isFutures = false,
    this.onToggleNative,
    this.livePrice,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  late String _currentInterval;
  late String _currentStyle;
  bool _lastIsDarkMode = AppColors.isDarkMode;
  Timer? _liveStockTimer;

  static final Map<String, ({DateTime time, List<Map<String, dynamic>> candles})> _yahooCandleCache = {};

  /// Checks whether a symbol is an Indian equity or index that is restricted from
  /// TradingView's free iframe embed script (which blocks external webviews).
  static bool isIndianStockSymbol(String symbol) {
    final clean = symbol.trim().toUpperCase().replaceAll(' ', '');
    if (clean.endsWith('.NS') || clean.endsWith('.BO') || clean == '^NSEI' || clean == 'NIFTY') {
      return true;
    }
    const indianNames = {
      'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'TATAMOTORS', 'ICICIBANK', 'ITC', 'SBIN', 'BHARTIARTL',
      'NSE:RELIANCE', 'NSE:TCS', 'NSE:HDFCBANK', 'NSE:INFY', 'NSE:TATAMOTORS', 'NSE:ICICIBANK', 'NSE:ITC', 'NSE:SBIN', 'NSE:BHARTIARTL', 'NSE:NIFTY'
    };
    return indianNames.contains(clean);
  }

  static Future<List<Map<String, dynamic>>> fetchYahooFinanceCandles(
    String symbol,
    String interval, {
    bool forceRefresh = false,
  }) async {
    String clean = symbol.trim().toUpperCase().replaceAll(' ', '');
    if (clean.contains(':')) clean = clean.split(':').last;

    String querySymbol = clean;
    if (querySymbol == 'SPX' || querySymbol == 'GSPC' || querySymbol == 'SPXUSD') {
      querySymbol = '^GSPC';
    } else if (querySymbol == 'IXIC' || querySymbol == 'NSXUSD' || querySymbol == 'NASDAQ') {
      querySymbol = '^IXIC';
    } else if (querySymbol == 'DJI' || querySymbol == 'US30') {
      querySymbol = '^DJI';
    } else if (querySymbol == 'SQ') {
      querySymbol = 'XYZ';
    }

    final cacheKey = '${querySymbol}_$interval';
    if (!forceRefresh && _yahooCandleCache.containsKey(cacheKey)) {
      final entry = _yahooCandleCache[cacheKey]!;
      if (DateTime.now().difference(entry.time).inSeconds < 15) {
        return entry.candles;
      }
    }

    String yInterval = '15m';
    String yRange = '5d';
    switch (interval) {
      case '1':
      case '5':
        yInterval = '5m';
        yRange = '1d';
        break;
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
      case 'W':
        yInterval = '1wk';
        yRange = '5y';
        break;
      default:
        yInterval = '15m';
        yRange = '5d';
    }

    try {
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$querySymbol?interval=$yInterval&range=$yRange';
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final result = json['chart']?['result']?[0];
        if (result != null) {
          final timestamps = (result['timestamp'] as List?)?.cast<int>() ?? [];
          final quote = result['indicators']?['quote']?[0];
          if (quote != null && timestamps.isNotEmpty) {
            final opens = (quote['open'] as List?) ?? [];
            final highs = (quote['high'] as List?) ?? [];
            final lows = (quote['low'] as List?) ?? [];
            final closes = (quote['close'] as List?) ?? [];
            final volumes = (quote['volume'] as List?) ?? [];
            final count = timestamps.length;
            final candles = <Map<String, dynamic>>[];
            for (int i = 0; i < count; i++) {
              if (i >= closes.length) break;
              final c = (closes[i] as num?)?.toDouble();
              if (c == null || c.isNaN) continue;
              final o = (opens.length > i && opens[i] != null) ? (opens[i] as num).toDouble() : c;
              final h = (highs.length > i && highs[i] != null) ? (highs[i] as num).toDouble() : (o > c ? o : c);
              final l = (lows.length > i && lows[i] != null) ? (lows[i] as num).toDouble() : (o < c ? o : c);
              final v = (volumes.length > i && volumes[i] != null) ? (volumes[i] as num).toDouble() : 0.0;
              candles.add({
                'time': timestamps[i],
                'open': o,
                'high': h,
                'low': l,
                'close': c,
                'volume': v,
              });
            }
            if (candles.isNotEmpty) {
              _yahooCandleCache[cacheKey] = (time: DateTime.now(), candles: candles);
              return candles;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Yahoo Finance chart fetch error: $e');
    }

    return _generateFallbackCandles(querySymbol);
  }

  static List<Map<String, dynamic>> _generateFallbackCandles(String symbol) {
    double basePrice = 1000.0;
    if (symbol.contains('RELIANCE')) basePrice = 1324.0;
    if (symbol.contains('TCS')) basePrice = 2475.0;
    if (symbol.contains('HDFC')) basePrice = 798.0;
    if (symbol.contains('INFY')) basePrice = 1154.0;
    if (symbol.contains('ICICI')) basePrice = 1589.0;
    if (symbol.contains('ITC')) basePrice = 278.0;
    if (symbol.contains('SBIN')) basePrice = 1042.0;
    if (symbol.contains('BHARTI')) basePrice = 2072.0;
    if (symbol.contains('NSEI') || symbol.contains('NIFTY')) basePrice = 25044.0;
    if (symbol.contains('TMCV') || symbol.contains('TATAMOTORS')) basePrice = 436.0;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final candles = <Map<String, dynamic>>[];
    double price = basePrice;
    for (int i = 60; i >= 0; i--) {
      final t = now - (i * 900);
      final change = (i % 3 == 0 ? 1 : -1) * (basePrice * 0.003 * ((i % 5) + 1));
      final open = price;
      final close = price + change;
      final high = (open > close ? open : close) + (basePrice * 0.002);
      final low = (open < close ? open : close) - (basePrice * 0.002);
      candles.add({
        'time': t,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': 50000.0 + (i * 1000),
      });
      price = close;
    }
    return candles;
  }

  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _currentInterval = widget.initialInterval;
    _currentStyle = widget.chartStyle;
    _lastIsDarkMode = AppColors.isDarkMode;
    if (isPlatformSupported) {
      _initWebView();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_lastIsDarkMode != isDark) {
      _lastIsDarkMode = isDark;
      AppColors.isDarkMode = isDark;
      _controller?.setBackgroundColor(AppColors.background);
      _reloadChart();
    }
  }

  void _initWebView() {
    if (isIndianStockSymbol(widget.symbol)) {
      _initIndianStockChart();
      return;
    }
    try {
      final tvSymbol = formatTradingViewSymbol(widget.symbol, isFutures: widget.isFutures);
      final html = _generateTradingViewHtml(
        tvSymbol: tvSymbol,
        interval: _currentInterval,
        chartStyle: _currentStyle,
        showDrawingToolbar: widget.enableDrawingToolbar,
        showTopToolbar: widget.showTopToolbar,
        showDateRanges: widget.showDateRanges,
        showRsi: widget.showRsi,
        isFullScreen: widget.isFullScreen,
      );

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.background)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame ?? true) {
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        )
        ..loadHtmlString(html, baseUrl: 'https://www.tradingview.com');
    } catch (e) {
      debugPrint('Error initializing TradingView WebView: $e');
      _hasError = true;
      _isLoading = false;
    }
  }

  Future<void> _initIndianStockChart() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.background)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame ?? true) {
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        );

      final candles = await fetchYahooFinanceCandles(widget.symbol, _currentInterval);
      final html = _generateLightweightChartHtml(
        symbol: widget.symbol,
        candles: candles,
        chartStyle: _currentStyle,
        isFullScreen: widget.isFullScreen,
      );

      await _controller?.loadHtmlString(html, baseUrl: 'https://www.tradingview.com');
      _startLiveStockPolling();
    } catch (e) {
      debugPrint('Error initializing Indian stock chart: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _startLiveStockPolling() {
    _liveStockTimer?.cancel();
    if (!isIndianStockSymbol(widget.symbol)) return;

    _liveStockTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;

      // 1. If widget has a live price, push it directly to update active candle
      if (widget.livePrice != null && widget.livePrice! > 0) {
        _pushLivePriceTick(widget.livePrice!);
      }

      // 2. Poll fresh Yahoo Finance data every 12 seconds
      if (DateTime.now().second % 12 < 4) {
        final candles = await fetchYahooFinanceCandles(widget.symbol, _currentInterval, forceRefresh: true);
        if (!mounted || candles.isEmpty) return;
        final last = candles.last;
        final time = last['time'];
        final o = last['open'];
        final h = last['high'];
        final l = last['low'];
        final c = last['close'];
        final v = last['volume'];
        _controller?.runJavaScript(
          'if (window.updateCandleData) { window.updateCandleData($time, $o, $h, $l, $c, $v); }',
        );
      }
    });
  }

  void _pushLivePriceTick(double price) {
    if (!isIndianStockSymbol(widget.symbol)) return;
    _controller?.runJavaScript(
      'if (window.updatePriceTick) { window.updatePriceTick($price); }',
    );
  }

  @override
  void dispose() {
    _liveStockTimer?.cancel();
    super.dispose();
  }

  void _reloadChart([String? newInterval, String? newStyle]) {
    if (newInterval != null) {
      _currentInterval = newInterval;
    }
    if (newStyle != null) {
      _currentStyle = newStyle;
    }
    if (isIndianStockSymbol(widget.symbol)) {
      _reloadIndianStockChart();
      return;
    }
    final tvSymbol = formatTradingViewSymbol(widget.symbol, isFutures: widget.isFutures);
    final html = _generateTradingViewHtml(
      tvSymbol: tvSymbol,
      interval: _currentInterval,
      chartStyle: _currentStyle,
      showDrawingToolbar: widget.enableDrawingToolbar,
      showTopToolbar: widget.showTopToolbar,
      showDateRanges: widget.showDateRanges,
      showRsi: widget.showRsi,
      isFullScreen: widget.isFullScreen,
    );
    _controller?.loadHtmlString(html, baseUrl: 'https://www.tradingview.com');
  }

  Future<void> _reloadIndianStockChart() async {
    if (mounted) setState(() => _isLoading = true);
    final candles = await fetchYahooFinanceCandles(widget.symbol, _currentInterval, forceRefresh: true);
    final html = _generateLightweightChartHtml(
      symbol: widget.symbol,
      candles: candles,
      chartStyle: _currentStyle,
      isFullScreen: widget.isFullScreen,
    );
    await _controller?.loadHtmlString(html, baseUrl: 'https://www.tradingview.com');
    if (mounted) setState(() => _isLoading = false);
    _startLiveStockPolling();
  }

  static String _generateLightweightChartHtml({
    required String symbol,
    required List<Map<String, dynamic>> candles,
    String chartStyle = '1',
    bool isFullScreen = false,
  }) {
    final isDark = AppColors.isDarkMode;
    final bgColor = isDark ? '#000000' : '#FFFFFF';
    final textColor = isDark ? '#848E9C' : '#474D57';
    final gridColor = isDark ? 'rgba(255, 255, 255, 0.04)' : 'rgba(0, 0, 0, 0.04)';
    final borderColor = isDark ? '#2B313A' : '#E6E8EA';
    final candleJson = jsonEncode(candles);
    final isLine = chartStyle == '3';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    html, body {
      width: 100%; height: 100%;
      background: $bgColor;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      user-select: none;
      -webkit-user-select: none;
    }
    #chart_container {
      width: 100%; height: 100%;
      position: absolute; top: 0; left: 0;
    }
    #legend_bar {
      position: absolute;
      top: 8px;
      left: 12px;
      z-index: 10;
      color: $textColor;
      font-size: 11px;
      font-weight: 500;
      pointer-events: none;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 6px;
    }
    .badge {
      background: ${isDark ? '#1E2329' : '#F0F2F5'};
      color: ${isDark ? '#EAECEF' : '#1E2329'};
      padding: 2px 6px;
      border-radius: 4px;
      font-weight: 700;
      font-size: 10px;
      margin-right: 2px;
    }
    .val { color: ${isDark ? '#EAECEF' : '#1E2329'}; font-weight: 600; }
    .up { color: #0ECB81 !important; }
    .down { color: #F6465D !important; }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/lightweight-charts@4.2.0/dist/lightweight-charts.standalone.production.js"></script>
  <script>
    if (typeof LightweightCharts === 'undefined') {
      document.write('<script src="https://unpkg.com/lightweight-charts@4.2.0/dist/lightweight-charts.standalone.production.js"><\\/script>');
    }
  </script>
</head>
<body>
  <div id="legend_bar">
    <span class="badge">$symbol</span>
    <span>O <span id="leg_o" class="val">-</span></span>
    <span>H <span id="leg_h" class="val">-</span></span>
    <span>L <span id="leg_l" class="val">-</span></span>
    <span>C <span id="leg_c" class="val">-</span></span>
  </div>
  <div id="chart_container"></div>
  <script>
    const isDark = $isDark;
    const isLine = $isLine;
    const container = document.getElementById('chart_container');
    const chart = LightweightCharts.createChart(container, {
      width: container.clientWidth || window.innerWidth,
      height: container.clientHeight || window.innerHeight,
      layout: {
        background: { color: '$bgColor' },
        textColor: '$textColor',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      },
      grid: {
        vertLines: { color: '$gridColor' },
        horzLines: { color: '$gridColor' },
      },
      crosshair: {
        mode: LightweightCharts.CrosshairMode.Normal,
        vertLine: {
          color: isDark ? 'rgba(255, 255, 255, 0.25)' : 'rgba(0, 0, 0, 0.25)',
          width: 1,
          style: LightweightCharts.LineStyle.Dashed,
          labelBackgroundColor: isDark ? '#2B313A' : '#E6E8EA',
        },
        horzLine: {
          color: isDark ? 'rgba(255, 255, 255, 0.25)' : 'rgba(0, 0, 0, 0.25)',
          width: 1,
          style: LightweightCharts.LineStyle.Dashed,
          labelBackgroundColor: isDark ? '#2B313A' : '#E6E8EA',
        },
      },
      rightPriceScale: {
        borderColor: '$borderColor',
        scaleMargins: { top: 0.1, bottom: 0.2 },
      },
      timeScale: {
        borderColor: '$borderColor',
        timeVisible: true,
        secondsVisible: false,
        barSpacing: 12,
        minBarSpacing: 3,
        rightOffset: 6,
      },
      handleScroll: {
        mouseWheel: true,
        pressedMouseMove: true,
        horzTouchDrag: true,
        vertTouchDrag: false,
      },
      handleScale: {
        axisPressedMouseMove: true,
        mouseWheel: true,
        pinch: true,
      },
    });

    const resizeObserver = new ResizeObserver(entries => {
      if (!entries || entries.length === 0) return;
      const { width, height } = entries[0].contentRect;
      if (width > 0 && height > 0) {
        chart.applyOptions({ width, height });
      }
    });
    resizeObserver.observe(container);

    let mainSeries;
    if (isLine) {
      mainSeries = chart.addAreaSeries({
        topColor: 'rgba(14, 203, 129, 0.28)',
        bottomColor: 'rgba(14, 203, 129, 0.00)',
        lineColor: '#0ECB81',
        lineWidth: 2,
        priceFormat: { type: 'price', precision: 2, minMove: 0.05 },
      });
    } else {
      mainSeries = chart.addCandlestickSeries({
        upColor: '#0ECB81',
        downColor: '#F6465D',
        borderUpColor: '#0ECB81',
        borderDownColor: '#F6465D',
        wickUpColor: '#0ECB81',
        wickDownColor: '#F6465D',
        priceFormat: { type: 'price', precision: 2, minMove: 0.05 },
      });
    }

    const volumeSeries = chart.addHistogramSeries({
      priceFormat: { type: 'volume' },
      priceScaleId: 'volume',
    });
    chart.priceScale('volume').applyOptions({
      scaleMargins: { top: 0.82, bottom: 0 },
      visible: false,
    });

    const rawData = $candleJson;
    const seriesData = [];
    const volData = [];

    for (let i = 0; i < rawData.length; i++) {
      const d = rawData[i];
      if (isLine) {
        seriesData.push({ time: d.time, value: d.close });
      } else {
        seriesData.push({ time: d.time, open: d.open, high: d.high, low: d.low, close: d.close });
      }
      volData.push({
        time: d.time,
        value: d.volume,
        color: d.close >= d.open ? 'rgba(14, 203, 129, 0.35)' : 'rgba(246, 70, 93, 0.35)',
      });
    }

    if (seriesData.length > 0) {
      mainSeries.setData(seriesData);
      volumeSeries.setData(volData);
      
      // Perfectly zoom into the most recent ~35 candles (or ~60 in fullscreen) on initial load
      const visibleBars = ${isFullScreen ? 60 : 35};
      const fromIdx = Math.max(0, seriesData.length - visibleBars);
      chart.timeScale().setVisibleLogicalRange({
        from: fromIdx,
        to: seriesData.length + 5,
      });
      
      const last = rawData[rawData.length - 1];
      updateLegend(last);
    }

    chart.subscribeCrosshairMove((param) => {
      if (!param || !param.time || !param.seriesData) {
        if (rawData.length > 0) updateLegend(rawData[rawData.length - 1]);
        return;
      }
      const data = param.seriesData.get(mainSeries);
      if (data) {
        updateLegend(data);
      }
    });

    function updateLegend(d) {
      if (!d) return;
      document.getElementById('leg_o').innerText = d.open !== undefined ? d.open.toFixed(2) : '-';
      document.getElementById('leg_h').innerText = d.high !== undefined ? d.high.toFixed(2) : '-';
      document.getElementById('leg_l').innerText = d.low !== undefined ? d.low.toFixed(2) : '-';
      const cEl = document.getElementById('leg_c');
      const closeVal = d.close !== undefined ? d.close : (d.value !== undefined ? d.value : null);
      if (closeVal !== null) {
        cEl.innerText = closeVal.toFixed(2);
        cEl.className = 'val ' + (d.open && closeVal >= d.open ? 'up' : 'down');
      }
    }

    window.updatePriceTick = function(price, timeSec) {
      if (!mainSeries || !rawData || rawData.length === 0) return;
      const last = rawData[rawData.length - 1];
      const t = timeSec || last.time;
      if (isLine) {
        last.close = price;
        mainSeries.update({ time: t, value: price });
      } else {
        const newHigh = Math.max(last.high, price);
        const newLow = Math.min(last.low, price);
        last.high = newHigh;
        last.low = newLow;
        last.close = price;
        mainSeries.update({
          time: t,
          open: last.open,
          high: newHigh,
          low: newLow,
          close: price,
        });
      }
      updateLegend(last);
    };

    window.updateCandleData = function(timeSec, open, high, low, close, volume) {
      if (!mainSeries || !rawData || rawData.length === 0) return;
      const last = rawData[rawData.length - 1];
      if (last.time === timeSec) {
        last.open = open;
        last.high = high;
        last.low = low;
        last.close = close;
        last.volume = volume;
        if (isLine) {
          mainSeries.update({ time: timeSec, value: close });
        } else {
          mainSeries.update({ time: timeSec, open: open, high: high, low: low, close: close });
        }
        if (volumeSeries) {
          volumeSeries.update({
            time: timeSec,
            value: volume,
            color: close >= open ? 'rgba(14, 203, 129, 0.35)' : 'rgba(246, 70, 93, 0.35)',
          });
        }
        updateLegend(last);
      } else if (timeSec > last.time) {
        const newBar = { time: timeSec, open: open, high: high, low: low, close: close, volume: volume };
        rawData.push(newBar);
        if (isLine) {
          mainSeries.update({ time: timeSec, value: close });
        } else {
          mainSeries.update({ time: timeSec, open: open, high: high, low: low, close: close });
        }
        if (volumeSeries) {
          volumeSeries.update({
            time: timeSec,
            value: volume,
            color: close >= open ? 'rgba(14, 203, 129, 0.35)' : 'rgba(246, 70, 93, 0.35)',
          });
        }
        updateLegend(newBar);
      }
    };
  </script>
</body>
</html>
''';
  }

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.livePrice != null &&
        widget.livePrice != oldWidget.livePrice &&
        widget.livePrice! > 0) {
      _pushLivePriceTick(widget.livePrice!);
    }
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.initialInterval != widget.initialInterval ||
        oldWidget.chartStyle != widget.chartStyle ||
        oldWidget.enableDrawingToolbar != widget.enableDrawingToolbar ||
        oldWidget.showTopToolbar != widget.showTopToolbar ||
        oldWidget.showDateRanges != widget.showDateRanges ||
        oldWidget.showRsi != widget.showRsi ||
        oldWidget.isFullScreen != widget.isFullScreen ||
        oldWidget.isFutures != widget.isFutures) {
      _currentInterval = widget.initialInterval;
      _currentStyle = widget.chartStyle;
      _reloadChart();
    }
  }

  static String _generateTradingViewHtml({
    required String tvSymbol,
    required String interval,
    String chartStyle = '1',
    bool showDrawingToolbar = false,
    bool showTopToolbar = false,
    bool showDateRanges = false,
    bool showRsi = false,
    bool isFullScreen = false,
    String? range,
  }) {
    final studiesList = [
      '"MASimple@tv-basicstudies"',
      if (showRsi) '"RSI@tv-basicstudies"',
    ].join(',');

    final disabledFeatures = [
      '"header_symbol_search"',
    ].join(',');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden !important;
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      overscroll-behavior: none !important;
      touch-action: auto;
      background-color: ${AppColors.isDarkMode ? '#000000' : '#FFFFFF'};
      -webkit-user-select: none;
      user-select: none;
    }
    .tradingview-widget-container, #tv_chart_container, iframe {
      width: 100% !important;
      height: 100% !important;
      position: absolute !important;
      top: 0 !important;
      left: 0 !important;
      right: 0 !important;
      bottom: 0 !important;
      overflow: hidden !important;
      border: none !important;
    }
  </style>
</head>
<body>
  <div class="tradingview-widget-container">
    <div id="tv_chart_container"></div>
  </div>
  <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
  <script type="text/javascript">
    new TradingView.widget({
      "autosize": true,
      "symbol": "$tvSymbol",
      "interval": "$interval",
      ${range != null ? '"range": "$range",' : ''}
      "timezone": "exchange",
      "theme": "${AppColors.isDarkMode ? 'dark' : 'light'}",
      "style": "$chartStyle",
      "locale": "en",
      "toolbar_bg": "${AppColors.isDarkMode ? '#000000' : '#FFFFFF'}",
      "enable_publishing": false,
      "allow_symbol_change": $showTopToolbar,
      "container_id": "tv_chart_container",
      "hide_side_toolbar": ${!showDrawingToolbar},
      "hide_top_toolbar": ${!showTopToolbar},
      "hide_legend": false,
      "hide_volume": false,
      "withdateranges": $showDateRanges,
      "save_image": false,
      "details": false,
      "hotlist": false,
      "calendar": false,
      "backgroundColor": "${AppColors.isDarkMode ? '#000000' : '#FFFFFF'}",
      "gridColor": "${AppColors.isDarkMode ? 'rgba(240, 243, 246, 0.04)' : 'rgba(0, 0, 0, 0.06)'}",
      "disabled_features": [
        $disabledFeatures
      ],
      "studies": [
        $studiesList
      ]
    });
  </script>
</body>
</html>
''';
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => TradingViewFullScreenPage(
          symbol: widget.symbol,
          initialInterval: _currentInterval,
          initialChartStyle: _currentStyle,
          isFutures: widget.isFutures,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isPlatformSupported) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.candlestick_chart, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            Text(
              'TradingView: ${widget.symbol}',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Interactive TradingView WebView is supported on Android, iOS & macOS.\nSwitch to native chart view for other platforms.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtle, fontSize: 12),
            ),
            if (widget.onToggleNative != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onToggleNative,
                icon: const Icon(Icons.show_chart, size: 16),
                label: const Text('Switch to Native Chart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // The WebView
          if (_controller != null)
            Positioned.fill(
              child: WebViewWidget(
                controller: _controller!,
                gestureRecognizers: widget.isFullScreen
                    ? {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      }
                    : {
                        Factory<OneSequenceGestureRecognizer>(
                          () => HorizontalDragGestureRecognizer(),
                        ),
                      },
              ),
            ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: AppColors.background,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2962FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TV',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loading TradingView Chart...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Error overlay
          if (_hasError)
            Positioned.fill(
              child: Container(
                color: AppColors.background,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: AppColors.subtle, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      'Failed to load TradingView chart',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please check your internet connection',
                      style: TextStyle(color: AppColors.subtle, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _reloadChart(),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.outline),
                          ),
                        ),
                        if (widget.onToggleNative != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: widget.onToggleNative,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text('Use Native Chart'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Top action buttons overlay (Fullscreen & Refresh)
          if (widget.showFullscreenAction && !_isLoading && !_hasError)
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChartOverlayIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Reload Chart',
                    onPressed: () => _reloadChart(),
                  ),
                  const SizedBox(width: 6),
                  _ChartOverlayIconButton(
                    icon: Icons.fullscreen,
                    tooltip: 'Fullscreen View',
                    onPressed: _openFullscreen,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartOverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ChartOverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.outline),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 16),
          ),
        ),
      ),
    );
  }
}

/// Fullscreen TradingView Chart Page for immersive technical analysis.
class TradingViewFullScreenPage extends StatefulWidget {
  final String symbol;
  final String initialInterval;
  final String initialChartStyle;
  final bool isFutures;
  final double? livePrice;

  const TradingViewFullScreenPage({
    super.key,
    required this.symbol,
    this.initialInterval = '15',
    this.initialChartStyle = '1',
    this.isFutures = false,
    this.livePrice,
  });

  @override
  State<TradingViewFullScreenPage> createState() => _TradingViewFullScreenPageState();
}

class _TradingViewFullScreenPageState extends State<TradingViewFullScreenPage> {
  late String _selectedInterval;
  late String _chartStyle;
  bool _showRsi = false;
  bool _showDrawingTools = false;

  static const _intervals = [
    ('1', '1m'),
    ('5', '5m'),
    ('15', '15m'),
    ('60', '1h'),
    ('240', '4h'),
    ('D', '1D'),
    ('W', '1W'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedInterval = widget.initialInterval;
    _chartStyle = widget.initialChartStyle;
    // Allow landscape and portrait orientations so user can rotate or tilt device
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Restore default portrait orientation and edge-to-edge system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleOrientation(bool isCurrentlyLandscape) {
    if (isCurrentlyLandscape) {
      // Rotate back to Portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      // Rotate to Landscape
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        // In landscape, omit Scaffold AppBar to maximize chart vertical real estate!
        appBar: isLandscape ? null : _buildPortraitAppBar(context),
        body: SafeArea(
          top: !isLandscape,
          bottom: !isLandscape,
          left: isLandscape,
          right: isLandscape,
          child: isLandscape
              ? _buildLandscapeLayout(context)
              : _buildPortraitLayout(context),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPortraitAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2962FF),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'TV',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.symbol,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.isFutures) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'PERP',
                style: TextStyle(color: AppColors.warning, fontSize: 8.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.screen_rotation_rounded, color: AppColors.primary, size: 20),
          tooltip: 'Rotate to Landscape',
          onPressed: () => _toggleOrientation(false),
        ),
        IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary, size: 20),
          tooltip: 'Close Fullscreen',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        // Timeframe quick bar with intervals + tool shortcuts
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.outline)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _intervals.map((item) {
                    final isSel = item.$1 == _selectedInterval;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                      child: InkWell(
                        onTap: () => setState(() => _selectedInterval = item.$1),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF2962FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.$2,
                            style: TextStyle(
                              color: isSel ? Colors.white : AppColors.subtle,
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: AppColors.outline,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
              // Chart style toggle (Candles / Line)
              Tooltip(
                message: _chartStyle == '1' ? 'Switch to Line' : 'Switch to Candles',
                child: InkWell(
                  onTap: () => setState(() => _chartStyle = _chartStyle == '1' ? '3' : '1'),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Icon(
                      _chartStyle == '1' ? Icons.candlestick_chart_rounded : Icons.show_chart_rounded,
                      color: AppColors.subtle,
                      size: 19,
                    ),
                  ),
                ),
              ),
              // Drawing tools toggle
              Tooltip(
                message: _showDrawingTools ? 'Hide Drawing Tools' : 'Show Drawing Tools',
                child: InkWell(
                  onTap: () => setState(() => _showDrawingTools = !_showDrawingTools),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Icon(
                      Icons.draw_outlined,
                      color: _showDrawingTools ? AppColors.primary : AppColors.subtle,
                      size: 19,
                    ),
                  ),
                ),
              ),
              // RSI toggle
              Tooltip(
                message: _showRsi ? 'Hide RSI' : 'Show RSI Indicator',
                child: InkWell(
                  onTap: () => setState(() => _showRsi = !_showRsi),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _showRsi ? const Color(0xFF9C27B0).withValues(alpha: 0.3) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _showRsi ? const Color(0xFFBA68C8) : AppColors.outline,
                      ),
                    ),
                    child: Text(
                      'RSI',
                      style: TextStyle(
                        color: _showRsi ? const Color(0xFFBA68C8) : AppColors.subtle,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The chart view
        Expanded(
          child: TradingViewChart(
            key: ValueKey('${widget.symbol}_${_selectedInterval}_${_chartStyle}_${_showRsi}_${_showDrawingTools}_portrait'),
            symbol: widget.symbol,
            initialInterval: _selectedInterval,
            chartStyle: _chartStyle,
            enableDrawingToolbar: _showDrawingTools,
            showTopToolbar: false,
            showDateRanges: false,
            showRsi: _showRsi,
            showFullscreenAction: false,
            isFullScreen: true,
            isFutures: widget.isFutures,
            livePrice: widget.livePrice,
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Column(
      children: [
        _buildLandscapeHeader(context),
        Expanded(
          child: TradingViewChart(
            key: ValueKey('${widget.symbol}_${_selectedInterval}_${_chartStyle}_${_showRsi}_${_showDrawingTools}_landscape'),
            symbol: widget.symbol,
            initialInterval: _selectedInterval,
            chartStyle: _chartStyle,
            enableDrawingToolbar: _showDrawingTools,
            showTopToolbar: false, // Clean: no duplicate 40px TV header
            showDateRanges: false, // Clean: no duplicate 32px bottom widget
            showRsi: _showRsi,     // Clean: full height for candlesticks unless toggled
            showFullscreenAction: false,
            isFullScreen: true,
            isFutures: widget.isFutures,
            livePrice: widget.livePrice,
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHeader(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2962FF),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'TV',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.symbol,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          if (widget.isFutures) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'PERP',
                style: TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          Container(
            width: 1,
            height: 16,
            color: AppColors.outline,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          // Timeframe selector (inline in header to save 38px!)
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _intervals.map((item) {
                final isSel = item.$1 == _selectedInterval;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedInterval = item.$1),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF2962FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          color: isSel ? Colors.white : AppColors.subtle,
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Chart style toggle (Candles / Line)
          Tooltip(
            message: _chartStyle == '1' ? 'Switch to Line' : 'Switch to Candles',
            child: InkWell(
              onTap: () => setState(() => _chartStyle = _chartStyle == '1' ? '3' : '1'),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(
                  _chartStyle == '1' ? Icons.candlestick_chart_rounded : Icons.show_chart_rounded,
                  color: AppColors.subtle,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // RSI Toggle chip
          Tooltip(
            message: _showRsi ? 'Hide RSI' : 'Show RSI Indicator',
            child: InkWell(
              onTap: () => setState(() => _showRsi = !_showRsi),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _showRsi ? const Color(0xFF9C27B0).withValues(alpha: 0.3) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _showRsi ? const Color(0xFFBA68C8) : AppColors.outline,
                  ),
                ),
                child: Text(
                  'RSI',
                  style: TextStyle(
                    color: _showRsi ? const Color(0xFFBA68C8) : AppColors.subtle,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Drawing Tools Toggle
          Tooltip(
            message: _showDrawingTools ? 'Hide Drawing Tools' : 'Show Drawing Tools',
            child: InkWell(
              onTap: () => setState(() => _showDrawingTools = !_showDrawingTools),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _showDrawingTools ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.draw_outlined,
                  color: _showDrawingTools ? AppColors.primary : AppColors.subtle,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Screen Rotate (back to portrait)
          Tooltip(
            message: 'Rotate to Portrait',
            child: InkWell(
              onTap: () => _toggleOrientation(true),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.screen_rotation_rounded, color: AppColors.primary, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Close
          Tooltip(
            message: 'Exit Fullscreen',
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
