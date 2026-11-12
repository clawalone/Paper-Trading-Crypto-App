import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/currency_formatters.dart';
import '../core/ban_manager.dart';
import '../core/app_translations.dart';
import 'models.dart';
import 'market_provider.dart';
import 'stock_market_provider.dart';

final userProvider = NotifierProvider<UserNotifier, UserState>(() {
  return UserNotifier();
});

class UserState {
  final bool isLoading;
  final bool isOnboarded;
  final bool hasSyncError;
  final UserProfile profile;
  final List<Holding> holdings;
  final List<Trade> trades;
  final List<Mission> missions;
  final List<FuturesPosition> futuresPositions;
  final List<Map<String, dynamic>> walletEntries;
  final List<SpotLimitOrder> spotLimitOrders;
  final List<FuturesLimitOrder> futuresLimitOrders;
  final List<AmoOrder> amoOrders;
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedAt;
  final DateTime? createdAt;

  const UserState({
    this.isLoading = false,
    required this.isOnboarded,
    this.hasSyncError = false,
    required this.profile,
    this.holdings = const [],
    this.trades = const [],
    required this.missions,
    this.futuresPositions = const [],
    this.walletEntries = const [],
    this.spotLimitOrders = const [],
    this.futuresLimitOrders = const [],
    this.amoOrders = const [],
    this.isBanned = false,
    this.banReason,
    this.bannedAt,
    this.createdAt,
  });

  UserState copyWith({
    bool? isLoading,
    bool? isOnboarded,
    bool? hasSyncError,
    UserProfile? profile,
    List<Holding>? holdings,
    List<Trade>? trades,
    List<Mission>? missions,
    List<FuturesPosition>? futuresPositions,
    List<Map<String, dynamic>>? walletEntries,
    List<SpotLimitOrder>? spotLimitOrders,
    List<FuturesLimitOrder>? futuresLimitOrders,
    List<AmoOrder>? amoOrders,
    bool? isBanned,
    String? banReason,
    DateTime? bannedAt,
    DateTime? createdAt,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      hasSyncError: hasSyncError ?? this.hasSyncError,
      profile: profile ?? this.profile,
      holdings: holdings ?? this.holdings,
      trades: trades ?? this.trades,
      missions: missions ?? this.missions,
      futuresPositions: futuresPositions ?? this.futuresPositions,
      walletEntries: walletEntries ?? this.walletEntries,
      spotLimitOrders: spotLimitOrders ?? this.spotLimitOrders,
      futuresLimitOrders: futuresLimitOrders ?? this.futuresLimitOrders,
      amoOrders: amoOrders ?? this.amoOrders,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      bannedAt: bannedAt ?? this.bannedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns unreserved holding quantity for [symbol], subtracting quantities
  /// locked in pending spot limit sell orders and queued 1x AMO sell orders.
  int availableHoldingQty(String symbol) {
    final idx = holdings.indexWhere((h) => h.symbol == symbol);
    if (idx < 0) return 0;
    final reservedLimit = spotLimitOrders
        .where((o) => o.symbol == symbol && o.side == OrderSide.sell && o.status == 'pending')
        .fold<int>(0, (total, o) => total + o.quantity);
    final reservedAmo = amoOrders
        .where((o) => o.symbol == symbol && o.side == OrderSide.sell && o.leverage == 1 && o.status == 'queued')
        .fold<int>(0, (total, o) => total + o.quantity);
    final avail = holdings[idx].quantity - reservedLimit - reservedAmo;
    return avail > 0 ? avail : 0;
  }

  DateTime _inferCreatedAt() {
    if (createdAt != null) return createdAt!;
    if (profile.streak > 1) {
      return DateTime.now().subtract(Duration(days: profile.streak));
    }
    if (trades.isNotEmpty) {
      DateTime earliest = trades.first.time;
      for (final t in trades) {
        if (t.time.isBefore(earliest)) earliest = t.time;
      }
      return earliest;
    }
    if (walletEntries.isNotEmpty) {
      DateTime? earliest;
      for (final e in walletEntries) {
        if (e['timestamp'] != null) {
          final d = DateTime.tryParse(e['timestamp'].toString());
          if (d != null && (earliest == null || d.isBefore(earliest))) {
            earliest = d;
          }
        }
      }
      if (earliest != null) return earliest;
    }
    if (profile.xp > 100) {
      return DateTime.now().subtract(const Duration(days: 14));
    }
    return DateTime(2026, 10, 15, 12, 0);
  }

  Map<String, dynamic> toJson() => {
    'isOnboarded': isOnboarded,
    'profile': profile.toJson(),
    'holdings': holdings.map((h) => h.toJson()).toList(),
    'trades': trades.map((t) => t.toJson()).toList(),
    'missions': missions.map((m) => m.toJson()).toList(),
    'futuresPositions': futuresPositions.map((f) => f.toJson()).toList(),
    'walletEntries': walletEntries,
    'spotLimitOrders': spotLimitOrders.map((o) => o.toJson()).toList(),
    'futuresLimitOrders': futuresLimitOrders.map((o) => o.toJson()).toList(),
    'amoOrders': amoOrders.map((o) => o.toJson()).toList(),
    'isBanned': isBanned || profile.isBanned,
    'banReason': banReason ?? profile.banReason,
    'bannedAt': bannedAt?.toIso8601String() ?? profile.bannedAt,
    'createdAt': (createdAt ?? _inferCreatedAt()).toIso8601String(),
  };

  factory UserState.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map<String, dynamic>?;
    final parsedProfile = profileJson != null
        ? UserProfile.fromJson(profileJson)
        : const UserProfile(name: 'Guest', experienceLevel: 'Beginner', virtualBalance: 0, xp: 0, streak: 1, watchlist: {});

    final storedMissions = (json['missions'] as List?)?.map((m) => Mission.fromJson(m)).toList() ?? [];
    final completedMissionIds = parsedProfile.completedMissions;
    final activeMissions = List<Mission>.from(storedMissions);

    // Auto-refill active missions if any missions were completed and new pool missions are available
    for (final poolM in UserNotifier.MISSION_POOL) {
      if (activeMissions.length >= 4) break;
      if (!completedMissionIds.contains(poolM.id) && !activeMissions.any((m) => m.id == poolM.id)) {
        activeMissions.add(poolM);
      }
    }
    final isBanned = (json['isBanned'] as bool?) ?? (profileJson?['isBanned'] as bool?) ?? false;
    final banReason = (json['banReason'] as String?) ?? (profileJson?['banReason'] as String?);
    DateTime? bannedAt;
    final rawBannedAt = json['bannedAt'] ?? profileJson?['bannedAt'];
    if (rawBannedAt != null) {
      if (rawBannedAt is Timestamp) {
        bannedAt = rawBannedAt.toDate();
      } else {
        bannedAt = DateTime.tryParse(rawBannedAt.toString());
      }
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        createdAt = (json['createdAt'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.tryParse(json['createdAt'].toString());
      }
    }

    return UserState(
      isLoading: false,
      isOnboarded: json['isOnboarded'] as bool? ?? false,
      hasSyncError: false,
      profile: parsedProfile.copyWith(
        isBanned: isBanned,
        banReason: banReason,
        bannedAt: bannedAt?.toIso8601String(),
      ),
      holdings: (json['holdings'] as List?)
              ?.map((h) => Holding.fromJson(h))
              .where((h) => !h.symbol.endsWith('.NS') && !h.symbol.endsWith('.BO'))
              .toList() ??
          [],
      trades: (json['trades'] as List?)?.map((t) => Trade.fromJson(t)).toList() ?? [],
      missions: activeMissions.isNotEmpty ? activeMissions : UserNotifier.MISSION_POOL.take(4).toList(),
      futuresPositions: (json['futuresPositions'] as List?)
              ?.map((f) => FuturesPosition.fromJson(f))
              .where((f) => !f.symbol.endsWith('.NS') && !f.symbol.endsWith('.BO'))
              .toList() ??
          [],
      walletEntries: (json['walletEntries'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      spotLimitOrders: (json['spotLimitOrders'] as List?)
              ?.map((o) => SpotLimitOrder.fromJson(o))
              .where((o) => !o.symbol.endsWith('.NS') && !o.symbol.endsWith('.BO'))
              .toList() ??
          [],
      futuresLimitOrders: (json['futuresLimitOrders'] as List?)
              ?.map((o) => FuturesLimitOrder.fromJson(o))
              .where((o) => !o.symbol.endsWith('.NS') && !o.symbol.endsWith('.BO'))
              .toList() ??
          [],
      amoOrders: (json['amoOrders'] as List?)
              ?.map((o) => AmoOrder.fromJson(o))
              .where((o) => !o.symbol.endsWith('.NS') && !o.symbol.endsWith('.BO'))
              .toList() ??
          [],
      isBanned: isBanned,
      banReason: banReason,
      bannedAt: bannedAt,
      createdAt: createdAt,
    );
  }

  bool get hasClaimedDaily {
    if (profile.lastDailyClaim == null || profile.lastDailyClaim!.isEmpty) return false;
    final lastClaim = DateTime.tryParse(profile.lastDailyClaim!);
    if (lastClaim == null) return false;
    final local = lastClaim.toLocal();
    final now = DateTime.now().toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }
}

class UserNotifier extends Notifier<UserState> {
  StreamSubscription? _sub;

  static const List<Mission> MISSION_POOL = [
    Mission(id: 'm1', title: 'Place your first virtual trade', reward: 100, target: 1),
    Mission(id: 'm2', title: 'Add 3 stocks to your watchlist', reward: 80, target: 3),
    Mission(id: 'm3', title: 'Finish the beginner quiz', reward: 120, target: 1),
    Mission(id: 'm4', title: 'Try both buy and sell orders', reward: 150, target: 2),
    Mission(id: 'm5', title: 'Make 5 total trades', reward: 200, target: 5),
    Mission(id: 'm6', title: 'Open your first futures position', reward: 200, target: 1),
    Mission(id: 'm7', title: 'Make 10 total trades', reward: 300, target: 10),
    Mission(id: 'm8', title: 'Add 5 stocks to your watchlist', reward: 150, target: 5),
    Mission(id: 'm9', title: 'Open 3 futures positions', reward: 400, target: 3),
    Mission(id: 'm10', title: 'Make 25 total trades', reward: 500, target: 25),
    Mission(id: 'm11', title: 'Place a spot limit order', reward: 250, target: 1),
    Mission(id: 'm12', title: 'Hold 3 different crypto assets', reward: 200, target: 3),
    Mission(id: 'm13', title: 'Reach a 3-day check-in streak', reward: 350, target: 3),
    Mission(id: 'm14', title: 'Open 5 futures positions', reward: 500, target: 5),
    Mission(id: 'm15', title: 'Make 50 total trades', reward: 750, target: 50),
    Mission(id: 'm16', title: 'Hold 5 different crypto assets', reward: 400, target: 5),
    Mission(id: 'm17', title: 'Place 3 spot limit orders', reward: 450, target: 3),
    Mission(id: 'm18', title: 'Earn 1,000 total XP', reward: 500, target: 1000),
    Mission(id: 'm19', title: 'Reach a 7-day check-in streak', reward: 600, target: 7),
    Mission(id: 'm20', title: 'Open 10 futures positions', reward: 800, target: 10),
    Mission(id: 'm21', title: 'Add 8 cryptos to your watchlist', reward: 250, target: 8),
    Mission(id: 'm22', title: 'Make 75 total trades', reward: 900, target: 75),
    Mission(id: 'm23', title: 'Make 100 total trades', reward: 1200, target: 100),
    Mission(id: 'm24', title: 'Reach \$10,000 virtual balance', reward: 600, target: 10000),
    Mission(id: 'm25', title: 'Reach \$25,000 virtual balance', reward: 1000, target: 25000),
    // Stock Arena Missions
    Mission(id: 'm_s1', title: 'Buy your first stock (US or Indian)', reward: 100, target: 1),
    Mission(id: 'm_s2', title: 'Add 3 stocks to your watchlist', reward: 100, target: 3),
    Mission(id: 'm_s3', title: 'Queue an After-Market Order (AMO)', reward: 150, target: 1),
    Mission(id: 'm_s4', title: 'Try 2x-5x Intraday Margin on stocks', reward: 200, target: 1),
    Mission(id: 'm_s5', title: 'Hold 3 different stock equities', reward: 250, target: 3),
    Mission(id: 'm_s6', title: 'Execute 10 stock trades', reward: 400, target: 10),
  ];

  Timer? _firestoreTimeout;
  String? _currentListeningUid;
  StreamSubscription? _authSub;
  StreamSubscription? _tipsSub;
  bool _disposed = false;

  void retrySync() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      state = state.copyWith(isLoading: true, hasSyncError: false);
      _listenToFirestore(user, force: true);
    }
  }

  void clearLoading() {
    if (state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  UserState build() {
    _disposed = false;
    _currentListeningUid = null;
    _sub = null;
    _authSub = null;
    _tipsSub = null;
    _firestoreTimeout = null;

    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
      _sub = null;
      _authSub?.cancel();
      _authSub = null;
      _tipsSub?.cancel();
      _tipsSub = null;
      _firestoreTimeout?.cancel();
      _firestoreTimeout = null;
      _currentListeningUid = null;
    });

    Future.microtask(() {
      if (!_disposed) {
        _loadLocalCurrency();
      }
    });

    User? currentUser;
    try {
      currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {}

    if (currentUser != null) {
      Future.microtask(() {
        if (!_disposed) {
          _listenToFirestore(currentUser!);
        }
      });
    }

    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        Future.microtask(() {
          if (_disposed) return;
          if (user != null) {
            _listenToFirestore(user);
          } else {
            _currentListeningUid = null;
            _sub?.cancel();
            _sub = null;
            _tipsSub?.cancel();
            _tipsSub = null;
            _firestoreTimeout?.cancel();
            _firestoreTimeout = null;
            final currentCurrency = state.profile.preferredCurrency;
            state = _defaultState(isLoading: false).copyWith(
              profile: _defaultState().profile.copyWith(
                preferredCurrency: currentCurrency,
              ),
            );
          }
        });
      });
    } catch (_) {}

    Future.microtask(() {
      if (!_disposed) {
        try {
          ref.listen<List<Stock>>(marketProvider, (previous, next) {
            if (_disposed) return;
            try {
              checkAndExecuteSpotLimitOrders(next);
              checkAndExecuteFuturesLimitOrders(next);
              checkAndExecuteFuturesLiquidations(next);
            } catch (_) {}
          });
          ref.listen<List<Stock>>(stockMarketProvider, (previous, next) {
            if (_disposed) return;
            try {
              checkAndExecuteSpotLimitOrders(next);
              checkAndExecuteFuturesLimitOrders(next);
              checkAndExecuteAmoOrders(next);
              checkAndExecuteFuturesLiquidations(next);
            } catch (_) {}
          });
        } catch (_) {}
      }
    });

    return _defaultState(isLoading: currentUser != null);
  }

  Future<void> _loadLocalCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final savedCurrency = prefs.getString('preferred_currency') ?? 'USD';
      final savedLanguage = prefs.getString('preferred_language');
      // Purge legacy global device unlock key if present
      await prefs.remove('is_ai_signals_unlocked');
      if (_disposed) return;
      state = state.copyWith(
        profile: state.profile.copyWith(
          preferredCurrency: savedCurrency,
          preferredLanguage: savedLanguage ?? state.profile.preferredLanguage,
        ),
      );
      if (savedLanguage != null) {
        AppTranslations.setLanguage(savedLanguage);
      }
    } catch (_) {}
  }

  UserState _defaultState({bool isLoading = false}) {
    return UserState(
      isLoading: isLoading,
      isOnboarded: false,
      hasSyncError: false,
      profile: const UserProfile(
        name: 'Guest',
        experienceLevel: 'Beginner',
        virtualBalance: 0,
        xp: 0,
        streak: 1,
        watchlist: {},
        preferredCurrency: 'USD',
      ),
      missions: MISSION_POOL.take(4).toList(),
    );
  }

  String _generateUid() {
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'PT-$rand';
  }

  Future<void> _loadCachedUserState(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final raw = prefs.getString('cached_user_state_$uid');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final cached = UserState.fromJson(data);
        if (_disposed) return;
        if (state.isLoading || !state.isOnboarded) {
          final savedCurrency = prefs.getString('preferred_currency');
          final finalProfile = (savedCurrency != null && savedCurrency.isNotEmpty)
              ? cached.profile.copyWith(preferredCurrency: savedCurrency)
              : cached.profile;
          state = cached.copyWith(isLoading: false, hasSyncError: false, profile: finalProfile);
        }
      }
    } catch (_) {}
  }

  Future<void> _cacheUserState(String uid, UserState userState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_state_$uid', jsonEncode(userState.toJson()));
    } catch (_) {}
  }

  void _listenToFirestore(User user, {bool force = false}) {
    if (_disposed) return;
    if (!force && _currentListeningUid == user.uid && _sub != null) {
      return;
    }
    _currentListeningUid = user.uid;
    _sub?.cancel();
    _sub = null;
    _tipsSub?.cancel();
    _tipsSub = null;
    _firestoreTimeout?.cancel();
    _firestoreTimeout = null;

    // Listen for incoming tips sent to this user in real time
    _listenToIncomingTips(user.uid);

    // Mark loading to prevent premature onboarding flash
    if (!state.isOnboarded) {
      state = state.copyWith(isLoading: true, hasSyncError: false);
    }

    // 1. Instantly load local cache if available to prevent premature onboarding or loading freeze
    _loadCachedUserState(user.uid);

    // 2. Set fallback timeout so slow/offline/non-GMS devices never lock in loading state
    _firestoreTimeout = Timer(const Duration(seconds: 4), () {
      if (_disposed) return;
      if (state.isLoading) {
        state = state.copyWith(
          isLoading: false,
          hasSyncError: !state.isOnboarded,
        );
      }
    });

    // 3. Listen to live Firestore snapshots with error handling
    try {
      _sub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) async {
        _firestoreTimeout?.cancel();
        _firestoreTimeout = null;
        if (_disposed) return;
        if (doc.exists && doc.data() != null) {
          var profileState = UserState.fromJson(doc.data()!).copyWith(isLoading: false, hasSyncError: false);

          // Auto-delete account if banned for > 10 days
          if (profileState.isBanned || profileState.profile.isBanned) {
            final wasDeleted = await BanManager.checkAndAutoDeleteCurrentUser(
              user: user,
              isBanned: true,
              bannedAt: profileState.bannedAt,
            );
            if (wasDeleted) {
              state = state.copyWith(isLoading: false, isOnboarded: false);
              return;
            }
          }

          bool needsUpdate = false;

          try {
            final prefs = await SharedPreferences.getInstance();
            if (_disposed) return;
            final savedCurrency = prefs.getString('preferred_currency');
            if (savedCurrency != null) {
              if (profileState.profile.preferredCurrency != savedCurrency) {
                profileState = profileState.copyWith(
                  profile: profileState.profile.copyWith(preferredCurrency: savedCurrency),
                );
                needsUpdate = true;
              }
            } else {
              await prefs.setString('preferred_currency', profileState.profile.preferredCurrency);
            }

            // One-time cleanup for any accounts erroneously marked unlocked during prior testing
            final hasReset = prefs.getBool('ai_signals_lock_reset_v1') ?? false;
            if (!hasReset) {
              await prefs.remove('is_ai_signals_unlocked');
              await prefs.setBool('ai_signals_lock_reset_v1', true);
              if (profileState.profile.isAiSignalsUnlocked) {
                profileState = profileState.copyWith(
                  profile: profileState.profile.copyWith(isAiSignalsUnlocked: false),
                );
                needsUpdate = true;
              }
            }
          } catch (_) {}

          if (_disposed) return;

          if (profileState.profile.publicUid.isEmpty) {
            profileState = profileState.copyWith(
              profile: profileState.profile.copyWith(publicUid: _generateUid()),
            );
            needsUpdate = true;
          }

          if (profileState.profile.email != (user.email ?? '')) {
            profileState = profileState.copyWith(
              profile: profileState.profile.copyWith(email: user.email ?? ''),
            );
            needsUpdate = true;
          }

          state = profileState;
          _syncAllMissionProgress();
          _checkBadges();
          final currentMarket = ref.read(marketProvider);
          if (currentMarket.isNotEmpty) {
            checkAndExecuteFuturesLiquidations(currentMarket);
          }
          final currentStockMarket = ref.read(stockMarketProvider);
          if (currentStockMarket.isNotEmpty) {
            checkAndExecuteAmoOrders(currentStockMarket);
            checkAndExecuteFuturesLiquidations(currentStockMarket);
          }
          _cacheUserState(user.uid, profileState);
          if (needsUpdate) {
            _saveToFirestore();
          }
        } else if (!doc.exists) {
          if (_disposed) return;
          final currentCurrency = state.profile.preferredCurrency;
          state = _defaultState(isLoading: false).copyWith(
            profile: _defaultState().profile.copyWith(
              name: user.displayName ?? '',
              publicUid: _generateUid(),
              email: user.email ?? '',
              preferredCurrency: currentCurrency,
            ),
          );
          _cacheUserState(user.uid, state);
          _saveToFirestore();
        }
      }, onError: (err) {
        _firestoreTimeout?.cancel();
        _firestoreTimeout = null;
        if (_disposed) return;
        if (state.isLoading) {
          state = state.copyWith(
            isLoading: false,
            hasSyncError: !state.isOnboarded,
          );
        }
      });
    } catch (_) {
      _firestoreTimeout?.cancel();
      _firestoreTimeout = null;
      if (!_disposed && state.isLoading) {
        state = state.copyWith(
          isLoading: false,
          hasSyncError: !state.isOnboarded,
        );
      }
    }
  }

  void _listenToIncomingTips(String userId) {
    _tipsSub?.cancel();
    try {
      _tipsSub = FirebaseFirestore.instance
          .collection('community_tips')
          .where('recipientId', isEqualTo: userId)
          .where('claimed', isEqualTo: false)
          .snapshots()
          .listen((snapshot) async {
        if (_disposed || snapshot.docs.isEmpty) return;

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final amountUsd = (data['amountUsd'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
          final senderName = (data['senderName'] as String?) ?? 'A trader';

          if (amountUsd > 0) {
            try {
              // 1. Mark as claimed so it is never re-processed
              await doc.reference.update({
                'claimed': true,
                'claimedAt': FieldValue.serverTimestamp(),
              });

              if (_disposed) return;

              final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
              final baseCreditAmount = amountUsd * inrRate;

              // 2. Credit the recipient's virtual balance
              final newBalance = state.profile.virtualBalance + baseCreditAmount;
              state = state.copyWith(
                profile: state.profile.copyWith(
                  virtualBalance: newBalance,
                ),
              );

              // 3. Log wallet credit transaction
              _logWalletTx(
                title: 'Community Tip Received',
                subtitle: 'Received \$${amountUsd.toStringAsFixed(0)} USD from $senderName on Community Hub',
                amount: baseCreditAmount,
                type: 'credit',
                category: 'community_tip',
              );

              // 4. Save updated balance to Firestore
              _saveToFirestore();
            } catch (_) {}
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _saveToFirestore() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (user != null) {
      _cacheUserState(user.uid, state);
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(state.toJson());
      } catch (_) {}
    }
  }

  void _logWalletTx({
    required String title,
    required String subtitle,
    required double amount,
    required String type,
    required String category,
  }) {
    final entry = {
      'title': title,
      'subtitle': subtitle,
      'amount': amount,
      'type': type,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final updated = List<Map<String, dynamic>>.from(state.walletEntries)..add(entry);
    state = state.copyWith(walletEntries: updated);
    _saveToFirestore();
  }

  Future<void> acknowledgeResetNotice() async {
    final currentNotice = state.profile.resetNotice;
    if (currentNotice == null) return;
    final updatedNotice = Map<String, dynamic>.from(currentNotice);
    updatedNotice['acknowledged'] = true;
    final updatedProfile = state.profile.copyWith(resetNotice: updatedNotice);
    state = state.copyWith(profile: updatedProfile);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profile.resetNotice.acknowledged': true,
          'resetNotice.acknowledged': true,
        });
      } catch (_) {}
    }
  }

  void onboardUser(String name, String experienceLevel, String currency, String photoUrl) {
    state = state.copyWith(
      isOnboarded: true,
      createdAt: state.createdAt ?? DateTime.now(),
      profile: state.profile.copyWith(
        name: name.trim(),
        experienceLevel: experienceLevel,
        preferredCurrency: currency,
        photoUrl: photoUrl,
        virtualBalance: 5000,
        xp: 50,
      ),
    );
    _saveToFirestore();
  }

  void addVirtualFundsFromPayment({
    required double virtualAmount,
    required double inrAmount,
    required String paymentId,
    String paymentMethod = 'google_play',
    double? bonusVirtualAmount,
  }) {
    final newBalance = state.profile.virtualBalance + virtualAmount;
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: newBalance,
      ),
    );

    final methodLabel = paymentMethod == 'google_play' ? 'Google Play' : 'Razorpay';

    final formattedPaid = CurrencyFormatters.format(inrAmount, state.profile.preferredCurrency);
    final bonusNotice = (bonusVirtualAmount != null && bonusVirtualAmount > 0)
        ? ' • Bonus: +${CurrencyFormatters.format(bonusVirtualAmount, state.profile.preferredCurrency)}'
        : '';

    _logWalletTx(
      title: 'Virtual Capital Top-Up',
      subtitle: 'Paid $formattedPaid via $methodLabel • ID: $paymentId$bonusNotice',
      amount: virtualAmount,
      type: 'credit',
      category: 'topup',
    );

    // Save transaction to Firestore money_requests collection as auto-approved payment
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('money_requests').add({
        'requesterName': state.profile.name.isNotEmpty ? state.profile.name : 'CryptoTrader',
        'requesterUid': state.profile.publicUid,
        'requesterId': user.uid,
        'amount': virtualAmount,
        'bonusAmount': bonusVirtualAmount ?? 0.0,
        'baseAmount': virtualAmount - (bonusVirtualAmount ?? 0.0),
        'inrAmount': inrAmount,
        'paymentId': paymentId,
        'paymentMethod': paymentMethod,
        'reason': 'Instant Auto-Credit Top-Up (Paid $formattedPaid$bonusNotice)',
        'requesterNetWorth': state.profile.virtualBalance,
        'status': 'approved',
        'createdAt': DateTime.now().toIso8601String(),
        'previousBalance': state.profile.virtualBalance - virtualAmount,
        'newBalance': newBalance,
      });
    }

    _saveToFirestore();
  }

  void addVirtualFundsFromRewardedAd({
    required double rewardUsd,
    required int adCount,
  }) {
    final inrMultiplier = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final creditAmount = rewardUsd * inrMultiplier;
    final newBalance = state.profile.virtualBalance + creditAmount;
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: newBalance,
      ),
    );

    final txId = 'AD_${DateTime.now().millisecondsSinceEpoch}';
    final formattedCash = CurrencyFormatters.formatUsd(
      rewardUsd,
      state.profile.preferredCurrency,
      decimalDigits: 0,
    );

    _logWalletTx(
      title: 'Video Ad Reward',
      subtitle: 'Completed $adCount ${adCount == 1 ? 'Ad' : 'Ads'} for +$formattedCash Capital',
      amount: creditAmount,
      type: 'credit',
      category: 'topup',
    );

    // Save transaction to Firestore money_requests collection for audit verification
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('money_requests').add({
        'requesterName': state.profile.name.isNotEmpty ? state.profile.name : 'CryptoTrader',
        'requesterUid': state.profile.publicUid,
        'requesterId': user.uid,
        'amount': creditAmount,
        'rewardUsd': rewardUsd,
        'inrAmount': 0.0,
        'paymentId': txId,
        'paymentMethod': 'rewarded_ad',
        'reason': 'Watched $adCount Video Ad(s)',
        'requesterNetWorth': state.profile.virtualBalance,
        'status': 'approved',
        'createdAt': DateTime.now().toIso8601String(),
        'previousBalance': state.profile.virtualBalance - creditAmount,
        'newBalance': newBalance,
      });
    }

    _saveToFirestore();
  }

  bool deductVirtualBalanceForTip({required double amount, required String recipientName}) {
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final baseDeductAmount = amount * inrRate;

    if (state.profile.virtualBalance < baseDeductAmount) {
      return false; // Insufficient balance
    }
    final newBalance = state.profile.virtualBalance - baseDeductAmount;
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: newBalance,
      ),
    );

    _logWalletTx(
      title: 'Community Tip Sent',
      subtitle: 'Tipped \$${amount.toStringAsFixed(0)} USD to $recipientName on Community Hub',
      amount: -baseDeductAmount,
      type: 'debit',
      category: 'community_tip',
    );
    _saveToFirestore();

    return true;
  }

  void updateProfileSettings({String? name, String? currency, String? language, String? themeMode, String? photoUrl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (currency != null) {
        await prefs.setString('preferred_currency', currency);
      }
      if (language != null) {
        await prefs.setString('preferred_language', language);
      }
    } catch (_) {}
    state = state.copyWith(
      profile: state.profile.copyWith(
        name: name,
        preferredCurrency: currency,
        preferredLanguage: language,
        themeMode: themeMode,
        photoUrl: photoUrl,
      ),
    );
    _saveToFirestore();
  }

  void addFunds(double amount) {
    if (amount <= 0) return;
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: state.profile.virtualBalance + amount,
      ),
    );
    _saveToFirestore();
  }

  bool claimReviewReward({double amount = 25.0, int xp = 100}) {
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: state.profile.virtualBalance + amount,
        xp: state.profile.xp + xp,
      ),
    );
    _saveToFirestore();
    return true;
  }

  void toggleWatchlist(String symbol) {
    final current = Set<String>.from(state.profile.watchlist);
    if (current.contains(symbol)) {
      current.remove(symbol);
    } else {
      current.add(symbol);
      _addXp(10);
    }
    
    state = state.copyWith(profile: state.profile.copyWith(watchlist: current));
    _updateMissionProgress('m2', min(current.length, 3));
    _updateMissionProgress('m8', min(current.length, 5));
    _updateMissionProgress('m21', min(current.length, 8));
    _saveToFirestore();
  }

  static const List<double> DAILY_CASH_TIERS = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 20.0];
  static const List<int> DAILY_XP_TIERS = [10, 15, 20, 25, 30, 35, 50];

  static const List<XpMilestone> XP_MILESTONES = [
    XpMilestone(
      id: 'xp_m1',
      requiredXp: 250,
      level: 2,
      cashReward: 15.0,
      titleUnlocked: 'Apprentice Trader',
      badgeIcon: '🎖️',
      description: 'Execute initial trades and prove foundational market literacy.',
    ),
    XpMilestone(
      id: 'xp_m2',
      requiredXp: 500,
      level: 3,
      cashReward: 25.0,
      titleUnlocked: 'Momentum Trader',
      badgeIcon: '⚡',
      description: 'Maintain trading consistency and master multi-asset orders.',
    ),
    XpMilestone(
      id: 'xp_m3',
      requiredXp: 1000,
      level: 5,
      cashReward: 50.0,
      titleUnlocked: 'Strategy Captain',
      badgeIcon: '🧭',
      description: 'Command portfolio risk and maintain steady trade execution.',
    ),
    XpMilestone(
      id: 'xp_m4',
      requiredXp: 2500,
      level: 11,
      cashReward: 100.0,
      titleUnlocked: 'Market Maestro',
      badgeIcon: '🎯',
      description: 'Navigate market volatility across Spot and Futures arenas.',
    ),
    XpMilestone(
      id: 'xp_m5',
      requiredXp: 5000,
      level: 21,
      cashReward: 150.0,
      titleUnlocked: 'Pro Analyst',
      badgeIcon: '📊',
      description: 'Demonstrate elite technical foresight and disciplined win streaks.',
    ),
    XpMilestone(
      id: 'xp_m_lvl31',
      requiredXp: 7500,
      level: 31,
      cashReward: 200.0,
      titleUnlocked: 'Alpha Vanguard',
      badgeIcon: '🛡️',
      description: 'Pioneer high-alpha positioning and risk-controlled market defense.',
    ),
    XpMilestone(
      id: 'xp_m6',
      requiredXp: 10000,
      level: 41,
      cashReward: 300.0,
      titleUnlocked: 'Crypto Whale',
      badgeIcon: '🐋',
      description: 'Command substantial liquidity and seasoned market influence.',
    ),
    XpMilestone(
      id: 'xp_m_lvl50',
      requiredXp: 12250,
      level: 50,
      cashReward: 500.0,
      titleUnlocked: 'Grandmaster 50',
      badgeIcon: '🔱',
      description: 'Break into the elite upper echelon by reaching Level 50. Unlocks the prestigious Grandmaster badge on the Leaderboard.',
    ),
    XpMilestone(
      id: 'xp_m_lvl65',
      requiredXp: 16000,
      level: 65,
      cashReward: 750.0,
      titleUnlocked: 'Liquidity Sovereign',
      badgeIcon: '🌊',
      description: 'Direct tidal liquidity waves across deep futures and high-volume order books.',
    ),
    XpMilestone(
      id: 'xp_m7',
      requiredXp: 20000,
      level: 81,
      cashReward: 1000.0,
      titleUnlocked: 'Apex Legend',
      badgeIcon: '🔥',
      description: 'The pinnacle of paper trading prowess and championship dominance.',
    ),
    XpMilestone(
      id: 'xp_m_lvl100',
      requiredXp: 24750,
      level: 100,
      cashReward: 1500.0,
      titleUnlocked: 'Mythic Centurion',
      badgeIcon: '👑',
      description: 'The ultimate hall of fame milestone. Unlocks the prestigious Mythic Centurion Gold Badge on the Leaderboard and an exclusive app launch celebration.',
    ),
    XpMilestone(
      id: 'xp_m_lvl125',
      requiredXp: 31000,
      level: 125,
      cashReward: 2000.0,
      titleUnlocked: 'Celestial Titan',
      badgeIcon: '🪐',
      description: 'Transcend standard exchange boundaries with planetary portfolio gravity.',
    ),
    XpMilestone(
      id: 'xp_m_lvl150',
      requiredXp: 37250,
      level: 150,
      cashReward: 3000.0,
      titleUnlocked: 'Sovereign Overlord',
      badgeIcon: '⚔️',
      description: 'Rule peer duels and global championships with unquestioned tactical dominion.',
    ),
    XpMilestone(
      id: 'xp_m_lvl200',
      requiredXp: 49750,
      level: 200,
      cashReward: 4500.0,
      titleUnlocked: 'Infinity Archon',
      badgeIcon: '🌌',
      description: 'Master infinite risk dimensions and eternal algorithmic precision.',
    ),
    XpMilestone(
      id: 'xp_m_lvl250',
      requiredXp: 62250,
      level: 250,
      cashReward: 6000.0,
      titleUnlocked: 'Immortal Paragon',
      badgeIcon: '💎',
      description: 'The supreme zenith of trading mastery. Immortalized across the global crypto cosmos.',
    ),
  ];

  bool claimXpMilestone(String milestoneId) {
    final milestone = XP_MILESTONES.firstWhere(
      (m) => m.id == milestoneId,
      orElse: () => const XpMilestone(
        id: '',
        requiredXp: 9999999,
        level: 999,
        cashReward: 0,
        titleUnlocked: '',
        badgeIcon: '',
        description: '',
      ),
    );
    if (milestone.id.isEmpty) return false;
    if (state.profile.xp < milestone.requiredXp) return false;
    if (state.profile.claimedXpMilestones.contains(milestoneId)) return false;

    final inrMultiplier = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final creditAmount = milestone.cashReward * inrMultiplier;
    final updatedClaimed = Set<String>.from(state.profile.claimedXpMilestones)..add(milestoneId);
    final newBalance = state.profile.virtualBalance + creditAmount;
    final updatedTitle = UserProfile.getEvolvedTitle(state.profile.xp);

    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: newBalance,
        claimedXpMilestones: updatedClaimed,
        experienceLevel: updatedTitle,
      ),
    );

    final formattedCash = CurrencyFormatters.formatUsd(
      milestone.cashReward,
      state.profile.preferredCurrency,
      decimalDigits: 0,
    );

    _logWalletTx(
      title: 'XP Milestone Reward: ${milestone.titleUnlocked}',
      subtitle: 'Achieved ${milestone.requiredXp} XP • +$formattedCash Virtual Capital',
      amount: creditAmount,
      type: 'credit',
      category: 'milestone',
    );

    _updateMissionProgress('m24', state.profile.virtualBalance.toInt());
    _updateMissionProgress('m25', state.profile.virtualBalance.toInt());
    _saveToFirestore();
    return true;
  }

  void claimDailyReward({double? customCash, int? customXp}) {
    if (state.hasClaimedDaily) return;

    final now = DateTime.now().toLocal();
    final todayStr = now.toIso8601String();
    
    int newStreak = 1;
    final lastClaimStr = state.profile.lastDailyClaim;
    if (lastClaimStr != null && lastClaimStr.isNotEmpty) {
      final lastClaim = DateTime.tryParse(lastClaimStr)?.toLocal();
      if (lastClaim != null) {
        final difference = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastClaim.year, lastClaim.month, lastClaim.day));
        if (difference.inDays == 1) {
          newStreak = state.profile.streak + 1;
        } else if (difference.inDays == 0) {
          newStreak = state.profile.streak;
        }
      }
    }

    final cycleIndex = ((newStreak - 1) % 7).clamp(0, 6);
    final cashUsd = customCash ?? DAILY_CASH_TIERS[cycleIndex];
    final xpAmount = customXp ?? DAILY_XP_TIERS[cycleIndex];
    final inrMultiplier = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final creditAmount = cashUsd * inrMultiplier;

    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: state.profile.virtualBalance + creditAmount,
        streak: newStreak,
        lastDailyClaim: todayStr,
      ),
    );
    _addXp(xpAmount);
    _updateMissionProgress('m13', newStreak);
    _updateMissionProgress('m19', newStreak);
    _updateMissionProgress('m24', state.profile.virtualBalance.toInt());
    _updateMissionProgress('m25', state.profile.virtualBalance.toInt());
    _saveToFirestore();
    final formattedCash = CurrencyFormatters.formatUsd(
      cashUsd,
      state.profile.preferredCurrency,
      decimalDigits: 0,
    );
    _logWalletTx(
      title: 'Daily Check-In Reward',
      subtitle: 'Day $newStreak streak bonus (+$formattedCash & +$xpAmount XP)',
      amount: creditAmount,
      type: 'credit',
      category: 'daily_reward',
    );
  }

  void recordQuizAttempt() {
    final now = DateTime.now().toIso8601String();
    state = state.copyWith(profile: state.profile.copyWith(lastQuizAttempt: now));
    _saveToFirestore();
  }

  void resetDailyReward() {
    state = state.copyWith(profile: state.profile.copyWith(lastDailyClaim: ''));
    _saveToFirestore();
  }

  void completeQuiz() {
    final m3Idx = state.missions.indexWhere((m) => m.id == 'm3');
    if (m3Idx >= 0) {
      _updateMissionProgress('m3', 1);
      _saveToFirestore();
    }
  }

  bool tradeStock(Stock stock, OrderSide side, int quantity) {
    if (stock.isStock) {
      if (!stock.isMarketOpen || !stock.isLive || stock.currentPrice <= 0) return false;
    } else {
      if (!ref.read(marketOnlineProvider) || !stock.isLive || stock.currentPrice <= 0) return false;
    }
    if (quantity <= 0) return false;

    // Cost in USD for master virtual balance
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final double costPerShareUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
    if (costPerShareUsd <= 0 || costPerShareUsd.isNaN || costPerShareUsd.isInfinite) return false;

    final totalCostUsd = costPerShareUsd * quantity;
    final holdings = List<Holding>.from(state.holdings);
    
    if (side == OrderSide.buy) {
      if (state.profile.virtualBalance < totalCostUsd) return false;
      final idx = holdings.indexWhere((h) => h.symbol == stock.symbol);
      if (idx >= 0) {
        final existing = holdings[idx];
        final newQty = existing.quantity + quantity;
        final newAvg = ((existing.quantity * existing.averagePrice) + totalCostUsd) / newQty;
        holdings[idx] = Holding(symbol: stock.symbol, quantity: newQty, averagePrice: newAvg);
      } else {
        holdings.add(Holding(symbol: stock.symbol, quantity: quantity, averagePrice: costPerShareUsd));
      }
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance - totalCostUsd),
      );
    } else {
      final idx = holdings.indexWhere((h) => h.symbol == stock.symbol);
      if (idx < 0 || state.availableHoldingQty(stock.symbol) < quantity) return false;

      final existing = holdings[idx];
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance + totalCostUsd),
      );
      if (existing.quantity == quantity) {
        holdings.removeAt(idx);
      } else {
        holdings[idx] = Holding(symbol: stock.symbol, quantity: existing.quantity - quantity, averagePrice: existing.averagePrice);
      }
    }

    final newTrade = Trade(symbol: stock.symbol, side: side, quantity: quantity, price: costPerShareUsd, time: DateTime.now());
    state = state.copyWith(
      holdings: holdings,
      trades: [newTrade, ...state.trades],
    );

    _addXp(side == OrderSide.buy ? 35 : 45);
    _updateMissionProgress('m1', 1);
    if (stock.isStock) {
      _updateMissionProgress('m_s1', 1);
      final stockHoldingsCount = holdings.where((h) => !h.symbol.endsWith('USDT')).length;
      _updateMissionProgress('m_s5', stockHoldingsCount);
      final stockTradesCount = state.trades.where((t) => !t.symbol.endsWith('USDT')).length;
      _updateMissionProgress('m_s6', stockTradesCount);
    }
    _updateMissionProgress('m5', state.trades.length);
    _updateMissionProgress('m7', state.trades.length);
    _updateMissionProgress('m10', state.trades.length);
    _updateMissionProgress('m15', state.trades.length);
    _updateMissionProgress('m22', state.trades.length);
    _updateMissionProgress('m23', state.trades.length);
    _updateMissionProgress('m12', holdings.length);
    _updateMissionProgress('m16', holdings.length);
    _updateMissionProgress('m24', state.profile.virtualBalance.toInt());
    _updateMissionProgress('m25', state.profile.virtualBalance.toInt());
    
    final uniqueSides = state.trades.map((t) => t.side).toSet().length;
    _updateMissionProgress('m4', uniqueSides);

    _checkBadges();
    _saveToFirestore();
    return true;
  }

  bool placeSpotLimitOrder({
    required Stock stock,
    required OrderSide side,
    required int quantity,
    required double targetPrice,
  }) {
    if (stock.isStock) {
      if (!stock.isMarketOpen || !stock.isLive || stock.currentPrice <= 0) return false;
    } else {
      if (!ref.read(marketOnlineProvider) || !stock.isLive || stock.currentPrice <= 0) return false;
    }
    if (quantity <= 0 || targetPrice <= 0 || targetPrice.isNaN || targetPrice.isInfinite) return false;
    if (quantity > 100000000) return false; // Hard cap against overflow and fabricated quantity injection

    // Price collar sanity check: targetPrice cannot deviate absurdly from current price (prevents low limit exploits)
    // Symmetrical 30% band collar prevents both low limit manipulation and absurd limit pricing
    if (targetPrice < stock.currentPrice * 0.70 || targetPrice > stock.currentPrice * 1.30) return false;

    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final targetPriceUsd = stock.currency == 'INR' ? (targetPrice / inrRate) : targetPrice;
    final totalCostUsd = targetPriceUsd * quantity;
    final feeUsd = totalCostUsd * 0.001;
    final totalRequiredUsd = totalCostUsd + feeUsd;
    if (totalRequiredUsd.isNaN || totalRequiredUsd.isInfinite || totalRequiredUsd <= 0) return false;

    if (side == OrderSide.buy) {
      if (state.profile.virtualBalance < totalRequiredUsd) return false;
      // Reserve virtual balance immediately in USD
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance - totalRequiredUsd),
      );
    } else {
      if (state.availableHoldingQty(stock.symbol) < quantity) return false;
    }

    final newOrder = SpotLimitOrder(
      id: 'SPOT_LIMIT_${DateTime.now().millisecondsSinceEpoch}',
      symbol: stock.symbol,
      side: side,
      quantity: quantity,
      targetPrice: targetPrice,
      reservedAmount: side == OrderSide.buy ? totalRequiredUsd : quantity.toDouble(),
      createdAt: DateTime.now(),
      status: 'pending',
    );

    state = state.copyWith(
      spotLimitOrders: [newOrder, ...state.spotLimitOrders],
    );

    _updateMissionProgress('m11', 1);
    _updateMissionProgress('m17', state.spotLimitOrders.length);

    _saveToFirestore();
    return true;
  }

  bool cancelSpotLimitOrder(String orderId) {
    final idx = state.spotLimitOrders.indexWhere((o) => o.id == orderId && o.status == 'pending');
    if (idx < 0) return false;

    final order = state.spotLimitOrders[idx];
    final updatedOrders = List<SpotLimitOrder>.from(state.spotLimitOrders);
    updatedOrders[idx] = order.copyWith(status: 'cancelled');

    if (order.side == OrderSide.buy) {
      // Refund reserved virtual capital
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance + order.reservedAmount),
        spotLimitOrders: updatedOrders,
      );
    } else {
      state = state.copyWith(spotLimitOrders: updatedOrders);
    }

    _saveToFirestore();
    return true;
  }

  void checkAndExecuteSpotLimitOrders(List<Stock> currentStocks) {
    try {
      final _ = state;
    } catch (_) {
      return;
    }
    final pendingOrders = state.spotLimitOrders.where((o) => o.status == 'pending').toList();
    if (pendingOrders.isEmpty) return;

    bool stateChanged = false;
    List<SpotLimitOrder> updatedOrders = List<SpotLimitOrder>.from(state.spotLimitOrders);
    List<Holding> holdings = List<Holding>.from(state.holdings);
    List<Trade> trades = List<Trade>.from(state.trades);
    double currentBalance = state.profile.virtualBalance;

    for (final order in pendingOrders) {
      final stockIdx = currentStocks.indexWhere((s) => s.symbol == order.symbol);
      if (stockIdx < 0) continue;
      final stock = currentStocks[stockIdx];

      // CRITICAL: Ensure market price is verified live and positive before execution
      if (!stock.isLive || stock.currentPrice <= 0 || stock.currentPrice.isNaN) continue;

      bool shouldExecute = false;
      if (order.side == OrderSide.buy && stock.currentPrice <= order.targetPrice) {
        shouldExecute = true;
      } else if (order.side == OrderSide.sell && stock.currentPrice >= order.targetPrice) {
        shouldExecute = true;
      }

      if (shouldExecute) {
        final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
        final rawPriceUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
        if (rawPriceUsd <= 0 || rawPriceUsd.isNaN || rawPriceUsd.isInfinite) continue;

        // Price improvement: Buy fills at min(target, current), Sell fills at max(target, current)
        final targetUsd = stock.currency == 'INR' ? (order.targetPrice / inrRate) : order.targetPrice;
        final execPriceUsd = order.side == OrderSide.buy
            ? min(targetUsd, rawPriceUsd)
            : max(targetUsd, rawPriceUsd);

        final totalValueUsd = execPriceUsd * order.quantity;
        final actualFeeUsd = totalValueUsd * 0.001;

        if (order.side == OrderSide.buy) {
          final actualTotalUsd = totalValueUsd + actualFeeUsd;
          final diffRefund = order.reservedAmount - actualTotalUsd;

          if (diffRefund < 0 && (currentBalance + diffRefund) < 0) {
            // Cannot afford fill due to unforeseen gap, cancel order and refund reserved
            final orderIdx = updatedOrders.indexWhere((o) => o.id == order.id);
            if (orderIdx >= 0) {
              updatedOrders[orderIdx] = order.copyWith(status: 'cancelled');
            }
            currentBalance += order.reservedAmount;
            stateChanged = true;
            continue;
          }

          stateChanged = true;
          final orderIdx = updatedOrders.indexWhere((o) => o.id == order.id);
          if (orderIdx >= 0) {
            updatedOrders[orderIdx] = order.copyWith(status: 'executed');
          }

          currentBalance += diffRefund;

          final hIdx = holdings.indexWhere((h) => h.symbol == order.symbol);
          if (hIdx >= 0) {
            final existing = holdings[hIdx];
            final newQty = existing.quantity + order.quantity;
            final newAvg = ((existing.quantity * existing.averagePrice) + totalValueUsd) / newQty;
            holdings[hIdx] = Holding(symbol: order.symbol, quantity: newQty, averagePrice: newAvg);
          } else {
            holdings.add(Holding(symbol: order.symbol, quantity: order.quantity, averagePrice: execPriceUsd));
          }
        } else {
          final hIdx = holdings.indexWhere((h) => h.symbol == order.symbol);
          if (hIdx < 0 || holdings[hIdx].quantity < order.quantity) {
            // Anti-Cheat: User cannot sell holdings they do not possess.
            // Cancel order immediately to prevent ghost coin exploitation.
            final orderIdx = updatedOrders.indexWhere((o) => o.id == order.id);
            if (orderIdx >= 0) {
              updatedOrders[orderIdx] = order.copyWith(status: 'cancelled');
            }
            stateChanged = true;
            continue;
          }

          stateChanged = true;
          final orderIdx = updatedOrders.indexWhere((o) => o.id == order.id);
          if (orderIdx >= 0) {
            updatedOrders[orderIdx] = order.copyWith(status: 'executed');
          }

          final existing = holdings[hIdx];
          if (existing.quantity <= order.quantity) {
            holdings.removeAt(hIdx);
          } else {
            holdings[hIdx] = Holding(symbol: order.symbol, quantity: existing.quantity - order.quantity, averagePrice: existing.averagePrice);
          }
          currentBalance += (totalValueUsd - actualFeeUsd);
        }

        trades.insert(0, Trade(
          symbol: order.symbol,
          side: order.side,
          quantity: order.quantity,
          price: execPriceUsd,
          time: DateTime.now(),
        ));

        // Deliver in-app notification for limit order execution
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final clean = order.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').trim().toUpperCase();
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('notifications')
              .add({
                'userId': currentUser.uid,
                'title': 'Limit Order Executed! 📈',
                'message': 'Your ${order.side == OrderSide.buy ? "Buy" : "Sell"} limit order for ${order.quantity} $clean was filled at \$${execPriceUsd.toStringAsFixed(2)}.',
                'category': 'trade',
                'type': 'order_fill',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
                'data': {
                  'symbol': clean,
                  'side': order.side == OrderSide.buy ? 'BUY' : 'SELL',
                  'price': execPriceUsd,
                  'quantity': order.quantity,
                },
              }).then<void>((_) {}, onError: (_) {});
        }
      }
    }

    if (stateChanged) {
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: currentBalance),
        holdings: holdings,
        trades: trades,
        spotLimitOrders: updatedOrders,
      );
      _saveToFirestore();
    }
  }

  bool queueAmoOrder({
    required Stock stock,
    required OrderSide side,
    required int quantity,
    int leverage = 1,
  }) {
    if (quantity <= 0 || !stock.isLive || stock.currentPrice <= 0) return false;
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final double costPerShareUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
    if (costPerShareUsd <= 0 || costPerShareUsd.isNaN || costPerShareUsd.isInfinite) return false;

    final totalCostUsd = costPerShareUsd * quantity;
    final marginRequiredUsd = totalCostUsd / (leverage > 0 ? leverage : 1);
    final double reservedCash;

    if (side == OrderSide.buy) {
      if (state.profile.virtualBalance < marginRequiredUsd) return false;
      reservedCash = marginRequiredUsd;
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance - marginRequiredUsd),
      );
    } else {
      if (leverage == 1) {
        if (state.availableHoldingQty(stock.symbol) < quantity) return false;

        // No cash reserved for 1x delivery sell of owned shares
        reservedCash = 0.0;
      } else {
        if (state.profile.virtualBalance < marginRequiredUsd) return false;
        reservedCash = marginRequiredUsd;
        state = state.copyWith(
          profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance - marginRequiredUsd),
        );
      }
    }

    final newOrder = AmoOrder(
      id: 'AMO_${DateTime.now().millisecondsSinceEpoch}',
      symbol: stock.symbol,
      side: side,
      quantity: quantity,
      estimatedPrice: stock.currentPrice,
      reservedAmount: reservedCash,
      leverage: leverage,
      createdAt: DateTime.now(),
      status: 'queued',
    );

    state = state.copyWith(
      amoOrders: [newOrder, ...state.amoOrders],
    );

    _updateMissionProgress('m_s3', 1);
    _checkBadges();
    _saveToFirestore();
    return true;
  }

  bool cancelAmoOrder(String orderId) {
    final idx = state.amoOrders.indexWhere((o) => o.id == orderId && o.status == 'queued');
    if (idx < 0) return false;

    final order = state.amoOrders[idx];
    final refundCash = (order.reservedAmount > 0) ? order.reservedAmount : 0.0;
    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: state.profile.virtualBalance + refundCash),
      amoOrders: state.amoOrders.where((o) => o.id != orderId).toList(),
    );

    _saveToFirestore();
    return true;
  }

  void checkAndExecuteAmoOrders(List<Stock> stockMarket) {
    try {
      final _ = state;
    } catch (_) {
      return;
    }
    if (state.amoOrders.isEmpty || stockMarket.isEmpty) return;

    final pendingAmos = state.amoOrders.where((o) => o.status == 'queued').toList();
    if (pendingAmos.isEmpty) return;

    final updatedAmos = List<AmoOrder>.from(state.amoOrders);
    final holdings = List<Holding>.from(state.holdings);
    final positions = List<FuturesPosition>.from(state.futuresPositions);
    final trades = List<Trade>.from(state.trades);
    double currentBalance = state.profile.virtualBalance;
    bool stateChanged = false;

    for (final order in pendingAmos) {
      final stockIdx = stockMarket.indexWhere((s) => s.symbol == order.symbol);
      if (stockIdx < 0) continue;
      final stock = stockMarket[stockIdx];

      if (!stock.isMarketOpen || !stock.isLive || stock.currentPrice <= 0) continue;

      final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
      final execPriceUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
      if (execPriceUsd <= 0 || execPriceUsd.isNaN || execPriceUsd.isInfinite) continue;

      stateChanged = true;
      final oIdx = updatedAmos.indexWhere((o) => o.id == order.id);
      if (oIdx >= 0) {
        updatedAmos[oIdx] = order.copyWith(status: 'executed');
      }

      if (order.leverage > 1) {
        final newMargin = (order.quantity * execPriceUsd) / order.leverage;
        final diff = order.reservedAmount - newMargin;
        currentBalance += diff;

        positions.add(FuturesPosition(
          id: 'POS_AMO_${DateTime.now().millisecondsSinceEpoch}',
          symbol: order.symbol,
          side: order.side,
          leverage: order.leverage,
          entryPrice: execPriceUsd,
          quantity: order.quantity.toDouble(),
          margin: newMargin,
        ));
      } else {
        final totalValue = execPriceUsd * order.quantity;
        if (order.side == OrderSide.buy) {
          final diff = order.reservedAmount - totalValue;
          currentBalance += diff;

          final hIdx = holdings.indexWhere((h) => h.symbol == order.symbol);
          if (hIdx >= 0) {
            final existing = holdings[hIdx];
            final newQty = existing.quantity + order.quantity;
            final newAvg = ((existing.quantity * existing.averagePrice) + totalValue) / newQty;
            holdings[hIdx] = Holding(symbol: order.symbol, quantity: newQty, averagePrice: newAvg);
          } else {
            holdings.add(Holding(symbol: order.symbol, quantity: order.quantity, averagePrice: execPriceUsd));
          }
        } else {
          final hIdx = holdings.indexWhere((h) => h.symbol == order.symbol);
          if (hIdx < 0 || holdings[hIdx].quantity < order.quantity) {
            // Anti-Cheat: User sold or no longer possesses required shares. Cancel order safely.
            final oIdx = updatedAmos.indexWhere((o) => o.id == order.id);
            if (oIdx >= 0) {
              updatedAmos[oIdx] = order.copyWith(status: 'cancelled');
            }
            continue;
          }

          currentBalance += totalValue;
          final existing = holdings[hIdx];
          if (existing.quantity <= order.quantity) {
            holdings.removeAt(hIdx);
          } else {
            holdings[hIdx] = Holding(
              symbol: order.symbol,
              quantity: existing.quantity - order.quantity,
              averagePrice: existing.averagePrice,
            );
          }
        }
      }

      trades.insert(0, Trade(
        symbol: order.symbol,
        side: order.side,
        quantity: order.quantity,
        price: execPriceUsd,
        time: DateTime.now(),
      ));
    }

    if (stateChanged) {
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: currentBalance),
        holdings: holdings,
        futuresPositions: positions,
        trades: trades,
        amoOrders: updatedAmos,
      );
      _checkBadges();
      _saveToFirestore();
    }
  }

  void updateBioAndBadge(String newBio, String? featuredBadgeId) {
    state = state.copyWith(
      profile: state.profile.copyWith(
        bio: newBio.trim(),
        featuredBadgeId: featuredBadgeId,
      ),
    );
    _saveToFirestore();
  }

  void checkAndExecuteFuturesLiquidations(List<Stock> currentStocks) {
    try {
      final _ = state;
    } catch (_) {
      return;
    }
    if (state.futuresPositions.isEmpty || currentStocks.isEmpty) return;

    final liquidatedPositions = <FuturesPosition>[];
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;

    for (final pos in state.futuresPositions) {
      final clean = pos.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').replaceAll('-PERP', '').replaceAll('/USD', '').trim().toUpperCase();
      final stockIdx = currentStocks.indexWhere((s) {
        final sClean = s.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').replaceAll('-PERP', '').replaceAll('/USD', '').trim().toUpperCase();
        return s.symbol == pos.symbol || sClean == clean;
      });

      if (stockIdx < 0) continue;
      final stock = currentStocks[stockIdx];
      if (!stock.isLive || stock.currentPrice <= 0) continue;

      final priceUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;

      if (pos.isLiquidated(priceUsd)) {
        liquidatedPositions.add(pos);
      }
    }

    if (liquidatedPositions.isEmpty) return;

    final liquidatedIds = liquidatedPositions.map((p) => p.id).toSet();
    final remainingPositions = state.futuresPositions.where((p) => !liquidatedIds.contains(p.id)).toList();

    state = state.copyWith(futuresPositions: remainingPositions);

    final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
    for (final pos in liquidatedPositions) {
      final isLong = pos.side == OrderSide.buy;
      final clean = pos.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').replaceAll('-PERP', '').trim().toUpperCase();
      _logWalletTx(
        title: 'Futures Position Liquidated',
        subtitle: '$clean ${isLong ? 'Long' : 'Short'} ${pos.leverage}x liquidated • Margin ${formatter.format(pos.margin)} wiped out',
        amount: pos.margin,
        type: 'debit',
        category: 'futures_liquidation',
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      for (final pos in liquidatedPositions) {
        final clean = pos.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').replaceAll('-PERP', '').trim().toUpperCase();
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .add({
              'userId': currentUser.uid,
              'title': '⚠️ Position Liquidated',
              'message': 'Your $clean ${pos.side == OrderSide.buy ? "Long" : "Short"} ${pos.leverage}x was liquidated at market price.',
              'category': 'trade',
              'type': 'liquidation',
              'createdAt': DateTime.now().toIso8601String(),
              'isRead': false,
              'data': {
                'symbol': clean,
                'leverage': pos.leverage,
                'margin': pos.margin,
              },
            }).then<void>((_) {}, onError: (_) {});
      }
    }

    _saveToFirestore();
  }

  bool openFuturesPosition(
    Stock stock,
    OrderSide side,
    int leverage,
    double quantity, {
    String orderType = 'Market',
  }) {
    if (quantity <= 0 || quantity.isNaN || quantity.isInfinite || quantity > 100000000) return false;
    if (leverage < 1 || leverage > 100) return false;
    if (stock.isStock) {
      if (!stock.isMarketOpen || !stock.isLive || stock.currentPrice <= 0) return false;
      if (leverage > 5) leverage = 5;
    } else {
      if (!ref.read(marketOnlineProvider) || !stock.isLive || stock.currentPrice <= 0) return false;
    }
    // ALWAYS execute at verified live market price in USD
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final execPrice = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
    if (execPrice <= 0 || execPrice.isNaN || execPrice.isInfinite) return false;
    final marginRequired = (quantity * execPrice) / leverage;
    if (marginRequired <= 0 || marginRequired.isNaN || marginRequired.isInfinite) return false;
    if (marginRequired > 5000000) return false; // Hard cap on runaway notional margin
    if (state.profile.virtualBalance < marginRequired) return false;

    final newPosition = FuturesPosition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: stock.symbol,
      side: side,
      leverage: leverage,
      entryPrice: execPrice,
      quantity: quantity,
      margin: marginRequired,
    );

    _updateMissionProgress('m6', 1);
    _updateMissionProgress('m9', state.futuresPositions.length + 1);
    _updateMissionProgress('m14', state.futuresPositions.length + 1);
    _updateMissionProgress('m20', state.futuresPositions.length + 1);
    if (stock.isStock) {
      _updateMissionProgress('m_s4', 1);
    }

    final newBalance = state.profile.virtualBalance - marginRequired;
    final newPositions = List<FuturesPosition>.from(state.futuresPositions)..add(newPosition);

    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: newBalance),
      futuresPositions: newPositions,
    );

    // Log actual cash deducted (margin), show position size in subtitle
    final contractValue = quantity * execPrice; // = margin × leverage
    final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
    final typeTitle = orderType != 'Market' ? 'Futures ($orderType) Margin Deducted' : 'Futures Margin Deducted';
    _logWalletTx(
      title: typeTitle,
      subtitle: '${stock.symbol} ${side == OrderSide.buy ? 'Long' : 'Short'} ${leverage}x  •  Margin ${formatter.format(marginRequired)} × $leverage = Position ${formatter.format(contractValue)}',
      amount: marginRequired,
      type: 'debit',
      category: 'futures_open',
    );

    _saveToFirestore();
    return true;
  }

  bool placeFuturesLimitOrder({
    required Stock stock,
    required OrderSide side,
    required int leverage,
    required double quantity,
    required double targetPrice,
    String orderType = 'Limit',
  }) {
    if (stock.isStock) {
      if (!stock.isMarketOpen || !stock.isLive || stock.currentPrice <= 0) return false;
      if (leverage > 5) leverage = 5;
    } else {
      if (!ref.read(marketOnlineProvider) || !stock.isLive || stock.currentPrice <= 0) return false;
    }
    if (targetPrice <= 0 || targetPrice.isNaN || targetPrice.isInfinite || quantity <= 0 || quantity.isNaN || quantity.isInfinite || quantity > 100000000 || leverage < 1 || leverage > 100) return false;

    // Price collar sanity check: symmetrical 30% band collar prevents both low limit manipulation and absurd limit pricing
    if (targetPrice < stock.currentPrice * 0.70 || targetPrice > stock.currentPrice * 1.30) return false;

    // Check if limit condition is already marketable against live market:
    // Buy Limit >= market price: immediately marketable at market price
    // Sell Limit <= market price: immediately marketable at market price
    final isMarketable = (side == OrderSide.buy && targetPrice >= stock.currentPrice) ||
                         (side == OrderSide.sell && targetPrice <= stock.currentPrice);

    if (isMarketable) {
      return openFuturesPosition(stock, side, leverage, quantity, orderType: orderType);
    }

    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
    final targetPriceUsd = stock.currency == 'INR' ? (targetPrice / inrRate) : targetPrice;

    // Otherwise, queue as a pending limit order and reserve margin in USD
    final marginRequired = (quantity * targetPriceUsd) / leverage;
    if (state.profile.virtualBalance < marginRequired) return false;

    final newOrder = FuturesLimitOrder(
      id: 'FUTURES_LIMIT_${DateTime.now().millisecondsSinceEpoch}',
      symbol: stock.symbol,
      side: side,
      leverage: leverage,
      quantity: quantity,
      targetPrice: targetPrice,
      reservedMargin: marginRequired,
      createdAt: DateTime.now(),
      status: 'pending',
      orderType: orderType,
    );

    final newBalance = state.profile.virtualBalance - marginRequired;
    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: newBalance),
      futuresLimitOrders: [newOrder, ...state.futuresLimitOrders],
    );

    final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
    _logWalletTx(
      title: 'Futures ($orderType) Margin Reserved',
      subtitle: '${stock.symbol} ${side == OrderSide.buy ? 'Long' : 'Short'} ${leverage}x  •  Reserved for Limit @ ${formatter.format(targetPrice)}',
      amount: marginRequired,
      type: 'debit',
      category: 'futures_limit_reserve',
    );

    _saveToFirestore();
    return true;
  }

  bool cancelFuturesLimitOrder(String orderId) {
    final idx = state.futuresLimitOrders.indexWhere((o) => o.id == orderId && o.status == 'pending');
    if (idx < 0) return false;

    final order = state.futuresLimitOrders[idx];
    final updatedOrders = List<FuturesLimitOrder>.from(state.futuresLimitOrders);
    updatedOrders[idx] = order.copyWith(status: 'cancelled');

    final newBalance = state.profile.virtualBalance + order.reservedMargin;
    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: newBalance),
      futuresLimitOrders: updatedOrders,
    );

    final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
    _logWalletTx(
      title: 'Futures Limit Margin Refunded',
      subtitle: '${order.symbol} ${order.side == OrderSide.buy ? 'Long' : 'Short'} ${order.leverage}x • Limit order cancelled • Refunded ${formatter.format(order.reservedMargin)}',
      amount: order.reservedMargin,
      type: 'credit',
      category: 'futures_limit_cancel',
    );

    _saveToFirestore();
    return true;
  }

  void checkAndExecuteFuturesLimitOrders(List<Stock> currentStocks) {
    try {
      final _ = state;
    } catch (_) {
      return;
    }
    final pendingOrders = state.futuresLimitOrders.where((o) => o.status == 'pending').toList();
    if (pendingOrders.isEmpty) return;

    bool stateChanged = false;
    final updatedOrders = List<FuturesLimitOrder>.from(state.futuresLimitOrders);
    final newPositions = List<FuturesPosition>.from(state.futuresPositions);
    double currentBalance = state.profile.virtualBalance;

    for (final order in pendingOrders) {
      final stockIdx = currentStocks.indexWhere((s) => s.symbol == order.symbol);
      if (stockIdx < 0) continue;
      final stock = currentStocks[stockIdx];
      // CRITICAL: Ensure market price is verified live and positive before execution
      if (!stock.isLive || stock.currentPrice <= 0 || stock.currentPrice.isNaN) continue;

      bool shouldExecute = false;
      if (order.side == OrderSide.buy && stock.currentPrice <= order.targetPrice) {
        shouldExecute = true;
      } else if (order.side == OrderSide.sell && stock.currentPrice >= order.targetPrice) {
        shouldExecute = true;
      }

      if (shouldExecute) {
        final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;
        final rawPriceUsd = stock.currency == 'INR' ? (stock.currentPrice / inrRate) : stock.currentPrice;
        if (rawPriceUsd <= 0 || rawPriceUsd.isNaN || rawPriceUsd.isInfinite) continue;

        // Price improvement: Buy fills at min(target, current), Sell fills at max(target, current)
        final targetUsd = stock.currency == 'INR' ? (order.targetPrice / inrRate) : order.targetPrice;
        final fillPriceUsd = order.side == OrderSide.buy
            ? min(targetUsd, rawPriceUsd)
            : max(targetUsd, rawPriceUsd);

        final actualMarginRequired = (order.quantity * fillPriceUsd) / order.leverage;

        // Refund any excess margin reserved or check if extra margin is required
        final marginDiff = order.reservedMargin - actualMarginRequired;
        if (marginDiff < 0 && (currentBalance + marginDiff) < 0) {
          // Cannot afford to fill position because price jumped beyond user's margin balance!
          // Cancel order and refund reservedMargin
          stateChanged = true;
          final orderIdx = updatedOrders.indexWhere((o) => o.id == order.id);
          if (orderIdx >= 0) {
            updatedOrders[orderIdx] = order.copyWith(status: 'cancelled');
          }
          currentBalance += order.reservedMargin;
          continue;
        }

        stateChanged = true;
        final orderIdx = updatedOrders.indexWhere((o) => o.id == order.id);
        if (orderIdx >= 0) {
          updatedOrders[orderIdx] = order.copyWith(status: 'executed');
        }

        currentBalance += marginDiff;

        final pos = FuturesPosition(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          symbol: order.symbol,
          side: order.side,
          leverage: order.leverage,
          entryPrice: fillPriceUsd,
          quantity: order.quantity,
          margin: actualMarginRequired,
        );
        newPositions.add(pos);

        final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
        final contractValue = order.quantity * fillPriceUsd;
        _logWalletTx(
          title: 'Futures (${order.orderType}) Filled',
          subtitle: '${order.symbol} ${order.side == OrderSide.buy ? 'Long' : 'Short'} ${order.leverage}x  •  Margin ${formatter.format(actualMarginRequired)} × ${order.leverage} = Position ${formatter.format(contractValue)}',
          amount: actualMarginRequired,
          type: 'debit',
          category: 'futures_open',
        );

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final clean = order.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').trim().toUpperCase();
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('notifications')
              .add({
                'userId': currentUser.uid,
                'title': 'Futures Limit Order Filled! 🎯',
                'message': 'Your $clean ${order.side == OrderSide.buy ? "Long" : "Short"} ${order.leverage}x limit order was filled at \$${fillPriceUsd.toStringAsFixed(2)}.',
                'category': 'trade',
                'type': 'order_fill',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
                'data': {
                  'symbol': clean,
                  'side': order.side == OrderSide.buy ? 'BUY' : 'SELL',
                  'price': fillPriceUsd,
                  'quantity': order.quantity,
                  'leverage': order.leverage,
                },
              }).then<void>((_) {}, onError: (_) {});
        }
      }
    }

    if (stateChanged) {
      state = state.copyWith(
        profile: state.profile.copyWith(virtualBalance: currentBalance),
        futuresLimitOrders: updatedOrders,
        futuresPositions: newPositions,
      );
      _saveToFirestore();
    }
  }

  void closeFuturesPosition(FuturesPosition position, [double? passedPrice]) {
    final stockMarket = ref.read(stockMarketProvider);
    final cryptoMarket = ref.read(marketProvider);
    final inrRate = CurrencyFormatters.rates['INR'] ?? CurrencyFormatters.usdToInr;

    final clean = position.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').replaceAll('-PERP', '').replaceAll('/USD', '').trim().toUpperCase();
    final matchedStock = stockMarket.where((s) => s.symbol == position.symbol || s.symbol.toUpperCase() == clean).firstOrNull;
    final matchedCrypto = cryptoMarket.where((s) => s.symbol == position.symbol || s.symbol.replaceAll('USDT', '').toUpperCase() == clean).firstOrNull;
    final asset = matchedStock ?? matchedCrypto;

    // Anti-Cheat & Live Price Verification
    if (matchedStock != null) {
      if (!matchedStock.isLive || !matchedStock.isMarketOpen || matchedStock.currentPrice <= 0) return;
    } else {
      if (!ref.read(marketOnlineProvider)) return;
      if (asset != null && (!asset.isLive || asset.currentPrice <= 0)) return;
    }

    final effectiveRawPrice = (asset != null && asset.isLive && asset.currentPrice > 0)
        ? asset.currentPrice
        : (passedPrice ?? 0.0);

    if (effectiveRawPrice <= 0 || effectiveRawPrice.isNaN || effectiveRawPrice.isInfinite) return;

    final priceUsd = (asset != null && asset.currency == 'INR') ? (effectiveRawPrice / inrRate) : effectiveRawPrice;

    final isLong = position.side == OrderSide.buy;
    final priceDiff = priceUsd - position.entryPrice;
    final pnl = isLong ? priceDiff * position.quantity : -priceDiff * position.quantity;
    
    final returnedAmount = position.margin + pnl;
    final safeReturn = returnedAmount > 0 ? returnedAmount : 0.0;
    final newBalance = state.profile.virtualBalance + safeReturn;
    
    final newPositions = state.futuresPositions.where((p) => p.id != position.id).toList();

    state = state.copyWith(
      profile: state.profile.copyWith(virtualBalance: newBalance),
      futuresPositions: newPositions,
    );

    final pnlSign = pnl >= 0 ? '+' : '';
    final dirLabel = '${position.symbol} ${isLong ? 'Long' : 'Short'} ${position.leverage}x';

    // Entry 1: margin returned to balance
    _logWalletTx(
      title: 'Futures Margin Returned',
      subtitle: '$dirLabel • Margin back to wallet',
      amount: position.margin,
      type: 'credit',
      category: 'futures_close',
    );

    // Entry 2: PnL (separate debit or credit)
    if (pnl != 0) {
      final formatter = AppCurrencyFormatter(state.profile.preferredCurrency);
      _logWalletTx(
        title: pnl >= 0 ? 'Futures Profit' : 'Futures Loss',
        subtitle: '$dirLabel • PnL: $pnlSign${formatter.format(pnl.abs())}',
        amount: pnl.abs(),
        type: pnl >= 0 ? 'credit' : 'debit',
        category: 'futures_pnl',
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final clean = position.symbol.replaceAll('USDT', '').replaceAll('/USDT', '').replaceAll('-PERP', '').trim().toUpperCase();
      final roe = position.margin > 0 ? (pnl / position.margin) * 100 : 0.0;
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .add({
            'userId': currentUser.uid,
            'title': pnl >= 0 ? 'Position Closed in Profit 🎯' : 'Position Closed 📉',
            'message': 'Closed $clean ${isLong ? "Long" : "Short"} ${position.leverage}x • PnL: ${pnl >= 0 ? "+" : ""}\$${pnl.toStringAsFixed(2)} (${roe.toStringAsFixed(1)}%)',
            'category': 'trade',
            'type': 'tp_sl',
            'createdAt': DateTime.now().toIso8601String(),
            'isRead': false,
            'data': {
              'symbol': clean,
              'pnl': pnl,
              'pnlPercentage': roe,
            },
          }).then<void>((_) {}, onError: (_) {});
    }

    _saveToFirestore();
  }

  void _addXp(int amount) {
    final newXp = state.profile.xp + amount;
    final updatedTitle = UserProfile.getEvolvedTitle(newXp);
    state = state.copyWith(
      profile: state.profile.copyWith(
        xp: newXp,
        experienceLevel: updatedTitle,
      ),
    );
    _updateMissionProgress('m18', newXp);
    _checkBadges();
  }

  void _updateMissionProgress(String missionId, int progress) {
    final idx = state.missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return;
    
    final m = state.missions[idx];
    if (m.completed) return;

    final newProgress = max(m.progress, progress);
    final completed = newProgress >= m.target;
    
    final updatedMissions = List<Mission>.from(state.missions);
    updatedMissions[idx] = m.copyWith(progress: newProgress, completed: completed);
    state = state.copyWith(missions: updatedMissions);
  }

  void _syncAllMissionProgress() {
    _updateMissionProgress('m1', state.trades.isNotEmpty ? 1 : 0);
    _updateMissionProgress('m2', min(state.profile.watchlist.length, 3));
    _updateMissionProgress('m4', state.trades.map((t) => t.side).toSet().length);
    _updateMissionProgress('m5', state.trades.length);
    _updateMissionProgress('m7', state.trades.length);
    _updateMissionProgress('m8', min(state.profile.watchlist.length, 5));
    _updateMissionProgress('m10', state.trades.length);
    _updateMissionProgress('m11', state.spotLimitOrders.isNotEmpty ? 1 : 0);
    _updateMissionProgress('m12', state.holdings.length);
    _updateMissionProgress('m13', state.profile.streak);
    _updateMissionProgress('m14', state.futuresPositions.length);
    _updateMissionProgress('m15', state.trades.length);
    _updateMissionProgress('m16', state.holdings.length);
    _updateMissionProgress('m17', state.spotLimitOrders.length);
    _updateMissionProgress('m18', state.profile.xp);
    _updateMissionProgress('m19', state.profile.streak);
    _updateMissionProgress('m20', state.futuresPositions.length);
    _updateMissionProgress('m21', min(state.profile.watchlist.length, 8));
    _updateMissionProgress('m22', state.trades.length);
    _updateMissionProgress('m23', state.trades.length);
    _updateMissionProgress('m24', state.profile.virtualBalance.toInt());
    _updateMissionProgress('m25', state.profile.virtualBalance.toInt());
  }

  void claimMission(String missionId) {
    final idx = state.missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return;
    
    final m = state.missions[idx];
    if (!m.completed) return;

    _addXp(m.reward);

    final completedSet = Set<String>.from(state.profile.completedMissions);
    completedSet.add(m.id);

    final updatedMissions = List<Mission>.from(state.missions);
    Mission? newMission;
    
    for (final poolM in MISSION_POOL) {
      if (!completedSet.contains(poolM.id) && !updatedMissions.any((active) => active.id == poolM.id)) {
        newMission = poolM;
        break;
      }
    }

    if (newMission != null) {
      updatedMissions[idx] = newMission;
    } else {
      updatedMissions.removeAt(idx);
    }

    state = state.copyWith(
      missions: updatedMissions,
      profile: state.profile.copyWith(completedMissions: completedSet)
    );

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .add({
            'userId': currentUser.uid,
            'title': 'Quest Reward Claimed! 🎯',
            'message': 'Completed "${m.title}" and earned +${m.reward} XP!',
            'category': 'system',
            'type': 'quest',
            'createdAt': DateTime.now().toIso8601String(),
            'isRead': false,
            'data': {'reward': m.reward},
          }).then<void>((_) {}, onError: (_) {});
    }
    _logWalletTx(
      title: 'Quest Reward',
      subtitle: m.title,
      amount: m.reward.toDouble(),
      type: 'credit',
      category: 'quest_reward',
    );
    _saveToFirestore();
  }

  void _checkBadges() {
    final currentBadges = Set<String>.from(state.profile.unlockedBadges);
    bool changed = false;

    if (state.trades.isNotEmpty && !currentBadges.contains('b1')) {
      currentBadges.add('b1');
      changed = true;
    }
    if (state.trades.length >= 10 && !currentBadges.contains('b2')) {
      currentBadges.add('b2');
      changed = true;
    }
    if (state.profile.virtualBalance > 20000000 && !currentBadges.contains('b3')) {
      currentBadges.add('b3');
      changed = true;
    }
    if (state.holdings.isNotEmpty && !currentBadges.contains('b4')) {
      currentBadges.add('b4');
      changed = true;
    }
    if (state.holdings.length >= 3 && !currentBadges.contains('b5')) {
      currentBadges.add('b5');
      changed = true;
    }
    // Stock Badges
    final hasStockTrade = state.trades.any((t) => !t.symbol.endsWith('USDT') && !t.symbol.contains('/'));
    if (hasStockTrade && !currentBadges.contains('b_stock1')) {
      currentBadges.add('b_stock1');
      changed = true;
    }
    final hasTechStock = state.trades.any((t) => t.symbol == 'AAPL' || t.symbol == 'NVDA' || t.symbol == 'TSLA' || t.symbol == 'AMD');
    if (hasTechStock && !currentBadges.contains('b_stock2')) {
      currentBadges.add('b_stock2');
      changed = true;
    }
    final stockHoldingsCount = state.holdings.where((h) => !h.symbol.endsWith('USDT')).length;
    if (stockHoldingsCount >= 5 && !currentBadges.contains('b_stock3')) {
      currentBadges.add('b_stock3');
      changed = true;
    }
    if (state.amoOrders.isNotEmpty && !currentBadges.contains('b_stock4')) {
      currentBadges.add('b_stock4');
      changed = true;
    }
    final hasStockMargin = state.futuresPositions.any((p) => !p.symbol.endsWith('USDT') && p.leverage <= 5);
    if (hasStockMargin && !currentBadges.contains('b_stock5')) {
      currentBadges.add('b_stock5');
      changed = true;
    }
    if (stockHoldingsCount >= 3 && !currentBadges.contains('b_stock6')) {
      currentBadges.add('b_stock6');
      changed = true;
    }
    // Level Milestone Progression Badges (15 Career Tiers)
    if (state.profile.xp >= 250 && !currentBadges.contains('b_lvl2')) {
      currentBadges.add('b_lvl2');
      changed = true;
    }
    if (state.profile.xp >= 500 && !currentBadges.contains('b_lvl3')) {
      currentBadges.add('b_lvl3');
      changed = true;
    }
    if (state.profile.xp >= 1000 && !currentBadges.contains('b_lvl5')) {
      currentBadges.add('b_lvl5');
      changed = true;
    }
    if (state.profile.xp >= 2500 && !currentBadges.contains('b_lvl11')) {
      currentBadges.add('b_lvl11');
      changed = true;
    }
    if (state.profile.xp >= 5000 && !currentBadges.contains('b_lvl21')) {
      currentBadges.add('b_lvl21');
      changed = true;
    }
    if (state.profile.xp >= 7500 && !currentBadges.contains('b_lvl31')) {
      currentBadges.add('b_lvl31');
      changed = true;
    }
    if (state.profile.xp >= 10000 && !currentBadges.contains('b_lvl41')) {
      currentBadges.add('b_lvl41');
      changed = true;
    }
    if (state.profile.xp >= 12250 && (!currentBadges.contains('b_lvl50') || !currentBadges.contains('b50'))) {
      currentBadges.add('b_lvl50');
      currentBadges.add('b50');
      changed = true;
    }
    if (state.profile.xp >= 16000 && !currentBadges.contains('b_lvl65')) {
      currentBadges.add('b_lvl65');
      changed = true;
    }
    if (state.profile.xp >= 20000 && !currentBadges.contains('b_lvl81')) {
      currentBadges.add('b_lvl81');
      changed = true;
    }
    if (state.profile.xp >= 24750 && (!currentBadges.contains('b_lvl100') || !currentBadges.contains('b100'))) {
      currentBadges.add('b_lvl100');
      currentBadges.add('b100');
      changed = true;
    }
    if (state.profile.xp >= 31000 && !currentBadges.contains('b_lvl125')) {
      currentBadges.add('b_lvl125');
      changed = true;
    }
    if (state.profile.xp >= 37250 && !currentBadges.contains('b_lvl150')) {
      currentBadges.add('b_lvl150');
      changed = true;
    }
    if (state.profile.xp >= 49750 && !currentBadges.contains('b_lvl200')) {
      currentBadges.add('b_lvl200');
      changed = true;
    }
    if (state.profile.xp >= 62250 && !currentBadges.contains('b_lvl250')) {
      currentBadges.add('b_lvl250');
      changed = true;
    }

    if (changed) {
      state = state.copyWith(profile: state.profile.copyWith(unlockedBadges: currentBadges));
      _saveToFirestore();
    }
  }

  void recordBlitzResult({
    required bool won,
    required int eloDelta,
    required int xpGain,
    double matchRoi = 0.0,
  }) {
    final newRating = (state.profile.blitzRating + eloDelta).clamp(100, 9999);
    final newWins = won ? state.profile.blitzWins + 1 : state.profile.blitzWins;
    final newLosses = won ? state.profile.blitzLosses : state.profile.blitzLosses + 1;
    final newXp = state.profile.xp + xpGain;

    final updatedBadges = Set<String>.from(state.profile.unlockedBadges);
    if (won && !updatedBadges.contains('b6')) {
      updatedBadges.add('b6');
    }

    state = state.copyWith(
      profile: state.profile.copyWith(
        blitzRating: newRating,
        blitzWins: newWins,
        blitzLosses: newLosses,
        xp: newXp,
        unlockedBadges: updatedBadges,
      ),
    );
    _saveToFirestore();

    // Sync to dedicated weekly_championship collection using FieldValue.increment
    try {
      final emailLower = state.profile.email.toLowerCase();
      final nameLower = state.profile.name.toLowerCase();
      // Admin accounts are excluded from championship leaderboard synchronization
      if (emailLower == 'admin@gmail.com' || emailLower.contains('admin') || nameLower.contains('admin')) {
        return;
      }

      final name = state.profile.name.trim().isNotEmpty ? state.profile.name.trim() : 'Trader';
      final uid = state.profile.email.isNotEmpty ? state.profile.email.replaceAll('.', '_') : 'user_$name';
      final earnedBoost = (won && matchRoi > 0) ? matchRoi : (won ? 5.0 : 0.0);

      FirebaseFirestore.instance.collection('weekly_championship').doc(uid).set({
        'uid': uid,
        'name': name,
        'photoUrl': state.profile.photoUrl,
        'xp': newXp,
        'wins': newWins,
        'losses': newLosses,
        'tournamentScore': FieldValue.increment(earnedBoost),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> joinWeeklyTournament() async {
    try {
      final emailLower = state.profile.email.toLowerCase();
      final nameLower = state.profile.name.toLowerCase();
      // Admin accounts cannot join weekly championship
      if (emailLower == 'admin@gmail.com' || emailLower.contains('admin') || nameLower.contains('admin')) {
        return;
      }

      final name = state.profile.name.trim().isNotEmpty ? state.profile.name.trim() : 'Trader';
      final uid = state.profile.email.isNotEmpty ? state.profile.email.replaceAll('.', '_') : 'user_$name';

      await FirebaseFirestore.instance.collection('weekly_championship').doc(uid).set({
        'uid': uid,
        'name': name,
        'photoUrl': state.profile.photoUrl,
        'xp': state.profile.xp,
        'wins': 0,
        'losses': 0,
        'tournamentScore': 0.0,
        'pendingPrize': FieldValue.delete(),
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void creditChampionshipPrize({
    required double amount,
    required int rank,
    required String weekId,
    double score = 1.0,
  }) {
    if (score <= 0.0 || rank < 1 || rank > 10 || amount <= 0) {
      debugPrint('[Championship] Denied prize credit: ineligible score $score or rank #$rank');
      return;
    }
    state = state.copyWith(
      profile: state.profile.copyWith(
        virtualBalance: state.profile.virtualBalance + amount,
      ),
    );
    _logWalletTx(
      title: 'Weekly Championship Rank #$rank Prize',
      subtitle: '$weekId Top 10 Award (+${score.toStringAsFixed(1)}%)',
      amount: amount,
      type: 'credit',
      category: 'tournament_prize',
    );
    _addXp(rank == 1 ? 500 : (rank <= 3 ? 300 : 150));
    _saveToFirestore();
  }

  Future<void> unlockAiSignals({String paymentId = '', double inrAmount = 4225.0}) async {
    state = state.copyWith(
      profile: state.profile.copyWith(isAiSignalsUnlocked: true),
    );
    _saveToFirestore();

    if (paymentId.isNotEmpty) {
      _logWalletTx(
        title: 'AI Signals Desk License',
        subtitle: 'Unlocked via Google Play • ID: $paymentId',
        amount: 0.0,
        type: 'credit',
        category: 'unlock',
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final formattedPaid = CurrencyFormatters.format(inrAmount, state.profile.preferredCurrency);
          FirebaseFirestore.instance.collection('money_requests').add({
            'requesterName': state.profile.name.isNotEmpty ? state.profile.name : 'CryptoTrader',
            'requesterUid': state.profile.publicUid,
            'requesterId': user.uid,
            'amount': 0.0,
            'inrAmount': inrAmount,
            'paymentId': paymentId,
            'paymentMethod': 'google_play',
            'reason': 'AI Signals & Safe Leverage Desk Lifetime License ($formattedPaid)',
            'requesterNetWorth': state.profile.virtualBalance,
            'status': 'approved',
            'createdAt': DateTime.now().toIso8601String(),
            'previousBalance': state.profile.virtualBalance,
            'newBalance': state.profile.virtualBalance,
          });
        } catch (_) {}
      }
    }
  }

  Future<void> lockAiSignals() async {
    state = state.copyWith(
      profile: state.profile.copyWith(isAiSignalsUnlocked: false),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_ai_signals_unlocked');
    } catch (_) {}
    _saveToFirestore();
  }
}
