import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_theme.dart';
import '../../data/user_provider.dart';
import '../../data/market_provider.dart';
import '../../core/currency_formatters.dart';
import '../../data/models.dart';
import '../community/widgets/user_profile_modal.dart';
import '../profile/admin_panel_screen.dart';
import 'widgets/past_seven_days_metrics_sheet.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  // Store stream in initState to avoid re-listening on every rebuild
  late final Stream<QuerySnapshot> _usersStream;
  Timer? _marketRefreshTimer;

  // Cached data structures for O(1) rebuilds during scroll
  QuerySnapshot? _lastSnapshot;
  Map<String, double> _cachedPriceMap = {};
  List<Map<String, dynamic>> _cachedPlayers = [];
  int _cachedMyRank = -1;
  Map<String, dynamic>? _cachedMyStats;

  // Admin-only metrics
  int _totalTradersCount = 0;
  int _newTradersTodayCount = 0;
  int _newTradersWeekCount = 0;
  int _bannedUsersCount = 0;
  List<DayRegistrationSummary> _pastSevenDaysSummary = [];

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAndRecompute();
    });

    // Refresh prices & recalculate net worth every 15s instead of on every 500ms market tick
    _marketRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshAndRecompute(),
    );
  }

  void _refreshAndRecompute() {
    if (!mounted) return;
    final market = ref.read(marketProvider);
    final map = <String, double>{};
    for (final stock in market) {
      map[stock.symbol] = stock.currentPrice;
    }
    _cachedPriceMap = map;

    if (_lastSnapshot != null) {
      _recomputeLeaderboard(_lastSnapshot!);
    }
  }

  void _recomputeLeaderboard(QuerySnapshot snapshot) {
    _lastSnapshot = snapshot;
    final userState = ref.read(userProvider);
    final players = _parsePlayers(snapshot.docs, _cachedPriceMap);

    int myRank = -1;
    Map<String, dynamic>? myStats;
    final currentName = userState.profile.name;
    final currentPublicUid = userState.profile.publicUid;

    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if ((currentPublicUid.isNotEmpty && p['uid'] == currentPublicUid) ||
          (p['name'] == currentName)) {
        myRank = i + 1;
        myStats = p;
        break;
      }
    }

    _computeMetricsForSnapshot(snapshot);

    if (mounted) {
      setState(() {
        _cachedPlayers = players;
        _cachedMyRank = myRank;
        _cachedMyStats = myStats;
      });
    }
  }

  void _computeMetricsForSnapshot(QuerySnapshot snapshot) {
    int totalTraders = 0;
    int bannedCount = 0;

    final now = DateTime.now();
    // Midnight 00:00:00 of the current day (particular calendar day)
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
        final data = doc.data() as Map<String, dynamic>;
        final state = UserState.fromJson(data);

        // Filter out admin accounts from metrics
        if (state.profile.email.toLowerCase() == 'admin@gmail.com' ||
            state.profile.name.toLowerCase().contains('admin')) {
          continue;
        }

        final isBanned = state.isBanned || state.profile.isBanned;
        if (isBanned) {
          bannedCount++;
          continue;
        }

        totalTraders++;

        final joinDate = _extractUserJoinDate(data, state);
        if (joinDate != null) {
          // Check if joinDate falls into one of the past 7 calendar days
          for (int i = 0; i < 7; i++) {
            final dayStart = pastSevenDays[i].date;
            final dayEnd = dayStart.add(const Duration(days: 1));
            if (!joinDate.isBefore(dayStart) && joinDate.isBefore(dayEnd)) {
              pastSevenDays[i].entries.add(
                TraderRegistrationEntry(
                  uid: (state.profile.publicUid.isNotEmpty) ? state.profile.publicUid : doc.id,
                  name: state.profile.name,
                  email: state.profile.email,
                  photoUrl: state.profile.photoUrl,
                  joinDate: joinDate,
                  virtualBalance: state.profile.virtualBalance,
                  netWorth: state.profile.virtualBalance,
                  xp: state.profile.xp,
                  isBanned: isBanned,
                ),
              );
              break;
            }
          }
        }
      } catch (_) {}
    }

    // Sort entries within each day newest first
    for (final day in pastSevenDays) {
      day.entries.sort((a, b) => b.joinDate.compareTo(a.joinDate));
    }

    _totalTradersCount = totalTraders;
    _newTradersTodayCount = pastSevenDays[0].count; // Strictly calendar day today since 00:00:00
    _newTradersWeekCount = pastSevenDays.fold(0, (total, d) => total + d.count);
    _bannedUsersCount = bannedCount;
    _pastSevenDaysSummary = pastSevenDays;
  }

  DateTime? _extractUserJoinDate(Map<String, dynamic> data, [UserState? state]) {
    // 1. Find true earliest historical timestamp across all user activity
    DateTime? earliestActivityDate;

    final walletEntries = data['walletEntries'] as List?;
    if (walletEntries != null && walletEntries.isNotEmpty) {
      for (final e in walletEntries) {
        if (e is Map && e['timestamp'] != null) {
          final d = DateTime.tryParse(e['timestamp'].toString());
          if (d != null) {
            if (earliestActivityDate == null || d.isBefore(earliestActivityDate)) {
              earliestActivityDate = d;
            }
          }
        }
      }
    }

    final trades = data['trades'] as List?;
    if (trades != null && trades.isNotEmpty) {
      for (final t in trades) {
        if (t is Map && t['time'] != null) {
          final d = DateTime.tryParse(t['time'].toString());
          if (d != null) {
            if (earliestActivityDate == null || d.isBefore(earliestActivityDate)) {
              earliestActivityDate = d;
            }
          }
        }
      }
    }

    final spotOrders = data['spotLimitOrders'] as List?;
    if (spotOrders != null && spotOrders.isNotEmpty) {
      for (final o in spotOrders) {
        if (o is Map && o['createdAt'] != null) {
          final d = DateTime.tryParse(o['createdAt'].toString());
          if (d != null) {
            if (earliestActivityDate == null || d.isBefore(earliestActivityDate)) {
              earliestActivityDate = d;
            }
          }
        }
      }
    }

    // 2. Read declared createdAt
    DateTime? declaredCreatedAt;
    if (state?.createdAt != null) {
      declaredCreatedAt = state!.createdAt;
    } else {
      final rawCreated = data['createdAt'] ?? (data['profile'] as Map?)?['createdAt'];
      if (rawCreated != null) {
        if (rawCreated is Timestamp) {
          declaredCreatedAt = rawCreated.toDate();
        } else {
          declaredCreatedAt = DateTime.tryParse(rawCreated.toString());
        }
      }
    }

    DateTime? effectiveJoinDate = declaredCreatedAt ?? earliestActivityDate;
    if (earliestActivityDate != null && effectiveJoinDate != null) {
      if (earliestActivityDate.isBefore(effectiveJoinDate)) {
        effectiveJoinDate = earliestActivityDate;
      }
    }

    if (effectiveJoinDate == null) return null;

    // 3. HARD SANITY CHECKS: Filter out existing/legacy users falsely stamped with today's date
    final profile = data['profile'] as Map<String, dynamic>?;
    final streak = (state?.profile.streak ?? (profile?['streak'] as num?)?.toInt() ?? 0);
    final xp = (state?.profile.xp ?? (profile?['xp'] as num?)?.toInt() ?? 0);
    final claimedMilestones = state?.profile.claimedXpMilestones ??
        (profile?['claimedXpMilestones'] as List?)?.map((e) => e.toString()).toSet() ??
        {};

    final now = DateTime.now();
    final isEffectiveToday = effectiveJoinDate.year == now.year &&
        effectiveJoinDate.month == now.month &&
        effectiveJoinDate.day == now.day;

    // Guard A: Streak > 1 means user has been active for at least `streak` days
    if (streak > 1) {
      final streakAnchor = now.subtract(Duration(days: streak - 1));
      if (effectiveJoinDate.isAfter(streakAnchor)) {
        effectiveJoinDate = streakAnchor;
      }
    }

    // Guard B: High XP or Claimed Milestones means they are seasoned traders (not joined today)
    if (isEffectiveToday && (xp > 150 || claimedMilestones.isNotEmpty)) {
      effectiveJoinDate = now.subtract(const Duration(days: 14));
    }

    // Guard C: Existing trading or wallet history means they are not brand new today
    if (isEffectiveToday && ((trades?.length ?? 0) >= 2 || (walletEntries?.length ?? 0) >= 2)) {
      effectiveJoinDate = now.subtract(const Duration(days: 7));
    }

    return effectiveJoinDate;
  }

  bool _checkIsAdmin(UserState userState) {
    final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    final profileEmail = userState.profile.email.toLowerCase();
    final profileName = userState.profile.name.toLowerCase();
    return userEmail == 'admin@gmail.com' ||
           profileEmail == 'admin@gmail.com' ||
           profileName == 'admin';
  }

  @override
  void dispose() {
    _marketRefreshTimer?.cancel();
    super.dispose();
  }

  void _openUserProfileModal(BuildContext context, Map<String, dynamic> player, {int? rank}) {
    final userId = (player['docId'] as String?)?.isNotEmpty == true
        ? player['docId'] as String
        : (player['uid'] as String? ?? '');
    final fallbackName = player['name']?.toString() ?? 'Trader';
    final fallbackAvatar = player['photoUrl']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => UserProfileModal(
        userId: userId,
        fallbackName: fallbackName,
        fallbackAvatar: fallbackAvatar,
        initialRank: rank != null && rank > 0 ? '#$rank' : null,
      ),
    );
  }

  // ─── Parse + sort players using the cached price map ──────────────────────
  List<Map<String, dynamic>> _parsePlayers(
    List<QueryDocumentSnapshot> docs,
    Map<String, double> priceMap,
  ) {
    final List<Map<String, dynamic>> players = [];

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final state = UserState.fromJson(data);

        if (state.profile.email.toLowerCase() == 'admin@gmail.com' ||
            state.profile.name.toLowerCase().contains('admin')) {
          continue;
        }

        if (state.isBanned || state.profile.isBanned) {
          continue;
        }

        double portfolioValue = 0;
        for (final holding in state.holdings) {
          final price = priceMap[holding.symbol] ?? holding.averagePrice;
          portfolioValue += price * holding.quantity;
        }

        double futuresValue = 0;
        for (final pos in state.futuresPositions) {
          final price = priceMap[pos.symbol];
          if (price != null) {
            final isLong = pos.side == OrderSide.buy;
            final diff = price - pos.entryPrice;
            final pnl = isLong ? diff * pos.quantity : -diff * pos.quantity;
            final currentValue = pos.margin + pnl;
            futuresValue += currentValue > 0 ? currentValue : 0;
          } else {
            futuresValue += pos.margin;
          }
        }

        final netWorth = state.profile.virtualBalance + portfolioValue + futuresValue;

        players.add({
          'docId': doc.id,
          'uid': state.profile.publicUid.isNotEmpty ? state.profile.publicUid : doc.id,
          'name': state.profile.name.isNotEmpty ? state.profile.name : 'Trader',
          'netWorth': netWorth,
          'xp': state.profile.xp,
          'streak': state.profile.streak,
          'photoUrl': state.profile.photoUrl,
        });
      } catch (_) {}
    }

    players.sort(
      (a, b) => (b['netWorth'] as double).compareTo(a['netWorth'] as double),
    );
    return players;
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);

    final formatter = AppCurrencyFormatter(
      userState.profile.preferredCurrency,
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEADERBOARD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Live Global Rankings',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _usersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError && _cachedPlayers.isEmpty) {
              return const Center(
                child: Text(
                  'Error loading leaderboard.',
                  style: TextStyle(color: AppColors.loss),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != _lastSnapshot) {
              _lastSnapshot = snapshot.data;
              if (_cachedPriceMap.isEmpty) {
                final market = ref.read(marketProvider);
                for (final stock in market) {
                  _cachedPriceMap[stock.symbol] = stock.currentPrice;
                }
              }
              _cachedPlayers = _parsePlayers(snapshot.data!.docs, _cachedPriceMap);
              _computeMetricsForSnapshot(snapshot.data!);
              
              final currentName = userState.profile.name;
              final currentPublicUid = userState.profile.publicUid;
              _cachedMyRank = -1;
              _cachedMyStats = null;

              for (int i = 0; i < _cachedPlayers.length; i++) {
                final p = _cachedPlayers[i];
                if ((currentPublicUid.isNotEmpty && p['uid'] == currentPublicUid) ||
                    (p['name'] == currentName)) {
                  _cachedMyRank = i + 1;
                  _cachedMyStats = p;
                  break;
                }
              }
            }

            if (_cachedPlayers.isEmpty && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final players = _cachedPlayers;
            final myStats = _cachedMyStats;
            final myRank = _cachedMyRank;
            final nonPodiumCount = players.length > 3 ? players.length - 3 : 0;
            final isAdmin = _checkIsAdmin(userState);

            return Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (isAdmin)
                          SliverToBoxAdapter(
                            child: _buildAdminStatsCard(
                              totalTraders: _totalTradersCount,
                              newTradersToday: _newTradersTodayCount,
                              newTradersWeek: _newTradersWeekCount,
                              bannedCount: _bannedUsersCount,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: RepaintBoundary(
                            child: _buildPodium(players, formatter),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          sliver: SliverList.builder(
                            itemCount: nonPodiumCount,
                            itemBuilder: (context, index) {
                              final player = players[index + 3];
                              final rank = index + 4;
                              return RepaintBoundary(
                                key: ValueKey(player['uid'] ?? 'player_$rank'),
                                child: _buildListPlayer(
                                  player,
                                  rank,
                                  userState.profile.name,
                                  formatter,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (myStats != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: RepaintBoundary(
                      child: _buildStickyUserBar(myStats, myRank, formatter),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Podium (top 3) ────────────────────────────────────────────────────────

  Widget _buildPodium(
    List<Map<String, dynamic>> players,
    AppCurrencyFormatter formatter,
  ) {
    if (players.isEmpty) return const SizedBox();

    final top1 = players.isNotEmpty ? players[0] : null;
    final top2 = players.length > 1 ? players[1] : null;
    final top3 = players.length > 2 ? players[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13366A), Color(0xFF0F1722)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: top2 != null
                ? _buildPodiumAvatar(top2, 2, const Color(0xFFE2E8F0), formatter)
                : const SizedBox(),
          ),
          Expanded(
            child: top1 != null
                ? _buildPodiumAvatar(top1, 1, const Color(0xFFFBBF24), formatter)
                : const SizedBox(),
          ),
          Expanded(
            child: top3 != null
                ? _buildPodiumAvatar(top3, 3, const Color(0xFFF97316), formatter)
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumAvatar(
    Map<String, dynamic> player,
    int rank,
    Color color,
    AppCurrencyFormatter formatter,
  ) {
    final isTop1 = rank == 1;
    final radius = isTop1 ? 40.0 : 32.0;
    final hasPhoto =
        player['photoUrl'] != null &&
        player['photoUrl'].toString().trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _openUserProfileModal(context, player, rank: rank),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: color, size: isTop1 ? 20 : 16),
                const SizedBox(width: 4),
                Text(
                  isTop1 ? '1st' : (rank == 2 ? '2nd' : '3rd'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: const Color(0xFF2B3139),
                child: hasPhoto
                    ? ClipOval(
                        child: Image.network(
                          player['photoUrl'],
                          width: radius * 2,
                          height: radius * 2,
                          cacheWidth: 120,
                          cacheHeight: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initial(
                            player['name'],
                            radius * 0.7,
                          ),
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : _initial(player['name'], radius * 0.7),
                        ),
                      )
                    : _initial(player['name'], radius * 0.7),
              ),
            ),
            const SizedBox(height: 10),
            // Fixed height name container ensures all 3 columns align horizontally regardless of line wrap
            SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  player['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: isTop1 ? 15 : 13.5,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${player['xp']} XP',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((player['streak'] as int? ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '🔥 ${player['streak']}',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatter.format(player['netWorth']),
                style: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── List rows (rank 4+) ───────────────────────────────────────────────────

  Widget _buildListPlayer(
    Map<String, dynamic> player,
    int rank,
    String myName,
    AppCurrencyFormatter formatter,
  ) {
    final isMe = player['name'] == myName;
    final hasPhoto =
        player['photoUrl'] != null &&
        player['photoUrl'].toString().trim().isNotEmpty;
    final rankString = rank.toString().padLeft(2, '0');

    final List<Color> edgeGradient;
    if (rank == 1) {
      edgeGradient = [const Color(0xFFFCD34D), const Color(0xFFD97706)];
    } else if (rank == 2) {
      edgeGradient = [const Color(0xFFA3E635), const Color(0xFF4D7C0F)];
    } else if (rank == 3) {
      edgeGradient = [const Color(0xFF67E8F9), const Color(0xFF0891B2)];
    } else {
      edgeGradient = [const Color(0xFF64748B), const Color(0xFF334155)];
    }

    return GestureDetector(
      onTap: () => _openUserProfileModal(context, player, rank: rank),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2329),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Stack(
        children: [
          // Coloured left edge.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: edgeGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rankString,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2B3139),
                  child: hasPhoto
                      ? ClipOval(
                          child: Image.network(
                            player['photoUrl'],
                            width: 36,
                            height: 36,
                            cacheWidth: 100,
                            cacheHeight: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _initial(player['name'], 14),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : _initial(player['name'], 14),
                          ),
                        )
                      : _initial(player['name'], 14),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player['name'],
                              style: TextStyle(
                                color: isMe
                                    ? const Color(0xFF22C55E)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((player['streak'] as int? ?? 0) > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '🔥 ${player['streak']}',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (rank <= 3) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: rank == 1
                                  ? const Color(0xFFFBBF24)
                                  : rank == 2
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFFF97316),
                            ),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player['xp']} XP',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatter.format(player['netWorth']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ─── Sticky "Your Rank" bar at the bottom ─────────────────────────────────

  Widget _buildStickyUserBar(
    Map<String, dynamic> myStats,
    int myRank,
    AppCurrencyFormatter formatter,
  ) {
    final hasPhoto =
        myStats['photoUrl'] != null &&
        myStats['photoUrl'].toString().trim().isNotEmpty;
    final rankString = myRank.toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () => _openUserProfileModal(context, myStats, rank: myRank),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1722).withValues(alpha: 0.98),
        border: const Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rankString,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2B3139),
            child: hasPhoto
                ? ClipOval(
                    child: Image.network(
                      myStats['photoUrl'],
                      width: 36,
                      height: 36,
                      cacheWidth: 100,
                      cacheHeight: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _initial(myStats['name'], 14),
                      loadingBuilder: (_, child, progress) =>
                          progress == null
                              ? child
                              : _initial(myStats['name'], 14),
                    ),
                  )
                : _initial(myStats['name'], 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        myStats['name'],
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((myStats['streak'] as int? ?? 0) > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '🔥 ${myStats['streak']}',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (myRank <= 3) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: myRank == 1
                            ? const Color(0xFFFBBF24)
                            : myRank == 2
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFFF97316),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const Text(
                      'YOUR RANK',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${myStats['xp']} XP',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatter.format(myStats['netWorth']),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    ),
  );
}

  void _openSevenDaysMetricsSheet({required String initialMode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => PastSevenDaysMetricsSheet(
          totalTraders: _totalTradersCount,
          newTradersToday: _newTradersTodayCount,
          newTradersWeek: _newTradersWeekCount,
          pastSevenDays: _pastSevenDaysSummary,
          initialMode: initialMode,
        ),
      ),
    );
  }

  // ─── Admin Overview Card ──────────────────────────────────────────────────

  Widget _buildAdminStatsCard({
    required int totalTraders,
    required int newTradersToday,
    required int newTradersWeek,
    required int bannedCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16181C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2F3336),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Admin badge, title, and Admin Panel navigation pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1D9BF0).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Color(0xFF1D9BF0), size: 12),
                    SizedBox(width: 3.5),
                    Text(
                      'ADMIN ONLY',
                      style: TextStyle(
                        color: Color(0xFF1D9BF0),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Global Metrics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202327),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2F3336)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 3 Metric Tiles: Total Persons, Added New Today, Added New 7D (Clickable for 7 Days Data)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.people_alt_rounded,
                  iconColor: const Color(0xFF1D9BF0),
                  label: 'Total',
                  value: '$totalTraders',
                  subtitle: 'Registered',
                  onTap: () => _openSevenDaysMetricsSheet(initialMode: 'total'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: AppColors.profit,
                  label: 'New Today',
                  value: '+$newTradersToday',
                  subtitle: 'Today',
                  badgeColor: AppColors.profit,
                  onTap: () => _openSevenDaysMetricsSheet(initialMode: 'today'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: '7 Days',
                  value: '+$newTradersWeek',
                  subtitle: 'This week',
                  onTap: () => _openSevenDaysMetricsSheet(initialMode: 'week'),
                ),
              ),
            ],
          ),
          if (bannedCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.loss.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.loss.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: AppColors.loss, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    '$bannedCount banned account${bannedCount > 1 ? "s" : ""} hidden from rankings',
                    style: const TextStyle(
                      color: AppColors.loss,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: iconColor.withValues(alpha: 0.15),
        highlightColor: iconColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF202327),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2F3336),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: iconColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF71767B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF71767B), size: 7.5),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: badgeColor ?? Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF71767B),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper: avatar initials ───────────────────────────────────────────────

  Widget _initial(String name, double fontSize) {
    final letter =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Text(
      letter,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
