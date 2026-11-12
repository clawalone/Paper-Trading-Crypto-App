import 'package:flutter_test/flutter_test.dart';
import 'package:stock_arena/core/portfolio_audit_engine.dart';
import 'package:stock_arena/data/models.dart';
import 'package:stock_arena/data/user_provider.dart';

void main() {
  final List<Stock> sampleMarket = [
    const Stock(
      symbol: 'BTCUSDT',
      name: 'Bitcoin',
      category: 'Crypto',
      currentPrice: 65000.0,
      previousClose: 64000.0,
      dayHigh: 66000.0,
      dayLow: 63500.0,
      volume: 1000000,
      history: [],
      candleHistory: [],
      about: 'Bitcoin',
      supply: 21000000.0,
      rank: 1,
      isLive: true,
    ),
    const Stock(
      symbol: 'ETHUSDT',
      name: 'Ethereum',
      category: 'Crypto',
      currentPrice: 3500.0,
      previousClose: 3400.0,
      dayHigh: 3550.0,
      dayLow: 3380.0,
      volume: 500000,
      history: [],
      candleHistory: [],
      about: 'Ethereum',
      supply: 120000000.0,
      rank: 2,
      isLive: true,
    ),
  ];

  group('PortfolioAuditEngine Tests', () {
    test('Clean user with no trades and standard initial capital (\$5000) is CLEAN', () async {
      final rawData = {
        'profile': {
          'name': 'Honest Trader',
          'publicUid': 'PT-111111',
          'virtualBalance': 5000.0,
          'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        },
        'walletEntries': <Map<String, dynamic>>[],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Honest Trader', experienceLevel: 'Beginner', virtualBalance: 5000, xp: 50, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [],
        trades: const [],
        futuresPositions: const [],
        spotLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_1',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.clean);
      expect(result.criticalFlags, isEmpty);
      expect(result.cashDiscrepancy, 0.0);
    });

    test('Cheater with direct Balance Injection (Ghost Cash) is detected', () async {
      final rawData = {
        'profile': {
          'name': 'Hacker',
          'publicUid': 'PT-999999',
          'virtualBalance': 500000.0,
        },
        'walletEntries': <Map<String, dynamic>>[],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Hacker', experienceLevel: 'Beginner', virtualBalance: 500000, xp: 50, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [],
        trades: const [],
        futuresPositions: const [],
        spotLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_cheater_cash',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.cheaterConfirmed);
      expect(result.criticalFlags.any((f) => f.contains('balance injection')), isTrue);
      expect(result.prefilledBanReason, contains('balance injection'));
    });

    test('Cheater with Ghost Holdings (Holds coins never bought) is detected', () async {
      final rawData = {
        'profile': {
          'name': 'Ghost Crypto Holder',
          'publicUid': 'PT-888888',
          'virtualBalance': 5000.0,
        },
        'walletEntries': <Map<String, dynamic>>[],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Ghost Crypto Holder', experienceLevel: 'Beginner', virtualBalance: 5000, xp: 50, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [
          Holding(symbol: 'BTCUSDT', quantity: 10, averagePrice: 60000.0),
        ],
        trades: [
          Trade(
            symbol: 'BTCUSDT',
            side: OrderSide.buy,
            quantity: 1,
            price: 60000.0,
            time: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
        futuresPositions: const [],
        spotLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_ghost_holding',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.cheaterConfirmed);
      expect(result.criticalFlags.any((f) => f.contains('Ghost holdings')), isTrue);
      expect(result.holdingDetails['BTCUSDT']!.isGhost, isTrue);
      expect(result.holdingDetails['BTCUSDT']!.expectedQty, 1);
      expect(result.holdingDetails['BTCUSDT']!.statedQuantity, 10);
    });

    test('Trader who got LUCKY with 100x leverage is classified as LEGITIMATE (NOT CHEATING)', () async {
      final rawData = {
        'profile': {
          'name': 'Degen Trader',
          'publicUid': 'PT-100X',
          'virtualBalance': 4940.0, // 5000 - 60 margin
        },
        'walletEntries': [
          {
            'title': 'Futures Margin Deducted',
            'subtitle': 'BTCUSDT Long 100x',
            'amount': 60.0,
            'type': 'debit',
            'category': 'futures_open',
            'timestamp': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          },
        ],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Degen Trader', experienceLevel: 'Pro', virtualBalance: 4940, xp: 500, streak: 5, watchlist: {}),
        missions: const [],
        holdings: const [],
        trades: const [],
        futuresPositions: const [
          FuturesPosition(
            id: 'pos_100x',
            symbol: 'BTCUSDT',
            side: OrderSide.buy,
            leverage: 100,
            entryPrice: 60000.0,
            quantity: 0.1,
            margin: 60.0,
          ),
        ],
        spotLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_100x_lucky',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.highLeverageLucky);
      expect(result.hasHighLeverage, isTrue);
      expect(result.isLeverageLegitimate, isTrue);
      expect(result.criticalFlags, isEmpty);
      expect(result.verdictTitle, contains('LEGITIMATE HIGH-LEVERAGE TRADER (NOT CHEATING)'));
    });

    test('Zero-margin exploit on 100x leverage is flagged as CHEATING', () async {
      final rawData = {
        'profile': {
          'name': 'Bug Exploiter',
          'publicUid': 'PT-BUG',
          'virtualBalance': 5000.0,
        },
        'walletEntries': <Map<String, dynamic>>[],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Bug Exploiter', experienceLevel: 'Pro', virtualBalance: 5000, xp: 100, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [],
        trades: const [],
        futuresPositions: const [
          FuturesPosition(
            id: 'pos_bug',
            symbol: 'BTCUSDT',
            side: OrderSide.buy,
            leverage: 100,
            entryPrice: 60000.0,
            quantity: 10.0,
            margin: 0.0, // Exploit!
          ),
        ],
        spotLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_zero_margin',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.cheaterConfirmed);
      expect(result.criticalFlags.any((f) => f.contains('Zero-margin')), isTrue);
    });

    test('Chronological Overdraft (Buying with money never had) is flagged', () async {
      final rawData = {
        'profile': {
          'name': 'Overdraft Exploiter',
          'publicUid': 'PT-OVERDRAFT',
          'virtualBalance': -45000.0,
        },
        'walletEntries': <Map<String, dynamic>>[],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Overdraft Exploiter', experienceLevel: 'Beginner', virtualBalance: -45000, xp: 100, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [
          Holding(symbol: 'BTCUSDT', quantity: 1, averagePrice: 50000.0),
        ],
        trades: [
          Trade(
            symbol: 'BTCUSDT',
            side: OrderSide.buy,
            quantity: 1,
            price: 50000.0,
            time: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
        futuresPositions: const [],
        spotLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_overdraft',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.cheaterConfirmed);
      expect(result.criticalFlags.any((f) => f.contains('overdraft')), isTrue);
    });

    test('Cheater with manipulated futures limit entry price (e.g. BTC @ \$2000) is flagged', () async {
      final rawData = {
        'profile': {
          'name': 'Glitched Entry Exploiter',
          'publicUid': 'PT-174491',
          'virtualBalance': 10000.0,
        },
        'walletEntries': <Map<String, dynamic>>[],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Glitched Entry Exploiter', experienceLevel: 'Beginner', virtualBalance: 10000, xp: 100, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [],
        trades: const [],
        futuresPositions: const [
          FuturesPosition(
            id: 'pos_glitched',
            symbol: 'BTCUSDT',
            side: OrderSide.buy,
            leverage: 2,
            entryPrice: 2000.0,
            quantity: 2000.0,
            margin: 2000000.0,
          ),
        ],
        spotLimitOrders: const [],
        futuresLimitOrders: const [],
        walletEntries: const [],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_glitched_entry',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.cheaterConfirmed);
      expect(result.criticalFlags.any((f) => f.contains('Manipulated futures entry price')), isTrue);
    });

    test('Cheater with impossible windfall futures PnL exploit is flagged', () async {
      final rawData = {
        'profile': {
          'name': 'Windfall Exploiter',
          'publicUid': 'PT-WINDFALL',
          'virtualBalance': 76000000.0,
        },
        'walletEntries': <Map<String, dynamic>>[
          {
            'amount': 76410830.0,
            'subtitle': 'BTC Long 2x • PnL: +\$76,410,830.00',
            'type': 'credit',
            'category': 'futures_pnl',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          },
        ],
      };

      final parsed = UserState(
        isOnboarded: true,
        profile: const UserProfile(name: 'Windfall Exploiter', experienceLevel: 'Beginner', virtualBalance: 76000000, xp: 100, streak: 1, watchlist: {}),
        missions: const [],
        holdings: const [],
        trades: const [],
        futuresPositions: const [],
        spotLimitOrders: const [],
        futuresLimitOrders: const [],
        walletEntries: [
          {
            'amount': 76410830.0,
            'subtitle': 'BTC Long 2x • PnL: +\$76,410,830.00',
            'type': 'credit',
            'category': 'futures_pnl',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          },
        ],
      );

      final result = await PortfolioAuditEngine.auditUser(
        userDocId: 'user_windfall',
        rawUserData: rawData,
        parsedUserState: parsed,
        market: sampleMarket,
      );

      expect(result.verdict, AuditVerdict.cheaterConfirmed);
      expect(result.criticalFlags.any((f) => f.contains('Impossible futures PnL exploit')), isTrue);
    });
  });
}
