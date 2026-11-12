import 'package:flutter_test/flutter_test.dart';
import 'package:stock_arena/core/signal_engine.dart';
import 'package:stock_arena/data/models.dart';

List<StockCandle> _buildTrendingWaveCandles({
  required DateTime start,
  required int count,
  required double startPrice,
}) {
  final candles = <StockCandle>[];
  double price = startPrice;
  for (int i = 0; i < count; i++) {
    final double ret;
    if (i < 45) {
      ret = 0.001; // Warmup base trend
    } else {
      final cycle = (i - 45) % 18;
      if (cycle < 6) {
        ret = -0.004; // Pullback cools RSI below 60 while EMA20 stays above EMA50
      } else {
        ret = 0.0065; // Impulse surge hits TP cleanly
      }
    }
    final open = price;
    final close = price * (1.0 + ret);
    final high = (open > close ? open : close) * 1.003;
    final low = (open < close ? open : close) * 0.997;
    candles.add(
      StockCandle(
        date: start.add(Duration(hours: i)),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 100000,
      ),
    );
    price = close;
  }
  return candles;
}

void main() {
  group('SignalEngine Track Record Backtest', () {
    test('summarizeTrackRecord computes exact win rate, avg win/loss, and profit ratio', () {
      final t0 = DateTime(2026, 11, 1, 10);
      final items = [
        SignalTrackRecordItem(
          symbol: 'NVDA',
          type: '5x Margin Long',
          entryPrice: 100.0,
          exitPrice: 104.0,
          returnPct: 20.0,
          isWin: true,
          targetHit: 'Target 2 Hit 🎯',
          entryDate: t0,
          date: t0.add(const Duration(hours: 4)),
          isLong: true,
          leverage: 5,
          isStock: true,
        ),
        SignalTrackRecordItem(
          symbol: 'AAPL',
          type: 'Delivery Breakout',
          entryPrice: 200.0,
          exitPrice: 210.0,
          returnPct: 5.0,
          isWin: true,
          targetHit: 'Target 1 Hit 🎯',
          entryDate: t0.add(const Duration(hours: 1)),
          date: t0.add(const Duration(hours: 6)),
          isLong: true,
          leverage: 1,
          isStock: true,
        ),
        SignalTrackRecordItem(
          symbol: 'META',
          type: '5x Margin Short',
          entryPrice: 500.0,
          exitPrice: 505.0,
          returnPct: -5.0,
          isWin: false,
          targetHit: 'Stop Loss Hit 🛑',
          entryDate: t0.add(const Duration(hours: 2)),
          date: t0.add(const Duration(hours: 8)),
          isLong: false,
          leverage: 5,
          isStock: true,
        ),
      ];

      final report = SignalEngine.summarizeTrackRecord(items, assetsAudited: 3);

      expect(report.totalTrades, 3);
      expect(report.winCount, 2);
      expect(report.lossCount, 1);
      expect(report.winRatePct, closeTo(66.666, 0.01));
      expect(report.avgWinPct, closeTo(12.5, 0.01)); // (20 + 5) / 2
      expect(report.avgLossPct, closeTo(5.0, 0.01));
      expect(report.profitRatio, closeTo(2.5, 0.01)); // 12.5 / 5.0
      // Sorted newest first
      expect(report.records.first.symbol, 'META');
      expect(report.records.last.symbol, 'NVDA');
    });

    test('runTrackRecordBacktest walks historical candles with consistent exit math and timestamps', () {
      final start = DateTime(2026, 10, 15, 9, 0);
      final candles = _buildTrendingWaveCandles(
        start: start,
        count: 140,
        startPrice: 150.0,
      );

      final stock = Stock(
        symbol: 'NVDA',
        name: 'NVIDIA',
        category: 'US Tech',
        currentPrice: candles.last.close,
        previousClose: candles[candles.length - 2].close,
        dayHigh: candles.last.high,
        dayLow: candles.last.low,
        volume: 5000000,
        history: candles.map((c) => c.close).toList(),
        candleHistory: candles,
        about: 'Test asset',
        supply: 1000000,
        rank: 1,
        isLive: true,
        isStock: true,
      );

      final report = SignalEngine.runTrackRecordBacktest(
        market: [stock],
        isStock: true,
      );

      expect(report.assetsAudited, 1);
      expect(report.isLiveAudit, true);
      expect(report.totalTrades, greaterThan(0));

      for (final rec in report.records) {
        // Dates come strictly from the input candle timeline, never synthetic future dates
        expect(rec.entryDate.isBefore(rec.date), true);
        expect(rec.date.isAfter(candles.last.date), false);
        expect(rec.entryDate.isBefore(start), false);

        // Leveraged returnPct matches exact entry -> exit price move
        final rawMove = rec.isLong
            ? (rec.exitPrice - rec.entryPrice) / rec.entryPrice
            : (rec.entryPrice - rec.exitPrice) / rec.entryPrice;
        final expectedReturn = rawMove * rec.leverage * 100.0;
        expect(rec.returnPct, closeTo(expectedReturn, 0.001));
        expect(rec.isWin, rec.returnPct > 0);
      }
    });
  });
}
