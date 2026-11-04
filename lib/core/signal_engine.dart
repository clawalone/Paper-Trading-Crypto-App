import 'dart:math';
import 'package:flutter/material.dart';
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
    final futuresAdvice = _buildFuturesAdvice(currentPrice, score, support, resistance, reasons, atrPct);

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
    double atrPct,
  ) {
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
      futuresAdvice: _buildFuturesAdvice(currentPrice, score, support, resistance, reasons, atrPct),
      compositeScore: score,
    );
  }

  // ── Helper Math Calculations ──────────────────────────────────────────────

  static double _calculateRSI(List<double> closes, int period) {
    if (closes.length <= period) return 50.0;

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

    for (int i = period + 1; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? diff.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
    }

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  static double _calculateEMA(List<double> closes, int period) {
    if (closes.isEmpty) return 0.0;
    if (closes.length < period) return closes.last;

    final k = 2.0 / (period + 1);
    double ema = closes.sublist(0, period).reduce((a, b) => a + b) / period;

    for (int i = period; i < closes.length; i++) {
      ema = (closes[i] * k) + (ema * (1.0 - k));
    }
    return ema;
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

  static double _calculateAtrPct(List<StockCandle> candles, double currentPrice) {
    if (candles.length < 5 || currentPrice <= 0) return 2.5;

    double trSum = 0;
    final count = min(14, candles.length);
    final start = candles.length - count;

    for (int i = start; i < candles.length; i++) {
      final c = candles[i];
      final prevClose = i > 0 ? candles[i - 1].close : c.open;
      final tr = max(c.high - c.low, max((c.high - prevClose).abs(), (c.low - prevClose).abs()));
      trSum += tr;
    }

    final atr = trSum / count;
    return ((atr / currentPrice) * 100.0).clamp(0.5, 12.0);
  }
}
