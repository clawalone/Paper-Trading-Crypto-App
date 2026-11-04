import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _currentInterval = widget.initialInterval;
    _currentStyle = widget.chartStyle;
    if (isPlatformSupported) {
      _initWebView();
    }
  }

  void _initWebView() {
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
        ..setBackgroundColor(const Color(0xFF000000))
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

  void _reloadChart([String? newInterval, String? newStyle]) {
    if (newInterval != null) {
      _currentInterval = newInterval;
    }
    if (newStyle != null) {
      _currentStyle = newStyle;
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

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      background-color: #000000;
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
      "timezone": "Asia/Kolkata",
      "theme": "dark",
      "style": "$chartStyle",
      "locale": "en",
      "toolbar_bg": "#000000",
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
      "backgroundColor": "#000000",
      "gridColor": "rgba(240, 243, 246, 0.04)",
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
          isFutures: widget.isFutures,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isPlatformSupported) {
      return Container(
        color: const Color(0xFF000000),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.candlestick_chart, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            Text(
              'TradingView: ${widget.symbol}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Interactive TradingView WebView is supported on Android, iOS & macOS.\nSwitch to native chart view for other platforms.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
      color: const Color(0xFF000000),
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
                color: const Color(0xFF000000),
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
                          const Text(
                            'Loading TradingView Chart...',
                            style: TextStyle(
                              color: Colors.white70,
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
                color: const Color(0xFF000000),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 36),
                    const SizedBox(height: 10),
                    const Text(
                      'Failed to load TradingView chart',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please check your internet connection',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
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
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
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
              color: const Color(0xFF1E2329).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.white70, size: 16),
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
  final bool isFutures;

  const TradingViewFullScreenPage({
    super.key,
    required this.symbol,
    this.initialInterval = '15',
    this.isFutures = false,
  });

  @override
  State<TradingViewFullScreenPage> createState() => _TradingViewFullScreenPageState();
}

class _TradingViewFullScreenPageState extends State<TradingViewFullScreenPage> {
  late String _selectedInterval;

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
    // Allow landscape orientation in fullscreen mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Restore default portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2962FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TradingView',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.symbol,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.screen_rotation, color: Colors.white70, size: 20),
            tooltip: 'Rotate Screen',
            onPressed: () {
              final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              if (isLandscape) {
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
              } else {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close Fullscreen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Timeframe quick bar
            Container(
              height: 38,
              color: const Color(0xFF181C25),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('Interval: ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _intervals.map((item) {
                        final isSel = item.$1 == _selectedInterval;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedInterval = item.$1);
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF2962FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white60,
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
                ],
              ),
            ),
            // The chart view
            Expanded(
              child: TradingViewChart(
                key: ValueKey('${widget.symbol}_$_selectedInterval'),
                symbol: widget.symbol,
                initialInterval: _selectedInterval,
                enableDrawingToolbar: true,
                showTopToolbar: true,
                showDateRanges: true,
                showRsi: true,
                showFullscreenAction: false,
                isFullScreen: true,
                isFutures: widget.isFutures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
