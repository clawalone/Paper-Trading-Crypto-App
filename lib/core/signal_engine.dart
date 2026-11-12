import 'dart:math';
import 'package:stock_arena/core/app_material.dart';
import '../data/models.dart';

enum SignalAction {
  strongBuy,
  buy,
  neutral,
  sell,
  strongSell,
}

enum FuturesBias {
  long,
  short,
  neutral,
}

class SignalReason {
  final String title;
  final String description;
  final bool isBullish;
  final IconData icon;

  const SignalReason({
    required this.title,
    required this.description,
    required this.isBullish,
    required this.icon,
  });
}

class SpotAdvice {
  final SignalAction action;
  final String title;
  final String summary;
  final double entryZoneLow;
  final double entryZoneHigh;
  final double targetPrice;
  final double targetGainPct;
  final double stopLossPrice;
  final double stopLossPct;
  final List<SignalReason> keyDrivers;
  final double confidenceScore; // 0..100%

  const SpotAdvice({
    required this.action,
    required this.title,
    required this.summary,
    required this.entryZoneLow,
    required this.entryZoneHigh,
    required this.targetPrice,
    required this.targetGainPct,
    required this.stopLossPrice,
    required this.stopLossPct,
    required this.keyDrivers,
    required this.confidenceScore,
  });
}

class FuturesAdvice {
  final FuturesBias bias;
  final int recommendedLeverage;
  final String leverageRationale;
  final double entryPrice;
  final double targetPrice1;
  final double targetPrice2;
  final double stopLossPrice;
  final double riskRewardRatio;
  final double estimatedLiquidationPrice;
  final double liquidationDistancePct;
  final String riskLevel; // 'Low', 'Moderate', 'High'
  final List<SignalReason> keyDrivers;
  final double confidenceScore;

  const FuturesAdvice({
    required this.bias,
    required this.recommendedLeverage,
    required this.leverageRationale,
    required this.entryPrice,
    required this.targetPrice1,
    required this.targetPrice2,
    required this.stopLossPrice,
    required this.riskRewardRatio,
    required this.estimatedLiquidationPrice,
    required this.liquidationDistancePct,
    required this.riskLevel,
    required this.keyDrivers,
    required this.confidenceScore,
  });
}

class TechnicalAnalysisResult {
  final double currentPrice;
  final double rsi;
  final double macdLine;
  final double macdSignal;
  final double macdHist;
  final double ema20;
  final double ema50;
  final double atrPct;
  final double support;
  final double resistance;
  final SpotAdvice spotAdvice;
  final FuturesAdvice futuresAdvice;
  final int compositeScore; // -100 (Strong Bearish) to +100 (Strong Bullish)

  const TechnicalAnalysisResult({
    required this.currentPrice,
    required this.rsi,
    required this.macdLine,
    required this.macdSignal,
    required this.macdHist,
    required this.ema20,
    required this.ema50,
    required this.atrPct,
    required this.support,
    required this.resistance,
    required this.spotAdvice,
    required this.futuresAdvice,
    required this.compositeScore,
  });
}

class TimeframeSignal {
  final String label; // '15m', '1H', '4H', '1D'
  final String trend; // 'Bullish', 'Bearish', 'Neutral'
  final double confidence; // e.g. 85.0
  final Color color;
  const TimeframeSignal({
    required this.label,
    required this.trend,
    required this.confidence,
    required this.color,
  });
}

class MarketSignalItem {
  final Stock stock;
  final TechnicalAnalysisResult analysis;
  const MarketSignalItem({
    required this.stock,
    required this.analysis,
  });
}

class SignalTrackRecordItem {
  final String symbol;
  final String type; // e.g. 'Delivery Breakout', '5x Margin Long', '10x Futures Short'
  final double entryPrice;
  final double exitPrice;
  final double returnPct;
  final bool isWin;
  final String targetHit; // 'Target 1 Hit 🎯', 'Target 2 Hit 🎯', 'Stop Loss Hit 🛑'
  final DateTime entryDate;
  final DateTime date; // Exit timestamp
  final bool isLong;
  final int leverage;
  final bool isStock;
  final String currency;

  const SignalTrackRecordItem({
    required this.symbol,
    required this.type,
    required this.entryPrice,
    required this.exitPrice,
    required this.returnPct,
    required this.isWin,
    required this.targetHit,
    required this.entryDate,
    required this.date,
    required this.isLong,
    required this.leverage,
    required this.isStock,
    this.currency = 'USD',
  });
}

class SignalTrackRecordReport {
  final List<SignalTrackRecordItem> records;
  final int totalTrades;
  final int winCount;
  final int lossCount;
  final double winRatePct;
  final double avgWinPct;
  final double avgLossPct;
  final double profitRatio;
  final int assetsAudited;
  final bool isLiveAudit;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const SignalTrackRecordReport({
    required this.records,
    required this.totalTrades,
    required this.winCount,
    required this.lossCount,
    required this.winRatePct,
    required this.avgWinPct,
    required this.avgLossPct,
    required this.profitRatio,
    required this.assetsAudited,
    required this.isLiveAudit,
    this.periodStart,
    this.periodEnd,
  });
}

class SignalEngine {
  /// Analyzes a stock using its candlestick history and 24h metrics
  static TechnicalAnalysisResult analyze(Stock stock, {List<StockCandle>? customCandles}) {
    final candles = (customCandles != null && customCandles.length >= 10)
        ? customCandles
        : stock.candleHistory;

    final currentPrice = stock.currentPrice > 0
        ? stock.currentPrice
        : (candles.isNotEmpty ? candles.last.close : 100.0);

    // If insufficient candles, build fallback estimate from 24h change & day high/low
    if (candles.length < 10) {
      return _generateFallbackAnalysis(stock, currentPrice);
    }

    final closes = candles.map((c) => c.close).toList();

    // 1. Calculate RSI(14)
    final rsi = _calculateRSI(closes, 14);

    // 2. Calculate EMA 20 & EMA 50
    final ema20 = _calculateEMA(closes, 20);
    final ema50 = _calculateEMA(closes, min(50, closes.length));

    // 3. Calculate MACD(12, 26, 9)
    final macd = _calculateMACD(closes);

    // 4. Calculate ATR % (volatility)
    final atrPct = _calculateAtrPct(candles, currentPrice);

    // 5. Support & Resistance (Swing lows & highs over lookback)
    final lookback = min(24, candles.length);
    final windowCandles = candles.sublist(candles.length - lookback);
    double support = windowCandles.map((c) => c.low).reduce(min);
    double resistance = windowCandles.map((c) => c.high).reduce(max);

    // Safeguard range
    if (support >= currentPrice) support = currentPrice * 0.96;
    if (resistance <= currentPrice) resistance = currentPrice * 1.04;

    // 6. Calculate Composite Score (-100 to +100)
    int score = 0;
    final reasons = <SignalReason>[];

    // RSI factor
    if (rsi < 30) {
      score += 35;
      reasons.add(SignalReason(
        title: 'RSI Oversold (${rsi.toStringAsFixed(1)})',
        description: 'Selling pressure exhausted. High probability of technical relief rally.',
        isBullish: true,
        icon: Icons.trending_up_rounded,
      ));
    } else if (rsi < 45) {
      score += 15;
      reasons.add(SignalReason(
        title: 'RSI Bullish Room (${rsi.toStringAsFixed(1)})',
        description: 'Asset is cool and has significant upside room before becoming overbought.',
        isBullish: true,
        icon: Icons.speed_rounded,
      ));
    } else if (rsi > 70) {
      score -= 35;
      reasons.add(SignalReason(
        title: 'RSI Overbought (${rsi.toStringAsFixed(1)})',
        description: 'Extreme buyer exhaustion. Pullback or consolidation is imminent.',
        isBullish: false,
        icon: Icons.trending_down_rounded,
      ));
    } else if (rsi > 58) {
      score -= 10;
      reasons.add(SignalReason(
        title: 'RSI High Caution (${rsi.toStringAsFixed(1)})',
        description: 'Approaching elevated momentum zones. Watch out for sudden profit taking.',
        isBullish: false,
        icon: Icons.warning_amber_rounded,
      ));
    }

    // Moving Average Trend factor
    if (ema20 > ema50) {
      score += 25;
      reasons.add(const SignalReason(
        title: 'Golden Trend (EMA 20 > EMA 50)',
        description: 'Short-term momentum is decisively above longer-term trend.',
        isBullish: true,
        icon: Icons.moving_rounded,
      ));
    } else {
      score -= 25;
      reasons.add(const SignalReason(
        title: 'Death Trend (EMA 20 < EMA 50)',
        description: 'Sellers in control on lower timeframe moving averages.',
        isBullish: false,
        icon: Icons.timeline_rounded,
      ));
    }

    // MACD factor
    if (macd.hist > 0) {
      score += 20;
      reasons.add(const SignalReason(
        title: 'Bullish MACD Momentum',
        description: 'MACD histogram is expanding positive, confirming upward surge.',
        isBullish: true,
        icon: Icons.flash_on_rounded,
      ));
    } else {
      score -= 20;
      reasons.add(const SignalReason(
        title: 'Bearish MACD Momentum',
        description: 'MACD histogram shows downward seller velocity.',
        isBullish: false,
        icon: Icons.south_east_rounded,
      ));
    }

    // 24h price action factor
    if (stock.changePercentage > 3) {
      score += 15;
    } else if (stock.changePercentage < -3) {
      score -= 15;
    }

    score = score.clamp(-100, 100);

    // 7. Spot Advice
    final spotAdvice = _buildSpotAdvice(currentPrice, score, support, resistance, reasons, atrPct);

    // 8. Futures Advice (Leverage & Direction)
    final isStock = stock.symbol.endsWith('.NS') ||
        stock.symbol.endsWith('.BO') ||
        stock.symbol.startsWith('^') ||
        stock.category != 'Crypto';
    final futuresAdvice = _buildFuturesAdvice(currentPrice, score, support, resistance, reasons, atrPct, isStock: isStock);

    return TechnicalAnalysisResult(
      currentPrice: currentPrice,
      rsi: rsi,
      macdLine: macd.line,
      macdSignal: macd.signal,
      macdHist: macd.hist,
      ema20: ema20,
      ema50: ema50,
      atrPct: atrPct,
      support: support,
      resistance: resistance,
      spotAdvice: spotAdvice,
      futuresAdvice: futuresAdvice,
      compositeScore: score,
    );
  }

  static SpotAdvice _buildSpotAdvice(
    double price,
    int score,
    double support,
    double resistance,
    List<SignalReason> reasons,
    double atrPct,
  ) {
    SignalAction action;
    String title;
    String summary;

    final entryLow = price * 0.985;
    final entryHigh = price * 1.005;
    double target;
    double stopLoss;

    if (score >= 40) {
      action = SignalAction.strongBuy;
      title = 'STRONG BUY / ACCUMULATE';
      summary = 'Confluence of bullish indicators indicates high probability continuation. Excellent risk/reward zone for spot accumulation.';
      target = max(resistance, price * 1.06);
      stopLoss = min(support, price * 0.96);
    } else if (score >= 15) {
      action = SignalAction.buy;
      title = 'BUY ON PULLBACK';
      summary = 'Market structure is bullish. Enter on minor dips towards support with targets set at recent swing highs.';
      target = max(resistance, price * 1.045);
      stopLoss = min(support, price * 0.965);
    } else if (score <= -40) {
      action = SignalAction.strongSell;
      title = 'STRONG SELL / EXIT';
      summary = 'Severe bearish pressure and moving average breakdown. Recommended to sell spot holdings or preserve capital.';
      target = min(support, price * 0.93);
      stopLoss = max(resistance, price * 1.04);
    } else if (score <= -15) {
      action = SignalAction.sell;
      title = 'TAKE PROFIT / LIGHTEN';
      summary = 'Upward momentum waning near resistance. Consider trimming profits or placing tight trailing stop-losses.';
      target = min(support, price * 0.95);
      stopLoss = max(resistance, price * 1.035);
    } else {
      action = SignalAction.neutral;
      title = 'HOLD / RANGE BOUND';
      summary = 'Price is consolidating in a neutral band. Wait for a definitive breakout above resistance before buying.';
      target = resistance;
      stopLoss = support;
    }

    final targetGainPct = ((target - price) / price) * 100;
    final stopLossPct = ((stopLoss - price) / price).abs() * 100;
    final confidence = (score.abs() * 0.6 + 40.0).clamp(40.0, 95.0);

    return SpotAdvice(
      action: action,
      title: title,
      summary: summary,
      entryZoneLow: entryLow,
      entryZoneHigh: entryHigh,
      targetPrice: target,
      targetGainPct: targetGainPct,
      stopLossPrice: stopLoss,
      stopLossPct: stopLossPct,
      keyDrivers: reasons,
      confidenceScore: confidence,
    );
  }

  static FuturesAdvice _buildFuturesAdvice(
    double price,
    int score,
    double support,
    double resistance,
    List<SignalReason> reasons,
    double atrPct, {
    bool isStock = false,
  }) {
    // 1. Determine Bias
    final FuturesBias bias;
    if (score >= 20) {
      bias = FuturesBias.long;
    } else if (score <= -20) {
      bias = FuturesBias.short;
    } else {
      bias = FuturesBias.neutral;
    }

    // 2. Compute Safe Recommended Leverage based on ATR Volatility
    int leverage;
    String riskLevel;
    String leverageRationale;

    if (atrPct >= 4.5) {
      leverage = 2;
      riskLevel = 'High Volatility';
      leverageRationale = 'High market volatility (ATR: ${atrPct.toStringAsFixed(1)}%). Conservative 2x leverage prevents sudden liquidation wicks.';
    } else if (atrPct >= 2.8) {
      leverage = 5;
      riskLevel = 'Moderate Volatility';
      leverageRationale = 'Moderate price swings. 5x leverage offers balanced amplification while keeping liquidation at a safe 20% distance.';
    } else if (atrPct >= 1.5) {
      leverage = 10;
      riskLevel = 'Balanced';
      leverageRationale = 'Standard volatility range. 10x leverage offers disciplined growth with an approximate 10% liquidation buffer.';
    } else {
      leverage = 20;
      riskLevel = 'Low Volatility / Squeeze';
      leverageRationale = 'Tight consolidation detected (ATR: ${atrPct.toStringAsFixed(1)}%). 20x leverage is suitable for catching the initial breakout burst.';
    }

    if (isStock) {
      leverage = min(leverage, 5);
      leverage = max(leverage, 1);
      leverageRationale = 'Stock Margin Model: Maximum regulatory intraday leverage is 5x with a 20% stop boundary.';
    }

    // 3. Targets and Stop Loss
    double target1;
    double target2;
    double stopLoss;

    if (bias == FuturesBias.short) {
      target1 = price * (1 - (max(atrPct * 1.0, 2.0) / 100));
      target2 = min(support, price * (1 - (max(atrPct * 2.2, 4.5) / 100)));
      stopLoss = max(resistance, price * (1 + (max(atrPct * 0.8, 1.8) / 100)));
    } else {
      // Long or Neutral
      target1 = price * (1 + (max(atrPct * 1.0, 2.0) / 100));
      target2 = max(resistance, price * (1 + (max(atrPct * 2.2, 4.5) / 100)));
      stopLoss = min(support, price * (1 - (max(atrPct * 0.8, 1.8) / 100)));
    }

    // 4. Liquidation Calculation
    final double liquidationPrice;
    final double liquidationDistancePct = 100.0 / leverage;

    if (bias == FuturesBias.short) {
      liquidationPrice = price * (1 + 1 / leverage);
    } else {
      liquidationPrice = price * (1 - 1 / leverage);
    }

    // 5. Risk / Reward Ratio
    final reward = (target1 - price).abs();
    final risk = (price - stopLoss).abs();
    final rrRatio = risk > 0 ? (reward / risk) : 2.0;
    final confidence = (score.abs() * 0.55 + 42.0).clamp(42.0, 94.0);

    return FuturesAdvice(
      bias: bias,
      recommendedLeverage: leverage,
      leverageRationale: leverageRationale,
      entryPrice: price,
      targetPrice1: target1,
      targetPrice2: target2,
      stopLossPrice: stopLoss,
      riskRewardRatio: double.parse(rrRatio.toStringAsFixed(1)),
      estimatedLiquidationPrice: liquidationPrice,
      liquidationDistancePct: liquidationDistancePct,
      riskLevel: riskLevel,
      keyDrivers: reasons,
      confidenceScore: confidence,
    );
  }

  static TechnicalAnalysisResult _generateFallbackAnalysis(Stock stock, double currentPrice) {
    final isPositive = stock.changePercentage >= 0;
    final score = isPositive
        ? min(60, (stock.changePercentage * 8).round())
        : max(-60, (stock.changePercentage * 8).round());

    final reasons = [
      SignalReason(
        title: isPositive ? '24h Bullish Outperformance' : '24h Bearish Pullback',
        description: '24h price change is ${stock.changePercentage >= 0 ? "+" : ""}${stock.changePercentage.toStringAsFixed(2)}%.',
        isBullish: isPositive,
        icon: isPositive ? Icons.trending_up : Icons.trending_down,
      ),
    ];

    final support = currentPrice * 0.95;
    final resistance = currentPrice * 1.05;
    const atrPct = 2.5;

    final isStock = stock.symbol.endsWith('.NS') ||
        stock.symbol.endsWith('.BO') ||
        stock.symbol.startsWith('^') ||
        stock.category != 'Crypto';

    return TechnicalAnalysisResult(
      currentPrice: currentPrice,
      rsi: isPositive ? 54.0 : 42.0,
      macdLine: isPositive ? 0.4 : -0.4,
      macdSignal: 0.0,
      macdHist: isPositive ? 0.4 : -0.4,
      ema20: currentPrice * (isPositive ? 0.99 : 1.01),
      ema50: currentPrice * (isPositive ? 0.97 : 1.02),
      atrPct: atrPct,
      support: support,
      resistance: resistance,
      spotAdvice: _buildSpotAdvice(currentPrice, score, support, resistance, reasons, atrPct),
      futuresAdvice: _buildFuturesAdvice(currentPrice, score, support, resistance, reasons, atrPct, isStock: isStock),
      compositeScore: score,
    );
  }

  // ── Helper Math Calculations ──────────────────────────────────────────────

  static List<double> _calculateRsiSeries(List<double> closes, int period) {
    final len = closes.length;
    final out = List<double>.filled(len, 50.0);
    if (len <= period) return out;

    double gains = 0;
    double losses = 0;
    for (int i = 1; i <= period; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff >= 0) {
        gains += diff;
      } else {
        losses += diff.abs();
      }
    }

    double avgGain = gains / period;
    double avgLoss = losses / period;
    out[period] = avgLoss == 0 ? 100.0 : 100.0 - (100.0 / (1.0 + (avgGain / avgLoss)));

    for (int i = period + 1; i < len; i++) {
      final diff = closes[i] - closes[i - 1];
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? diff.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      out[i] = avgLoss == 0 ? 100.0 : 100.0 - (100.0 / (1.0 + (avgGain / avgLoss)));
    }
    return out;
  }

  static double _calculateRSI(List<double> closes, int period) {
    if (closes.length <= period) return 50.0;
    return _calculateRsiSeries(closes, period).last;
  }

  static List<double> _calculateEmaSeries(List<double> closes, int period) {
    final len = closes.length;
    if (len == 0) return const [];
    if (len < period) return List<double>.from(closes);

    final out = List<double>.filled(len, 0.0);
    double sum = 0.0;
    for (int i = 0; i < period; i++) {
      sum += closes[i];
      out[i] = sum / (i + 1);
    }

    final k = 2.0 / (period + 1);
    double ema = out[period - 1];
    for (int i = period; i < len; i++) {
      ema = (closes[i] * k) + (ema * (1.0 - k));
      out[i] = ema;
    }
    return out;
  }

  static double _calculateEMA(List<double> closes, int period) {
    if (closes.isEmpty) return 0.0;
    if (closes.length < period) return closes.last;
    return _calculateEmaSeries(closes, period).last;
  }

  static ({double line, double signal, double hist}) _calculateMACD(List<double> closes) {
    if (closes.length < 26) return (line: 0.0, signal: 0.0, hist: 0.0);

    final ema12 = _calculateEMA(closes, 12);
    final ema26 = _calculateEMA(closes, 26);
    final line = ema12 - ema26;
    final signal = line * 0.8; // Approximate smoothing for single-pass
    final hist = line - signal;

    return (line: line, signal: signal, hist: hist);
  }

  static double _calculateAtrPctAt(List<StockCandle> candles, int endIdx, double currentPrice) {
    if (endIdx < 4 || candles.length < 5 || currentPrice <= 0) return 2.5;

    final available = endIdx + 1;
    final count = min(14, available);
    final start = available - count;
    double trSum = 0;

    for (int i = start; i <= endIdx; i++) {
      final c = candles[i];
      final prevClose = i > 0 ? candles[i - 1].close : c.open;
      final tr = max(c.high - c.low, max((c.high - prevClose).abs(), (c.low - prevClose).abs()));
      trSum += tr;
    }

    final atr = trSum / count;
    return ((atr / currentPrice) * 100.0).clamp(0.5, 12.0);
  }

  static double _calculateAtrPct(List<StockCandle> candles, double currentPrice) {
    if (candles.isEmpty) return 2.5;
    return _calculateAtrPctAt(candles, candles.length - 1, currentPrice);
  }

  /// Estimates trend alignment across 15m, 1H, 4H, and 1D timeframes
  static List<TimeframeSignal> getMultiTimeframeConfluence(Stock stock, TechnicalAnalysisResult current) {
    final score = current.compositeScore;
    final rsi = current.rsi;
    final chg = stock.changePercentage;

    // 15m (Short-term momentum)
    final tf15Bullish = (rsi > 42 && rsi < 72) || chg > 1.0;
    final tf15Trend = tf15Bullish ? 'Bullish' : (rsi > 72 || chg < -1.5 ? 'Bearish' : 'Neutral');

    // 1H (Current timeframe analysis)
    final tf1hTrend = score > 15 ? 'Bullish' : (score < -15 ? 'Bearish' : 'Neutral');

    // 4H (Intermediate trend - EMA 20 vs 50)
    final tf4hTrend = current.ema20 >= current.ema50 ? 'Bullish' : 'Bearish';

    // 1D (Macro trend)
    final tf1dTrend = chg >= 0 ? (score > -20 ? 'Bullish' : 'Neutral') : (score < 20 ? 'Bearish' : 'Neutral');

    return [
      TimeframeSignal(
        label: '15m',
        trend: tf15Trend,
        confidence: (current.spotAdvice.confidenceScore * 0.95).clamp(50, 98),
        color: tf15Trend == 'Bullish'
            ? const Color(0xFF0ECB81)
            : (tf15Trend == 'Bearish' ? const Color(0xFFF6465D) : const Color(0xFFF0B90B)),
      ),
      TimeframeSignal(
        label: '1H',
        trend: tf1hTrend,
        confidence: current.spotAdvice.confidenceScore,
        color: tf1hTrend == 'Bullish'
            ? const Color(0xFF0ECB81)
            : (tf1hTrend == 'Bearish' ? const Color(0xFFF6465D) : const Color(0xFFF0B90B)),
      ),
      TimeframeSignal(
        label: '4H',
        trend: tf4hTrend,
        confidence: (current.spotAdvice.confidenceScore * 1.02).clamp(50, 99),
        color: tf4hTrend == 'Bullish' ? const Color(0xFF0ECB81) : const Color(0xFFF6465D),
      ),
      TimeframeSignal(
        label: '1D',
        trend: tf1dTrend,
        confidence: (current.spotAdvice.confidenceScore * 0.98).clamp(50, 99),
        color: tf1dTrend == 'Bullish'
            ? const Color(0xFF0ECB81)
            : (tf1dTrend == 'Bearish' ? const Color(0xFFF6465D) : const Color(0xFFF0B90B)),
      ),
    ];
  }

  /// Scans the entire market and ranks opportunities by signal strength
  static List<MarketSignalItem> scanMarket(List<Stock> market) {
    final list = <MarketSignalItem>[];
    for (final s in market) {
      if (s.currentPrice > 0) {
        final analysis = analyze(s);
        list.add(MarketSignalItem(stock: s, analysis: analysis));
      }
    }
    list.sort((a, b) {
      final scoreA = a.analysis.compositeScore.abs() * a.analysis.spotAdvice.confidenceScore;
      final scoreB = b.analysis.compositeScore.abs() * b.analysis.spotAdvice.confidenceScore;
      return scoreB.compareTo(scoreA);
    });
    return list;
  }

  /// Summarizes any list of signal executions into exact aggregate metrics.
  static SignalTrackRecordReport summarizeTrackRecord(
    List<SignalTrackRecordItem> records, {
    int assetsAudited = 0,
    bool isLiveAudit = true,
  }) {
    if (records.isEmpty) {
      return SignalTrackRecordReport(
        records: const [],
        totalTrades: 0,
        winCount: 0,
        lossCount: 0,
        winRatePct: 0.0,
        avgWinPct: 0.0,
        avgLossPct: 0.0,
        profitRatio: 0.0,
        assetsAudited: assetsAudited,
        isLiveAudit: isLiveAudit,
      );
    }

    final sorted = List<SignalTrackRecordItem>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    int winCount = 0;
    int lossCount = 0;
    double winSum = 0.0;
    double lossSum = 0.0;
    DateTime minDate = sorted.first.entryDate;
    DateTime maxDate = sorted.first.date;

    for (final rec in sorted) {
      if (rec.isWin) {
        winCount++;
        winSum += rec.returnPct;
      } else {
        lossCount++;
        lossSum += rec.returnPct.abs();
      }
      if (rec.entryDate.isBefore(minDate)) minDate = rec.entryDate;
      if (rec.date.isAfter(maxDate)) maxDate = rec.date;
    }

    final total = sorted.length;
    final winRatePct = (winCount / total) * 100.0;
    final avgWinPct = winCount > 0 ? winSum / winCount : 0.0;
    final avgLossPct = lossCount > 0 ? lossSum / lossCount : 0.0;
    final profitRatio = avgLossPct > 0
        ? avgWinPct / avgLossPct
        : (avgWinPct > 0 ? avgWinPct : 0.0);

    return SignalTrackRecordReport(
      records: sorted,
      totalTrades: total,
      winCount: winCount,
      lossCount: lossCount,
      winRatePct: winRatePct,
      avgWinPct: avgWinPct,
      avgLossPct: avgLossPct,
      profitRatio: profitRatio,
      assetsAudited: assetsAudited,
      isLiveAudit: isLiveAudit,
      periodStart: minDate,
      periodEnd: maxDate,
    );
  }

  /// Runs a strict walk-forward historical backtest (zero future look-ahead)
  /// over real OHLC candles across the given market.
  static SignalTrackRecordReport runTrackRecordBacktest({
    required List<Stock> market,
    required bool isStock,
    Map<String, List<StockCandle>>? extendedCandles,
    String? symbolFilter,
  }) {
    final allTrades = <SignalTrackRecordItem>[];
    int assetsAudited = 0;
    bool anyLiveAsset = false;

    final liveAssets = market.where((s) => s.isLive).toList();
    final sourceAssets = liveAssets.isNotEmpty ? liveAssets : market;

    for (final stock in sourceAssets) {
      final cleanSym = stock.symbol.toUpperCase();
      if (symbolFilter != null &&
          symbolFilter.isNotEmpty &&
          cleanSym != symbolFilter.toUpperCase()) {
        continue;
      }

      final ext = extendedCandles?[cleanSym] ?? extendedCandles?[stock.symbol];
      final candles = (ext != null && ext.length >= 55) ? ext : stock.candleHistory;
      if (candles.length < 55) continue;

      assetsAudited++;
      if (stock.isLive || (ext != null && ext.length >= 55)) {
        anyLiveAsset = true;
      }

      allTrades.addAll(
        _backtestAsset(
          symbol: cleanSym,
          candles: candles,
          isStock: isStock,
          currency: stock.currency,
        ),
      );
    }

    return summarizeTrackRecord(
      allTrades,
      assetsAudited: assetsAudited,
      isLiveAudit: anyLiveAsset,
    );
  }

  static List<SignalTrackRecordItem> _backtestAsset({
    required String symbol,
    required List<StockCandle> candles,
    required bool isStock,
    required String currency,
  }) {
    final closes = candles.map((c) => c.close).toList(growable: false);
    final rsiSeries = _calculateRsiSeries(closes, 14);
    final ema12Series = _calculateEmaSeries(closes, 12);
    final ema20Series = _calculateEmaSeries(closes, 20);
    final ema26Series = _calculateEmaSeries(closes, 26);
    final ema50Series = _calculateEmaSeries(closes, 50);

    final trades = <SignalTrackRecordItem>[];
    int i = 50;

    while (i < candles.length - 3) {
      final entryPrice = closes[i];
      if (entryPrice <= 0) {
        i++;
        continue;
      }

      final rsi = rsiSeries[i];
      final e20 = ema20Series[i];
      final e50 = ema50Series[i];
      final macdNow = ema12Series[i] - ema26Series[i];
      final macdPrev = ema12Series[i - 1] - ema26Series[i - 1];
      final mom3 = ((entryPrice - closes[i - 3]) / closes[i - 3]) * 100.0;
      final atrPct = _calculateAtrPctAt(candles, i, entryPrice);

      // Confluence setup: Trend (EMA20 vs EMA50) + expanding MACD + 3-bar momentum + non-exhausted RSI
      final isBull = e20 > e50 &&
          macdNow > 0 &&
          macdNow > macdPrev &&
          mom3 > 0.2 &&
          rsi >= 40.0 &&
          rsi <= 65.0 &&
          entryPrice > e20;

      final isBear = e20 < e50 &&
          macdNow < 0 &&
          macdNow < macdPrev &&
          mom3 < -0.2 &&
          rsi >= 35.0 &&
          rsi <= 60.0 &&
          entryPrice < e20;

      if (!isBull && !isBear) {
        i++;
        continue;
      }

      final isLong = isBull;
      int baseLev;
      if (atrPct >= 4.5) {
        baseLev = 2;
      } else if (atrPct >= 2.8) {
        baseLev = 5;
      } else if (atrPct >= 1.5) {
        baseLev = 10;
      } else {
        baseLev = 20;
      }
      if (isStock) {
        baseLev = baseLev.clamp(1, 5);
      }

      final trendGap = (e20 - e50).abs() / entryPrice;
      final highConviction = trendGap >= 0.008 &&
          ((isLong && rsi <= 56.0) || (!isLong && rsi >= 44.0));

      final String typeLabel;
      final int effectiveLeverage;
      if (isLong && trendGap < 0.006) {
        typeLabel = isStock ? 'Delivery Breakout' : 'Spot Breakout';
        effectiveLeverage = 1;
      } else {
        typeLabel = isStock
            ? '${baseLev}x Margin ${isLong ? "Long" : "Short"}'
            : '${baseLev}x Futures ${isLong ? "Long" : "Short"}';
        effectiveLeverage = baseLev;
      }

      final riskPct = max(atrPct * 1.8, isStock ? 1.8 : 2.2) / 100.0;
      final tpMult = highConviction ? 2.0 : 1.4;
      final double targetPrice = isLong
          ? entryPrice * (1.0 + riskPct * tpMult)
          : entryPrice * (1.0 - riskPct * tpMult);
      final double stopLossPrice = isLong
          ? entryPrice * (1.0 - riskPct)
          : entryPrice * (1.0 + riskPct);

      int exitIdx = -1;
      double exitPrice = 0.0;
      bool isWin = false;
      String targetHit = '';

      final maxLookAhead = min(candles.length, i + 72);
      for (int j = i + 1; j < maxLookAhead; j++) {
        final c = candles[j];
        if (isLong) {
          // Conservative intrabar ordering: check stop-loss first
          if (c.low <= stopLossPrice) {
            exitIdx = j;
            exitPrice = stopLossPrice;
            isWin = false;
            targetHit = 'Stop Loss Hit 🛑';
            break;
          }
          if (c.high >= targetPrice) {
            exitIdx = j;
            exitPrice = targetPrice;
            isWin = true;
            targetHit = highConviction ? 'Target 2 Hit 🎯' : 'Target 1 Hit 🎯';
            break;
          }
        } else {
          if (c.high >= stopLossPrice) {
            exitIdx = j;
            exitPrice = stopLossPrice;
            isWin = false;
            targetHit = 'Stop Loss Hit 🛑';
            break;
          }
          if (c.low <= targetPrice) {
            exitIdx = j;
            exitPrice = targetPrice;
            isWin = true;
            targetHit = highConviction ? 'Target 2 Hit 🎯' : 'Target 1 Hit 🎯';
            break;
          }
        }
      }

      if (exitIdx != -1) {
        final rawMove = isLong
            ? (exitPrice - entryPrice) / entryPrice
            : (entryPrice - exitPrice) / entryPrice;
        final returnPct = rawMove * effectiveLeverage * 100.0;
        trades.add(
          SignalTrackRecordItem(
            symbol: symbol,
            type: typeLabel,
            entryPrice: entryPrice,
            exitPrice: exitPrice,
            returnPct: returnPct,
            isWin: isWin,
            targetHit: targetHit,
            entryDate: candles[i].date,
            date: candles[exitIdx].date,
            isLong: isLong,
            leverage: effectiveLeverage,
            isStock: isStock,
            currency: currency,
          ),
        );
        i = exitIdx + 3; // Cooldown before next setup on same asset
      } else {
        i++;
      }
    }

    return trades;
  }
}
