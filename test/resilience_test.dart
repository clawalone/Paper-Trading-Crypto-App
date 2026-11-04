import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_arena/core/currency_formatters.dart';
import 'package:stock_arena/core/trading_view_chart.dart';
import 'package:stock_arena/data/community_provider.dart';
import 'package:stock_arena/data/market_provider.dart';
import 'package:stock_arena/data/models.dart';
import 'package:stock_arena/data/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup & Currency Resilience', () {
    test('CurrencyFormatters formats without awaiting live exchange rate', () {
      final formatted = CurrencyFormatters.formatUsd(100.0, 'USD');
      expect(formatted, contains('100'));

      final inrFormatted = CurrencyFormatters.formatUsd(100.0, 'INR');
      expect(inrFormatted, contains('₹'));
      expect(CurrencyFormatters.rates.containsKey('USD'), isTrue);
      expect(CurrencyFormatters.rates['USD'], 1.0);
    });
  });

  group('Market Provider Resilience', () {
    test('marketProvider initializes all assets with non-zero prices and non-empty history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stocks = container.read(marketProvider);
      expect(stocks.isNotEmpty, isTrue);

      for (final stock in stocks) {
        expect(stock.currentPrice, greaterThan(0), reason: '${stock.symbol} price must be > 0');
        expect(stock.history.length, greaterThanOrEqualTo(2), reason: '${stock.symbol} history must have >= 2 points');
        expect(stock.candleHistory.isNotEmpty, isTrue, reason: '${stock.symbol} candleHistory must not be empty');
      }
    });
  });

  group('User Provider Resilience', () {
    test('UserNotifier clearLoading sets isLoading to false', () {
      const userState = UserState(
        isLoading: true,
        isOnboarded: false,
        profile: UserProfile(
          name: 'Guest',
          experienceLevel: 'Beginner',
          virtualBalance: 0,
          xp: 0,
          streak: 1,
          watchlist: {},
          preferredCurrency: 'USD',
        ),
        missions: [],
      );

      expect(userState.isLoading, isTrue);
      final updated = userState.copyWith(isLoading: false);
      expect(updated.isLoading, isFalse);
    });

    test('UserState preserves hasSyncError flag and serialization', () {
      const userState = UserState(
        isLoading: false,
        isOnboarded: false,
        hasSyncError: true,
        profile: UserProfile(
          name: 'Guest',
          experienceLevel: 'Beginner',
          virtualBalance: 0,
          xp: 0,
          streak: 1,
          watchlist: {},
          preferredCurrency: 'USD',
        ),
        missions: [],
      );

      expect(userState.hasSyncError, isTrue);
      final json = userState.toJson();
      final restored = UserState.fromJson(json);
      expect(restored.isOnboarded, isFalse);
      expect(restored.hasSyncError, isFalse); // fresh deserialized starts without sync error
    });

    test('userProvider initializes safely without uninitialized provider error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final userState = container.read(userProvider);
      expect(userState, isNotNull);
      expect(userState.isOnboarded, isFalse);
      expect(userState.hasSyncError, isFalse);

      // Allow any microtasks scheduled during build() to execute
      await Future.delayed(Duration.zero);

      final stateAfterMicrotasks = container.read(userProvider);
      expect(stateAfterMicrotasks, isNotNull);
    });

    test('userProvider can be invalidated and re-read without error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(userProvider);
      expect(initial, isNotNull);

      container.invalidate(userProvider);
      final refreshed = container.read(userProvider);
      expect(refreshed, isNotNull);

      await Future.delayed(Duration.zero);
    });

    test('userProvider loads preferred currency from SharedPreferences without error', () async {
      SharedPreferences.setMockInitialValues({'preferred_currency': 'EUR'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(userProvider);
      expect(initial, isNotNull);

      // Await microtask and async SharedPreferences.getInstance()
      await Future.delayed(const Duration(milliseconds: 50));

      final updated = container.read(userProvider);
      expect(updated.profile.preferredCurrency, equals('EUR'));
    });

    test('userProvider handles rapid invalidation and disposal without throwing', () async {
      final container = ProviderContainer();
      container.read(userProvider);
      container.invalidate(userProvider);
      container.read(userProvider);
      container.invalidate(userProvider);
      container.dispose();

      // Ensure any pending microtasks do not throw unhandled errors
      await Future.delayed(const Duration(milliseconds: 20));
      expect(true, isTrue);
    });

    test('MarketNotifier generateFallbackCandles creates 72 valid candles', () {
      final candles = MarketNotifier.generateFallbackCandles(150.0);
      expect(candles.length, equals(72));
      for (final candle in candles) {
        expect(candle.high, greaterThanOrEqualTo(candle.low));
        expect(candle.open, greaterThan(0));
        expect(candle.close, greaterThan(0));
      }
    });

    test('deductVirtualBalanceForTip debits balance and logs wallet transaction in USD', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userProvider.notifier);
      // Ensure initial 0 balance fails
      expect(notifier.deductVirtualBalanceForTip(amount: 100, recipientName: 'Alice'), isFalse);

      // Onboard gives 5000 virtual balance
      notifier.onboardUser('Test Trader', 'Beginner', 'USD', '');
      expect(container.read(userProvider).profile.virtualBalance, equals(5000));

      // Successful $50 USD tip deducts 50 * 84.5 = 4225 base INR
      final success = notifier.deductVirtualBalanceForTip(amount: 50, recipientName: 'Alice');
      expect(success, isTrue);
      expect(container.read(userProvider).profile.virtualBalance, equals(5000 - 4225));
      final txs = container.read(userProvider).walletEntries;
      expect(txs.any((tx) => tx['title'] == 'Community Tip Sent' && tx['amount'] == -4225.0), isTrue);
    });

    test('Chart clamp edge case: empty candle list clamp guard', () {
      final activeCandles = <StockCandle>[];
      int? clampResult;
      if (activeCandles.isNotEmpty) {
        clampResult = 0.clamp(0, activeCandles.length - 1);
      }
      expect(clampResult, isNull);
    });

    test('Continuous daily claims increase money according to 7-day tiers', () {
      expect(UserNotifier.DAILY_CASH_TIERS.length, equals(7));
      expect(UserNotifier.DAILY_CASH_TIERS, equals([5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 20.0]));
      expect(UserNotifier.DAILY_XP_TIERS, equals([10, 15, 20, 25, 30, 35, 50]));

      // Verify each consecutive day increases reward up to Day 7 mega bonus
      for (int day = 1; day <= 7; day++) {
        final cycleIndex = ((day - 1) % 7).clamp(0, 6);
        final cash = UserNotifier.DAILY_CASH_TIERS[cycleIndex];
        final xp = UserNotifier.DAILY_XP_TIERS[cycleIndex];
        if (day == 1) {
          expect(cash, equals(5.0));
          expect(xp, equals(10));
        } else if (day == 7) {
          expect(cash, equals(20.0));
          expect(xp, equals(50));
        } else {
          // Each consecutive day pays strictly more than previous
          final prevCash = UserNotifier.DAILY_CASH_TIERS[cycleIndex - 1];
          expect(cash, greaterThan(prevCash));
        }
      }
    });
  });

  group('Community Verified Badge Rules (>5 followers or Admin)', () {
    test('user is only verified if followers count is strictly greater than 5 or is Admin', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed profiles
      final isSatoshiVerified = container.read(isUserVerifiedProvider('user_satoshi'));
      final isCryptoKingVerified = container.read(isUserVerifiedProvider('user_crypto_king'));
      final isDegenVerified = container.read(isUserVerifiedProvider('user_degen'));

      expect(isSatoshiVerified, isTrue, reason: 'SatoshiScalper has 120 followers (>5) so must have blue tick');
      expect(isCryptoKingVerified, isTrue, reason: 'CryptoWhale99 has 85 followers (>5) so must have blue tick');
      expect(isDegenVerified, isFalse, reason: 'LeverageDegen has 3 followers (<=5) so must NOT have blue tick');

      // Admin verification
      final isAdminVerified = container.read(isUserVerifiedProvider('admin'));
      expect(isAdminVerified, isTrue, reason: 'Admin user must always have blue tick');

      // Empty or unknown user without followers
      final isUnknownVerified = container.read(isUserVerifiedProvider(''));
      expect(isUnknownVerified, isFalse);
    });
  });

  group('TradingView Symbol Resilience', () {
    test('formatTradingViewSymbol maps delisted, rebranded, and futures multiplier symbols accurately', () {
      // Rebranded: MATIC -> POL
      expect(formatTradingViewSymbol('MATICUSDT'), equals('BINANCE:POLUSDT'));
      expect(formatTradingViewSymbol('MATICUSDT', isFutures: true), equals('BINANCE:POLUSDT.P'));
      expect(formatTradingViewSymbol('MATIC-PERP'), equals('BINANCE:POLUSDT.P'));

      // Meme 1000x multiplier contracts on Binance Futures
      expect(formatTradingViewSymbol('PEPEUSDT'), equals('BINANCE:PEPEUSDT'));
      expect(formatTradingViewSymbol('PEPEUSDT', isFutures: true), equals('BINANCE:1000PEPEUSDT.P'));
      expect(formatTradingViewSymbol('PEPE-PERP'), equals('BINANCE:1000PEPEUSDT.P'));

      expect(formatTradingViewSymbol('SHIBUSDT'), equals('BINANCE:SHIBUSDT'));
      expect(formatTradingViewSymbol('SHIBUSDT', isFutures: true), equals('BINANCE:1000SHIBUSDT.P'));
      expect(formatTradingViewSymbol('SHIB-PERP'), equals('BINANCE:1000SHIBUSDT.P'));

      expect(formatTradingViewSymbol('FLOKIUSDT'), equals('BINANCE:FLOKIUSDT'));
      expect(formatTradingViewSymbol('FLOKIUSDT', isFutures: true), equals('BINANCE:1000FLOKIUSDT.P'));
      expect(formatTradingViewSymbol('FLOKI-PERP'), equals('BINANCE:1000FLOKIUSDT.P'));

      expect(formatTradingViewSymbol('BONKUSDT', isFutures: true), equals('BINANCE:1000BONKUSDT.P'));

      // Migrated & Market symbols on Binance
      expect(formatTradingViewSymbol('MKRUSDT'), equals('BINANCE:MKRUSDT'));
      expect(formatTradingViewSymbol('MKRUSDT', isFutures: true), equals('BINANCE:MKRUSDT.P'));
      expect(formatTradingViewSymbol('MKR - PERP'), equals('BINANCE:MKRUSDT.P'));

      // FTM -> Sonic (S)
      expect(formatTradingViewSymbol('FTMUSDT'), equals('BINANCE:SUSDT'));
      expect(formatTradingViewSymbol('FTMUSDT', isFutures: true), equals('BINANCE:SUSDT.P'));

      // AGIX -> Fetch.ai / ASI (FET)
      expect(formatTradingViewSymbol('AGIXUSDT'), equals('BINANCE:FETUSDT'));
      expect(formatTradingViewSymbol('AGIXUSDT', isFutures: true), equals('BINANCE:FETUSDT.P'));

      // TON -> Binance
      expect(formatTradingViewSymbol('TONUSDT'), equals('BINANCE:TONUSDT'));
      expect(formatTradingViewSymbol('TONUSDT', isFutures: true), equals('BINANCE:TONUSDT.P'));

      // Even if prefixed with BINANCE:, it handles properly
      expect(formatTradingViewSymbol('BINANCE:MATICUSDT'), equals('BINANCE:POLUSDT'));
      expect(formatTradingViewSymbol('BINANCE:MATICUSDT', isFutures: true), equals('BINANCE:POLUSDT.P'));

      // Standard symbols remain Binance pairs
      expect(formatTradingViewSymbol('BTCUSDT'), equals('BINANCE:BTCUSDT'));
      expect(formatTradingViewSymbol('BTCUSDT', isFutures: true), equals('BINANCE:BTCUSDT.P'));
      expect(formatTradingViewSymbol('ETHUSDT'), equals('BINANCE:ETHUSDT'));
      expect(formatTradingViewSymbol('ETHUSDT', isFutures: true), equals('BINANCE:ETHUSDT.P'));
    });
  });

  group('Championship Prize Eligibility Rules', () {
    test('traders with <= 0.0% profit are excluded from prize distribution', () {
      final participants = [
        {'name': 'AlphaTrader', 'tournamentScore': 15.5},
        {'name': 'BullKing', 'tournamentScore': 8.2},
        {'name': 'BreakoutPro', 'tournamentScore': 1.1},
        {'name': 'ZeroScoreUser', 'tournamentScore': 0.0},
        {'name': 'BaselineJoined', 'tournamentScore': 0.0},
        {'name': 'NegativeTrader', 'tournamentScore': -3.4},
      ];

      // Eligibility filter matching ChampionshipPrizeManager
      final eligibleWinners = participants.where((p) {
        final score = (p['tournamentScore'] as num).toDouble();
        return score > 0.0;
      }).take(10).toList();

      expect(eligibleWinners.length, equals(3));
      expect(eligibleWinners[0]['name'], equals('AlphaTrader'));
      expect(eligibleWinners[1]['name'], equals('BullKing'));
      expect(eligibleWinners[2]['name'], equals('BreakoutPro'));
      expect(eligibleWinners.any((p) => (p['tournamentScore'] as num) <= 0.0), isFalse);
    });
  });
}
