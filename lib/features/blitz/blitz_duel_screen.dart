import 'dart:async';
import 'dart:math';
import '../../core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/coin_icon.dart';
import '../../data/market_provider.dart';
import '../../data/models.dart';
import '../../data/user_provider.dart';

class BlitzDuelScreen extends ConsumerStatefulWidget {
  const BlitzDuelScreen({super.key});

  @override
  ConsumerState<BlitzDuelScreen> createState() => _BlitzDuelScreenState();
}

class _BlitzDuelScreenState extends ConsumerState<BlitzDuelScreen> with TickerProviderStateMixin {
  // Matchmaking State
  bool _isSearching = true;
  bool _battleEnded = false;

  // Opponent Details
  late String _opponentName;
  late int _opponentRating;
  late String _opponentAvatar;

  // Match Mechanics
  int _secondsRemaining = 180;
  Timer? _gameTimer;
  Timer? _priceTickTimer;
  Timer? _botTradeTimer;

  // Player Capital & Position
  final double _initialBalance = 10000.0;
  double _playerCash = 10000.0;
  double _playerAssetQty = 0.0;
  double _playerEntryPrice = 0.0;
  OrderSide? _playerSide; // buy = long, sell = short
  String _playerPositionSymbol = 'BTC';
  double _selectedAllocPct = 1.0; // 25%, 50%, 75%, 100%
  int _playerTradeCount = 0;

  // Live Match Activity Log
  final List<String> _matchLogs = [];
  bool _showLogView = false;

  String _formatTime() {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Bot Capital & Position
  double _botCash = 10000.0;
  double _botAssetQty = 0.0;
  double _botEntryPrice = 0.0;
  OrderSide? _botSide;

  // Multi-Asset Live State
  String _activeSymbol = 'BTC';
  final Map<String, double> _livePrices = {
    'BTC': 7500000.0,
    'ETH': 280000.0,
    'SOL': 14500.0,
  };
  final Map<String, List<double>> _priceHistories = {
    'BTC': [],
    'ETH': [],
    'SOL': [],
  };

  // Animations
  late AnimationController _radarController;

  static const List<Map<String, String>> botProfiles = [
    {'name': 'CryptoNinja_99', 'rating': '1040', 'avatar': '🥷'},
    {'name': 'Satoshi_Bull', 'rating': '1120', 'avatar': '🐂'},
    {'name': 'AlphaTrader', 'rating': '980', 'avatar': '⚡'},
    {'name': 'MoonChaser', 'rating': '1080', 'avatar': '🚀'},
    {'name': 'Viper_Trades', 'rating': '1010', 'avatar': '🐍'},
    {'name': 'HodlQueen', 'rating': '1150', 'avatar': '👑'},
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Random Bot Matchmaking
    final bot = botProfiles[Random().nextInt(botProfiles.length)];
    _opponentName = bot['name']!;
    _opponentRating = int.parse(bot['rating']!);
    _opponentAvatar = bot['avatar']!;

    // 3-second Radar Search
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _initMarketPrices();
        setState(() {
          _isSearching = false;
        });
        _startBattle();
      }
    });
  }

  void _initMarketPrices() {
    final market = ref.read(marketProvider);
    final rnd = Random();

    for (final key in _livePrices.keys) {
      Stock? stock;
      for (final s in market) {
        if (s.symbol == key) {
          stock = s;
          break;
        }
      }

      if (stock != null && stock.currentPrice > 0) {
        _livePrices[key] = stock.currentPrice;
      }

      final base = _livePrices[key]!;

      if (stock != null && stock.history.isNotEmpty) {
        final historyLength = stock.history.length;
        final startIdx = max(0, historyLength - 35);
        final realHistory = stock.history.sublist(startIdx);
        if (realHistory.length >= 5) {
          _priceHistories[key] = List<double>.from(realHistory);
          continue;
        }
      }

      _priceHistories[key] = _generateRealisticHistory(base, 35, rnd);
    }
  }

  List<double> _generateRealisticHistory(double currentPrice, int count, Random rnd) {
    final points = <double>[currentPrice];
    double p = currentPrice;
    double momentum = 0.0;
    for (int i = 0; i < count - 1; i++) {
      momentum = (momentum * 0.7) + ((rnd.nextDouble() - 0.498) * 0.002);
      p = p / (1 + momentum);
      points.insert(0, p);
    }
    return points;
  }

  void _startBattle() {
    final capStr = AppCurrencyFormatter(ref.read(userProvider).profile.preferredCurrency, decimalDigits: 0).format(10000);
    _matchLogs.add('[${_formatTime()}] ⚔️ 1v1 Blitz Duel Started! Both traders initialized with $capStr capital.');

    // 1-second Match Timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        _endBattle();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });

    // 500ms Volatile Price Simulation across assets
    final rnd = Random();
    _priceTickTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _battleEnded) return;

      for (final key in _livePrices.keys) {
        final currentP = _livePrices[key]!;
        final pctChange = (rnd.nextDouble() - 0.495) * 0.005;
        final newP = currentP * (1 + pctChange);
        _livePrices[key] = newP;

        final history = _priceHistories[key]!;
        history.add(newP);
        if (history.length > 50) history.removeAt(0);
      }
      setState(() {});
    });

    // Bot Trading AI logic
    _botTradeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _battleEnded) return;
      _executeBotAI();
    });
  }

  void _executeBotAI() {
    final rnd = Random();
    final formatter = AppCurrencyFormatter(ref.read(userProvider).profile.preferredCurrency);
    if (_botSide == null) {
      final side = rnd.nextBool() ? OrderSide.buy : OrderSide.sell;
      final price = _livePrices['BTC']!;
      _botSide = side;
      _botEntryPrice = price;
      _botAssetQty = (_botCash * 0.9) / price;
      _botCash -= _botAssetQty * price;
      _matchLogs.add('[${_formatTime()}] 🤖 $_opponentName opened BTC ${side == OrderSide.buy ? "LONG" : "SHORT"} 10x @ ${formatter.format(price)}');
    } else {
      if (rnd.nextDouble() < 0.4) {
        _closeBotPosition();
      }
    }
    setState(() {});
  }

  void _closeBotPosition() {
    if (_botSide == null) return;
    final price = _livePrices['BTC']!;
    final isLong = _botSide == OrderSide.buy;
    final diff = price - _botEntryPrice;
    final pnl = (isLong ? diff * _botAssetQty : -diff * _botAssetQty) * 10; // 10x leverage
    _botCash += (_botAssetQty * _botEntryPrice) + pnl;
    _botSide = null;
    _botAssetQty = 0;
    _botEntryPrice = 0;
    _matchLogs.add('[${_formatTime()}] 🤖 $_opponentName closed BTC position');
  }

  void _executePlayerTrade(OrderSide side) {
    if (_playerSide != null) return;
    final price = _livePrices[_activeSymbol]!;
    final allocCash = _playerCash * _selectedAllocPct;
    final formatter = AppCurrencyFormatter(ref.read(userProvider).profile.preferredCurrency);

    setState(() {
      _playerSide = side;
      _playerPositionSymbol = _activeSymbol;
      _playerEntryPrice = price;
      _playerAssetQty = (allocCash * 0.98) / price;
      _playerCash -= allocCash;
      _playerTradeCount++;
      _matchLogs.add('[${_formatTime()}] 🟢 YOU opened $_activeSymbol ${side == OrderSide.buy ? "LONG" : "SHORT"} 10x @ ${formatter.format(price)}');
    });
  }

  void _closePlayerPosition() {
    if (_playerSide == null) return;
    final price = _livePrices[_playerPositionSymbol]!;
    final isLong = _playerSide == OrderSide.buy;
    final diff = price - _playerEntryPrice;
    final pnl = (isLong ? diff * _playerAssetQty : -diff * _playerAssetQty) * 10; // 10x leverage
    final formatter = AppCurrencyFormatter(ref.read(userProvider).profile.preferredCurrency);
    final pnlStr = '${pnl >= 0 ? "+" : ""}${formatter.format(pnl)}';

    setState(() {
      _playerCash += (_playerAssetQty * _playerEntryPrice) + pnl;
      _playerSide = null;
      _playerAssetQty = 0;
      _playerEntryPrice = 0;
      _matchLogs.add('[${_formatTime()}] 🔴 YOU closed $_playerPositionSymbol position ($pnlStr P&L)');
    });
  }

  double get _playerCurrentPnl {
    if (_playerSide == null) return 0.0;
    final price = _livePrices[_playerPositionSymbol]!;
    final isLong = _playerSide == OrderSide.buy;
    final diff = price - _playerEntryPrice;
    return (isLong ? diff * _playerAssetQty : -diff * _playerAssetQty) * 10;
  }

  double get _playerTotalWorth => _playerCash + (_playerAssetQty * _playerEntryPrice) + _playerCurrentPnl;

  double get _botTotalWorth {
    if (_botSide == null) return _botCash;
    final price = _livePrices['BTC']!;
    final isLong = _botSide == OrderSide.buy;
    final diff = price - _botEntryPrice;
    final pnl = (isLong ? diff * _botAssetQty : -diff * _botAssetQty) * 10;
    return _botCash + (_botAssetQty * _botEntryPrice) + pnl;
  }

  double get _playerRoi => ((_playerTotalWorth - _initialBalance) / _initialBalance) * 100;
  double get _botRoi => ((_botTotalWorth - _initialBalance) / _initialBalance) * 100;

  void _endBattle({bool isSurrender = false}) {
    _gameTimer?.cancel();
    _priceTickTimer?.cancel();
    _botTradeTimer?.cancel();

    if (_battleEnded) return;
    setState(() {
      _battleEnded = true;
    });

    final isInactive = _playerTradeCount == 0;
    final won = (isSurrender || isInactive) ? false : (_playerRoi > _botRoi);
    final eloDelta = won ? 25 : (isInactive ? -25 : -20);
    final xpGain = won ? 150 : (isInactive ? 0 : 25);

    ref.read(userProvider.notifier).recordBlitzResult(
      won: won,
      eloDelta: eloDelta,
      xpGain: xpGain,
      matchRoi: _playerRoi,
    );

    _showResultDialog(won, eloDelta, xpGain, isSurrender: isSurrender, isInactive: isInactive);
  }

  void _showResultDialog(bool won, int eloDelta, int xpGain, {bool isSurrender = false, bool isInactive = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: won ? AppColors.profit : AppColors.loss, width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (won ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(won ? '🏆' : (isInactive ? '⏱️' : '💀'), style: const TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 12),
            Text(
              won ? 'VICTORY!' : (isSurrender ? 'FORFEIT' : (isInactive ? 'INACTIVITY LOSS' : 'DEFEAT')),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: won ? AppColors.profit : AppColors.loss,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // Score Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('YOU', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${_playerRoi >= 0 ? '+' : ''}${_playerRoi.toStringAsFixed(2)}%',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _playerRoi >= 0 ? AppColors.profit : AppColors.loss),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 30, width: 1, color: AppColors.outline),
                  Expanded(
                    child: Column(
                      children: [
                        Text(_opponentName, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          '${_botRoi >= 0 ? '+' : ''}${_botRoi.toStringAsFixed(2)}%',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _botRoi >= 0 ? AppColors.profit : AppColors.loss),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rewards Earned
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRewardChip('RATING', '${eloDelta >= 0 ? "+" : ""}$eloDelta', eloDelta >= 0 ? AppColors.primary : AppColors.loss),
                _buildRewardChip('XP', '+$xpGain XP', Colors.amberAccent),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardChip(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(color: col, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildMiniStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final market = ref.watch(marketProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency);

    final activePrice = _livePrices[_activeSymbol] ?? 100.0;
    final activeHistory = _priceHistories[_activeSymbol] ?? [100.0, 100.0];

    // Find active stock for market stats
    Stock? activeStock;
    for (final s in market) {
      if (s.symbol == _activeSymbol) {
        activeStock = s;
        break;
      }
    }

    final totalScore = (_playerRoi.abs() + _botRoi.abs());
    final tugProgress = totalScore == 0 ? 0.5 : (0.5 + ((_playerRoi - _botRoi) / 100).clamp(-0.45, 0.45));

    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isWarningTime = _secondsRemaining <= 30;

    if (_isSearching) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                  CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.radar, color: AppColors.primary, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('MATCHMAKING...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('Finding rival near ${userState.profile.blitzRating} ELO', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _endBattle(isSurrender: true);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => _endBattle(isSurrender: true),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.redAccent, size: 14),
                    SizedBox(width: 4),
                    Text('1V1 DUEL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isWarningTime ? Colors.redAccent : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isWarningTime ? Colors.transparent : AppColors.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: isWarningTime ? Colors.white : AppColors.textPrimary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$minutes:$seconds',
                      style: TextStyle(
                        color: isWarningTime ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── DUAL SCOREBOARD HEADER WITH NET WORTH & TRADE STATUS ─────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                color: AppColors.surface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Player (You)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('YOU', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text('${userState.profile.blitzRating}', style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _playerTradeCount > 0 ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _playerTradeCount > 0 ? '$_playerTradeCount Trade${_playerTradeCount > 1 ? "s" : ""}' : '0 Trades',
                                      style: TextStyle(
                                        color: _playerTradeCount > 0 ? Colors.greenAccent : Colors.amberAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${_playerRoi >= 0 ? '+' : ''}${_playerRoi.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: _playerRoi >= 0 ? AppColors.profit : AppColors.loss,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formatter.format(_playerTotalWorth),
                                    style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Opponent (Rival)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(_opponentAvatar, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text('$_opponentName ($_opponentRating)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    formatter.format(_botTotalWorth),
                                    style: TextStyle(color: AppColors.subtle, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_botRoi >= 0 ? '+' : ''}${_botRoi.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: _botRoi >= 0 ? AppColors.profit : AppColors.loss,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: tugProgress,
                        minHeight: 6,
                        backgroundColor: AppColors.loss.withValues(alpha: 0.6),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _playerRoi >= _botRoi ? AppColors.profit : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── ASSET SELECTOR & DETAILED MARKET STATS HEADER ──────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Coin Switcher Tabs
                        Row(
                          children: ['BTC', 'ETH', 'SOL'].map((sym) {
                            final isActive = _activeSymbol == sym;
                            return GestureDetector(
                              onTap: () => setState(() => _activeSymbol = sym),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isActive ? AppColors.primary : AppColors.outline),
                                ),
                                child: Row(
                                  children: [
                                    CoinIcon(symbol: sym, size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      sym,
                                      style: TextStyle(
                                        color: isActive ? AppColors.primary : AppColors.textSecondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        // Ticking Live Price & 24h Change
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatter.format(activePrice),
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            if (activeStock != null)
                              Text(
                                '${activeStock.changePercentage >= 0 ? "+" : ""}${activeStock.changePercentage.toStringAsFixed(2)}% 24h',
                                style: TextStyle(
                                  color: activeStock.changePercentage >= 0 ? AppColors.profit : AppColors.loss,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Detailed Market Stats Pill Bar
                    if (activeStock != null)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildMiniStatChip('24h High', formatter.format(activeStock.dayHigh)),
                            const SizedBox(width: 6),
                            _buildMiniStatChip('24h Low', formatter.format(activeStock.dayLow)),
                            const SizedBox(width: 6),
                            _buildMiniStatChip('Leverage', '10x Cross'),
                            const SizedBox(width: 6),
                            _buildMiniStatChip('Mode', 'Volatile Tick'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── PRO AREA CHART WITH GRID & TOGGLEABLE MATCH LOG ────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(
                      children: [
                        // View Switcher Header (Chart vs Match Feed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _showLogView = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: !_showLogView ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: !_showLogView ? AppColors.primary : Colors.transparent),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.show_chart, size: 13, color: !_showLogView ? AppColors.primary : AppColors.subtle),
                                      const SizedBox(width: 4),
                                      Text('Price Chart', style: TextStyle(color: !_showLogView ? AppColors.primary : AppColors.subtle, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _showLogView = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _showLogView ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _showLogView ? AppColors.primary : Colors.transparent),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.receipt_long, size: 13, color: _showLogView ? AppColors.primary : AppColors.subtle),
                                      const SizedBox(width: 4),
                                      Text('Match Feed (${_matchLogs.length})', style: TextStyle(color: _showLogView ? AppColors.primary : AppColors.subtle, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.sensors, color: Colors.greenAccent, size: 11),
                                    SizedBox(width: 4),
                                    Text('LIVE TICK', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: AppColors.outline),
                        Expanded(
                          child: _showLogView
                              ? ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _matchLogs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (ctx, idx) {
                                    final log = _matchLogs[_matchLogs.length - 1 - idx];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                                      child: Text(log, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'monospace')),
                                    );
                                  },
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _ProAreaChartPainter(
                                      prices: activeHistory,
                                      entryPrice: _playerPositionSymbol == _activeSymbol ? _playerEntryPrice : 0.0,
                                      isLong: _playerSide == OrderSide.buy,
                                      formatter: formatter,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── ACTIVE POSITION CARD WITH REAL-TIME P&L DETAILS ───────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _playerSide == null
                        ? AppColors.surfaceAlt
                        : (_playerSide == OrderSide.buy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _playerSide == null
                          ? AppColors.outline
                          : (_playerSide == OrderSide.buy ? AppColors.profit : AppColors.loss).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _playerSide == null
                                  ? (_playerTradeCount == 0 ? '⚠️ NO TRADES PLACED • Place at least 1 trade to avoid loss' : 'NO OPEN POSITION')
                                  : '$_playerPositionSymbol ${_playerSide == OrderSide.buy ? "LONG 10x" : "SHORT 10x"} @ ${formatter.format(_playerEntryPrice)}',
                              style: TextStyle(
                                color: _playerSide == null
                                    ? (_playerTradeCount == 0 ? Colors.amberAccent : AppColors.subtle)
                                    : (_playerSide == OrderSide.buy ? AppColors.profit : AppColors.loss),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_playerSide != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'P&L: ${_playerCurrentPnl >= 0 ? '+' : ''}${formatter.format(_playerCurrentPnl)}',
                                    style: TextStyle(
                                      color: _playerCurrentPnl >= 0 ? AppColors.profit : AppColors.loss,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${_playerCurrentPnl >= 0 ? "+" : ""}${((_playerCurrentPnl / (_playerAssetQty * _playerEntryPrice / 10)) * 100).toStringAsFixed(2)}%)',
                                    style: TextStyle(
                                      color: _playerCurrentPnl >= 0 ? AppColors.profit : AppColors.loss,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_playerSide != null)
                        GestureDetector(
                          onTap: _closePlayerPosition,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                            ),
                            child: const Text('CLOSE POSITION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── POSITION ALLOCATION & MARGIN PREVIEW CHIPS ────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('CAPITAL: ${formatter.format(_playerCash)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('SIZE:', style: TextStyle(color: AppColors.subtle, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    ...[0.25, 0.50, 0.75, 1.0].map((pct) {
                      final isSel = _selectedAllocPct == pct;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAllocPct = pct),
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.surfaceAlt : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isSel ? AppColors.primary : AppColors.outline),
                          ),
                          child: Text(
                            '${(pct * 100).toInt()}%',
                            style: TextStyle(color: isSel ? AppColors.primary : AppColors.subtle, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // ── ACTION BUTTONS TERMINAL ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _playerSide == null ? () => _executePlayerTrade(OrderSide.sell) : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: AppColors.loss,
                          side: const BorderSide(color: AppColors.loss, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppColors.loss.withValues(alpha: 0.1),
                        ),
                        child: Column(
                          children: [
                            const Text('SHORT (SELL)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            Text('Margin ${formatter.format(_playerCash * _selectedAllocPct)} • 10x', style: TextStyle(fontSize: 9, color: AppColors.subtle)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _playerSide == null ? () => _executePlayerTrade(OrderSide.buy) : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.profit,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Column(
                          children: [
                            const Text('LONG (BUY)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                            Text('Margin ${formatter.format(_playerCash * _selectedAllocPct)} • 10x', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProAreaChartPainter extends CustomPainter {
  final List<double> prices;
  final double entryPrice;
  final bool isLong;
  final AppCurrencyFormatter formatter;

  _ProAreaChartPainter({
    required this.prices,
    required this.entryPrice,
    required this.isLong,
    required this.formatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minP = prices.reduce(min);
    final maxP = prices.reduce(max);
    final rawRange = maxP - minP;
    final minRange = (prices.last * 0.003);
    final range = rawRange < minRange ? minRange : rawRange;
    final midP = (maxP + minP) / 2;
    final effectiveMin = rawRange < minRange ? (midP - range / 2) : minP;

    final isUp = prices.last >= prices.first;
    final strokeColor = isUp ? AppColors.profit : AppColors.loss;

    // Horizontal background grid lines & Y-axis price labels
    final gridPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: AppColors.subtle,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    for (int step = 1; step <= 3; step++) {
      final gridY = (size.height / 4) * step;
      canvas.drawLine(Offset(0, gridY), Offset(size.width, gridY), gridPaint);

      final priceAtLevel = (effectiveMin + range) - (range * (step / 4));
      final textSpan = TextSpan(text: formatter.format(priceAtLevel), style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 4, gridY - textPainter.height - 2));
    }

    // Gradient area beneath the line
    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = (i / (prices.length - 1)) * size.width;
      final y = size.height - ((prices[i] - effectiveMin) / range) * (size.height - 30) - 15;

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (prices.length - 1)) * size.width;
        final prevY = size.height - ((prices[i - 1] - effectiveMin) / range) * (size.height - 30) - 15;
        final cpX = (prevX + x) / 2;
        linePath.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }

      if (i == prices.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    // Paint Gradient Fill
    final fillGradient = LinearGradient(
      colors: [strokeColor.withValues(alpha: 0.35), strokeColor.withValues(alpha: 0.0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Paint Glowing Main Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = strokeColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // If active position exists, draw dashed horizontal entry price line
    if (entryPrice > 0 && entryPrice >= effectiveMin && entryPrice <= (effectiveMin + range)) {
      final entryY = size.height - ((entryPrice - effectiveMin) / range) * (size.height - 30) - 15;
      final entryPaint = Paint()
        ..color = (isLong ? AppColors.profit : AppColors.loss).withValues(alpha: 0.7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      double dashX = 0;
      while (dashX < size.width) {
        canvas.drawLine(Offset(dashX, entryY), Offset(dashX + 5, entryY), entryPaint);
        dashX += 9;
      }
    }

    // Pulsing price dot at current head
    final lastX = size.width;
    final lastY = size.height - ((prices.last - effectiveMin) / range) * (size.height - 30) - 15;
    canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = strokeColor);
    canvas.drawCircle(Offset(lastX, lastY), 10, Paint()..color = strokeColor.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(_ProAreaChartPainter oldDelegate) => true;
}
