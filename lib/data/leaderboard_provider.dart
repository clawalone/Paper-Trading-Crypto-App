import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/leaderboard/widgets/past_seven_days_metrics_sheet.dart';
import 'market_provider.dart';
import 'user_provider.dart';

class LeaderboardState {
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> streakPlayers;
  final int myRank;
  final Map<String, dynamic>? myStats;
  final int myStreakRank;
  final Map<String, dynamic>? myStreakStats;
  final bool isLoading;
  final String? error;
  final int totalTradersCount;
  final int bannedUsersCount;
  final int newTradersTodayCount;
  final int newTradersWeekCount;
  final List<DayRegistrationSummary> pastSevenDaysSummary;
  final List<TraderRegistrationEntry> allTraders;

  const LeaderboardState({
    this.players = const [],
    this.streakPlayers = const [],
    this.myRank = -1,
    this.myStats,
    this.myStreakRank = -1,
    this.myStreakStats,
    this.isLoading = true,
    this.error,
    this.totalTradersCount = 0,
    this.bannedUsersCount = 0,
    this.newTradersTodayCount = 0,
    this.newTradersWeekCount = 0,
    this.pastSevenDaysSummary = const [],
    this.allTraders = const [],
  });

  LeaderboardState copyWith({
    List<Map<String, dynamic>>? players,
    List<Map<String, dynamic>>? streakPlayers,
    int? myRank,
    Map<String, dynamic>? myStats,
    int? myStreakRank,
    Map<String, dynamic>? myStreakStats,
    bool? isLoading,
    String? error,
    int? totalTradersCount,
    int? bannedUsersCount,
    int? newTradersTodayCount,
    int? newTradersWeekCount,
    List<DayRegistrationSummary>? pastSevenDaysSummary,
    List<TraderRegistrationEntry>? allTraders,
  }) {
    return LeaderboardState(
      players: players ?? this.players,
      streakPlayers: streakPlayers ?? this.streakPlayers,
      myRank: myRank ?? this.myRank,
      myStats: myStats ?? this.myStats,
      myStreakRank: myStreakRank ?? this.myStreakRank,
      myStreakStats: myStreakStats ?? this.myStreakStats,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalTradersCount: totalTradersCount ?? this.totalTradersCount,
      bannedUsersCount: bannedUsersCount ?? this.bannedUsersCount,
      newTradersTodayCount: newTradersTodayCount ?? this.newTradersTodayCount,
      newTradersWeekCount: newTradersWeekCount ?? this.newTradersWeekCount,
      pastSevenDaysSummary: pastSevenDaysSummary ?? this.pastSevenDaysSummary,
      allTraders: allTraders ?? this.allTraders,
    );
  }
}

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  StreamSubscription<QuerySnapshot>? _subscription;
  Timer? _priceRefreshTimer;
  QuerySnapshot? _lastSnapshot;
  bool _isDisposed = false;

  @override
  LeaderboardState build() {
    _isDisposed = false;

    ref.onDispose(() {
      _isDisposed = true;
      _subscription?.cancel();
      _priceRefreshTimer?.cancel();
    });

    _startListening();

    // Periodic net-worth recompute using fresh market prices every 30 seconds
    _priceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recomputeWithLatestPrices();
    });

    return const LeaderboardState(isLoading: true);
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
      (snapshot) {
        if (_isDisposed) return;
        _lastSnapshot = snapshot;
        _processSnapshot(snapshot);
      },
      onError: (err) {
        if (_isDisposed) return;
        state = state.copyWith(
          isLoading: state.players.isEmpty,
          error: err.toString(),
        );
      },
    );
  }

  void _recomputeWithLatestPrices() {
    if (_isDisposed || _lastSnapshot == null) return;
    _processSnapshot(_lastSnapshot!);
  }

  Future<void> refresh() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      if (!_isDisposed) {
        _lastSnapshot = snapshot;
        _processSnapshot(snapshot);
      }
    } catch (_) {}
  }

  void _processSnapshot(QuerySnapshot snapshot) {
    // 1. Build latest price map from marketProvider
    final market = ref.read(marketProvider);
    final priceMap = <String, double>{};
    for (final stock in market) {
      priceMap[stock.symbol] = stock.currentPrice;
    }

    // 2. Parse players directly without heavy UserState serialization
    final players = <Map<String, dynamic>>[];
    final allTraders = <TraderRegistrationEntry>[];
    int totalTraders = 0;
    int bannedCount = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);

    // Initialize 7 calendar days (0 = Today, 1 = Yesterday, ..., 6 = 6 days ago)
    final List<DayRegistrationSummary> pastSevenDays = List.generate(7, (i) {
      final dayDate = startOfToday.subtract(Duration(days: i));
      String label;
      if (i == 0) {
        label = 'Today';
      } else if (i == 1) {
        label = 'Yesterday';
      } else {
        const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        label = '${weekdayNames[dayDate.weekday - 1]}, ${dayDate.day.toString().padLeft(2, '0')} ${monthNames[dayDate.month - 1]}';
      }
      return DayRegistrationSummary(
        date: dayDate,
        label: label,
        entries: [],
      );
    });

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final profile = data['profile'] as Map<String, dynamic>?;
        if (profile == null) continue;

        final email = (profile['email'] as String? ?? '').toLowerCase();
        final name = profile['name'] as String? ?? 'Trader';

        // Filter out internal admin accounts
        if (email == 'admin@gmail.com' || name.toLowerCase().contains('admin')) {
          continue;
        }

        final isBanned = (data['isBanned'] as bool? ?? false) ||
            (profile['isBanned'] as bool? ?? false);
        if (isBanned) {
          bannedCount++;
          continue;
        }

        totalTraders++;

        // Fast spot calculation
        double portfolioValue = 0;
        final rawHoldings = data['holdings'] as List?;
        if (rawHoldings != null) {
          for (final h in rawHoldings) {
            if (h is Map) {
              final sym = h['symbol']?.toString() ?? '';
              final qty = (h['quantity'] as num?)?.toDouble() ?? 0.0;
              final avg = (h['averagePrice'] as num?)?.toDouble() ?? 0.0;
              final price = priceMap[sym] ?? avg;
              portfolioValue += price * qty;
            }
          }
        }

        // Fast futures PnL calculation
        double futuresValue = 0;
        final rawPositions = data['futuresPositions'] as List?;
        if (rawPositions != null) {
          for (final p in rawPositions) {
            if (p is Map) {
              final sym = p['symbol']?.toString() ?? '';
              final qty = (p['quantity'] as num?)?.toDouble() ?? 0.0;
              final entryPrice = (p['entryPrice'] as num?)?.toDouble() ?? 0.0;
              final margin = (p['margin'] as num?)?.toDouble() ?? 0.0;
              final side = p['side']?.toString() ?? 'buy';
              final price = priceMap[sym];
              if (price != null) {
                final isLong = side.toLowerCase().contains('buy') || side.toLowerCase() == 'long';
                final diff = price - entryPrice;
                final pnl = isLong ? diff * qty : -diff * qty;
                final currentValue = margin + pnl;
                futuresValue += currentValue > 0 ? currentValue : 0;
              } else {
                futuresValue += margin;
              }
            }
          }
        }

        final virtualBal = (profile['virtualBalance'] as num?)?.toDouble() ?? 0.0;
        final netWorth = virtualBal + portfolioValue + futuresValue;
        final publicUid = profile['publicUid']?.toString() ?? '';

        final joinDate = _extractUserJoinDate(data);
        final traderEntry = TraderRegistrationEntry(
          uid: publicUid.isNotEmpty ? publicUid : doc.id,
          name: name.isNotEmpty ? name : 'Trader',
          email: profile['email']?.toString() ?? '',
          photoUrl: profile['photoUrl']?.toString() ?? '',
          joinDate: joinDate,
          virtualBalance: virtualBal,
          netWorth: netWorth,
          xp: (profile['xp'] as num?)?.toInt() ?? 0,
          isBanned: isBanned,
        );
        allTraders.add(traderEntry);

        // Classify entry into the past 7 days breakdown
        for (int i = 0; i < 7; i++) {
          final dayStart = pastSevenDays[i].date;
          final dayEnd = dayStart.add(const Duration(days: 1));
          if (!joinDate.isBefore(dayStart) && joinDate.isBefore(dayEnd)) {
            pastSevenDays[i].entries.add(traderEntry);
            break;
          }
        }

        players.add({
          'docId': doc.id,
          'uid': publicUid.isNotEmpty ? publicUid : doc.id,
          'name': name.isNotEmpty ? name : 'Trader',
          'netWorth': netWorth,
          'xp': (profile['xp'] as num?)?.toInt() ?? 0,
          'streak': (profile['streak'] as num?)?.toInt() ?? 0,
          'photoUrl': profile['photoUrl']?.toString(),
        });
      } catch (_) {}
    }

    // Sort entries within each day newest first
    for (final day in pastSevenDays) {
      day.entries.sort((a, b) => b.joinDate.compareTo(a.joinDate));
    }
    allTraders.sort((a, b) => b.joinDate.compareTo(a.joinDate));

    final newTradersToday = pastSevenDays.isNotEmpty ? pastSevenDays[0].count : 0;
    final newTradersWeek = pastSevenDays.fold(0, (total, d) => total + d.count);

    // Sort Global Leaderboard (Net Worth descending)
    players.sort(
      (a, b) => (b['netWorth'] as double).compareTo(a['netWorth'] as double),
    );

    // Sort Streaks Leaderboard (Streak descending, then XP descending)
    final streakPlayers = List<Map<String, dynamic>>.of(players);
    streakPlayers.sort((a, b) {
      final sA = (a['streak'] as int? ?? 0);
      final sB = (b['streak'] as int? ?? 0);
      if (sB != sA) return sB.compareTo(sA);
      final xpA = (a['xp'] as int? ?? 0);
      final xpB = (b['xp'] as int? ?? 0);
      return xpB.compareTo(xpA);
    });

    // Locate current user in both leaderboards
    final userState = ref.read(userProvider);
    final myName = userState.profile.name;
    final myUid = userState.profile.publicUid;

    int myRank = -1;
    Map<String, dynamic>? myStats;
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if ((myUid.isNotEmpty && p['uid'] == myUid) || p['name'] == myName) {
        myRank = i + 1;
        myStats = p;
        break;
      }
    }

    int myStreakRank = -1;
    Map<String, dynamic>? myStreakStats;
    for (int i = 0; i < streakPlayers.length; i++) {
      final p = streakPlayers[i];
      if ((myUid.isNotEmpty && p['uid'] == myUid) || p['name'] == myName) {
        myStreakRank = i + 1;
        myStreakStats = p;
        break;
      }
    }

    state = LeaderboardState(
      players: players,
      streakPlayers: streakPlayers,
      myRank: myRank,
      myStats: myStats,
      myStreakRank: myStreakRank,
      myStreakStats: myStreakStats,
      isLoading: false,
      error: null,
      totalTradersCount: totalTraders,
      bannedUsersCount: bannedCount,
      newTradersTodayCount: newTradersToday,
      newTradersWeekCount: newTradersWeek,
      pastSevenDaysSummary: pastSevenDays,
      allTraders: allTraders,
    );
  }

  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  static DateTime _extractUserJoinDate(Map<String, dynamic> data) {
    final profile = data['profile'] as Map<String, dynamic>?;

    DateTime? declaredCreatedAt = _parseTimestamp(data['createdAt']) ??
        _parseTimestamp(profile?['createdAt']) ??
        _parseTimestamp(data['joinedAt']) ??
        _parseTimestamp(profile?['joinedAt']) ??
        _parseTimestamp(data['registeredAt']) ??
        _parseTimestamp(profile?['registeredAt']) ??
        _parseTimestamp(data['timestamp']) ??
        _parseTimestamp(profile?['timestamp']);

    DateTime? earliestActivityDate;

    void checkDate(dynamic raw) {
      final d = _parseTimestamp(raw);
      if (d != null) {
        if (earliestActivityDate == null || d.isBefore(earliestActivityDate!)) {
          earliestActivityDate = d;
        }
      }
    }

    final walletEntries = data['walletEntries'] as List?;
    if (walletEntries != null) {
      for (final e in walletEntries) {
        if (e is Map) {
          checkDate(e['timestamp'] ?? e['time'] ?? e['date']);
        }
      }
    }

    final trades = data['trades'] as List?;
    if (trades != null) {
      for (final t in trades) {
        if (t is Map) {
          checkDate(t['time'] ?? t['timestamp']);
        }
      }
    }

    final spotOrders = data['spotLimitOrders'] as List?;
    if (spotOrders != null) {
      for (final o in spotOrders) {
        if (o is Map) {
          checkDate(o['createdAt'] ?? o['time']);
        }
      }
    }

    final futuresOrders = data['futuresLimitOrders'] as List?;
    if (futuresOrders != null) {
      for (final o in futuresOrders) {
        if (o is Map) {
          checkDate(o['createdAt'] ?? o['time']);
        }
      }
    }

    final amoOrders = data['amoOrders'] as List?;
    if (amoOrders != null) {
      for (final o in amoOrders) {
        if (o is Map) {
          checkDate(o['createdAt'] ?? o['time']);
        }
      }
    }

    checkDate(data['updatedAt'] ?? profile?['updatedAt']);
    checkDate(data['lastLogin'] ?? profile?['lastLogin']);
    checkDate(profile?['lastDailyClaim']);
    checkDate(profile?['lastQuizAttempt']);
    checkDate(data['bannedAt'] ?? profile?['bannedAt']);

    // Check if we found ANY explicit timestamp in the document
    final bool hasExplicitTimestamp = declaredCreatedAt != null || earliestActivityDate != null;

    final verifiedCreated = declaredCreatedAt;
    final verifiedActivity = earliestActivityDate;

    DateTime effectiveJoinDate;
    if (verifiedCreated != null && verifiedActivity != null) {
      effectiveJoinDate = verifiedActivity.isBefore(verifiedCreated)
          ? verifiedActivity
          : verifiedCreated;
    } else if (verifiedCreated != null) {
      effectiveJoinDate = verifiedCreated;
    } else if (verifiedActivity != null) {
      effectiveJoinDate = verifiedActivity;
    } else {
      // Historical pre-existing account created before timestamp tracking was added.
      // Retain in "Total Persons" / all traders, but do NOT attribute to "New Today".
      effectiveJoinDate = DateTime(2026, 10, 15, 12, 0);
    }

    final streak = (profile?['streak'] as num?)?.toInt() ?? 0;
    final xp = (profile?['xp'] as num?)?.toInt() ?? 0;
    final claimedMilestones = (profile?['claimedXpMilestones'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final completedMissions = (profile?['completedMissions'] as List?) ?? [];

    final now = DateTime.now();
    final isEffectiveToday = effectiveJoinDate.year == now.year &&
        effectiveJoinDate.month == now.month &&
        effectiveJoinDate.day == now.day;

    if (streak > 1) {
      final streakAnchor = now.subtract(Duration(days: streak - 1));
      if (effectiveJoinDate.isAfter(streakAnchor)) {
        effectiveJoinDate = streakAnchor;
      }
    }

    if (isEffectiveToday) {
      if (!hasExplicitTimestamp) {
        effectiveJoinDate = DateTime(2026, 10, 15, 12, 0);
      } else if (xp > 100 || claimedMilestones.isNotEmpty || completedMissions.isNotEmpty) {
        effectiveJoinDate = now.subtract(const Duration(days: 14));
      } else if ((trades?.length ?? 0) >= 2 || (walletEntries?.length ?? 0) >= 2) {
        effectiveJoinDate = now.subtract(const Duration(days: 7));
      }
    }

    return effectiveJoinDate;
  }
}

final leaderboardProvider = NotifierProvider<LeaderboardNotifier, LeaderboardState>(
  () => LeaderboardNotifier(),
);
