import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_theme.dart';
import '../../data/user_provider.dart';
import '../../data/leaderboard_provider.dart';
import '../../core/currency_formatters.dart';
import '../community/widgets/user_profile_modal.dart';
import '../profile/admin_panel_screen.dart';
import 'widgets/past_seven_days_metrics_sheet.dart';
import '../../core/avatar_helper.dart';
import 'streak_leaderboard_screen.dart';
import '../../core/widgets/prestige_level_badge.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _isNavigatingToStreaks = false;

  void _openStreakScreen() async {
    if (_isNavigatingToStreaks) return;
    _isNavigatingToStreaks = true;
    HapticFeedback.lightImpact();

    try {
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const StreakLeaderboardScreen(),
        ),
      );
    } finally {
      if (mounted) {
        _isNavigatingToStreaks = false;
      }
    }
  }

  bool _checkIsAdmin(UserState userState) {
    final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    final profileEmail = userState.profile.email.toLowerCase();
    final profileName = userState.profile.name.toLowerCase();
    return userEmail == 'admin@gmail.com' ||
           profileEmail == 'admin@gmail.com' ||
           profileName == 'admin';
  }

  void _openUserProfileModal(BuildContext context, Map<String, dynamic> player, {int? rank}) {
    final userId = (player['docId'] as String?)?.isNotEmpty == true
        ? player['docId'] as String
        : (player['uid'] as String? ?? '');
    final fallbackName = player['name']?.toString() ?? 'Trader';
    final fallbackAvatar = player['photoUrl']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEADERBOARD'.tr(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Live Global Rankings'.tr(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: _openStreakScreen,
                    borderRadius: BorderRadius.circular(20),
                    splashColor: const Color(0xFFF97316).withValues(alpha: 0.35),
                    highlightColor: const Color(0xFFF97316).withValues(alpha: 0.18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFF97316),
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Streaks'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFF97316),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFF97316),
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final leaderboard = ref.watch(leaderboardProvider);

            if (leaderboard.error != null && leaderboard.players.isEmpty) {
              return const Center(
                child: Text(
                  'Error loading leaderboard.',
                  style: TextStyle(color: AppColors.loss),
                ),
              );
            }

            if (leaderboard.isLoading && leaderboard.players.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final players = leaderboard.players;
            final myStats = leaderboard.myStats;
            final myRank = leaderboard.myRank;
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
                              totalTraders: leaderboard.totalTradersCount,
                              newTradersToday: leaderboard.newTradersTodayCount,
                              newTradersWeek: leaderboard.newTradersWeekCount,
                              bannedCount: leaderboard.bannedUsersCount,
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
                              return _buildListPlayer(
                                player,
                                rank,
                                userState.profile.name,
                                formatter,
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
        color: AppColors.isDarkMode ? null : AppColors.surface,
        gradient: AppColors.isDarkMode
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF13366A), Color(0xFF0F1722)],
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
              child: AppAvatar(
                avatarUrl: player['photoUrl'],
                radius: radius,
                fallbackName: player['name'],
                backgroundColor: const Color(0xFF2B3139),
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
                    color: AppColors.textPrimary,
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
            PrestigeLevelBadge(
              level: (player['xp'] as int? ?? 0) ~/ 250 + 1,
              isCompact: true,
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
      key: ValueKey(player['uid'] ?? rank),
      onTap: () => _openUserProfileModal(context, player, rank: rank),
      child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
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
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  AppAvatar(
                    avatarUrl: player['photoUrl'],
                    radius: 18,
                    fallbackName: player['name'],
                    backgroundColor: AppColors.surfaceAlt,
                    animate: false,
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
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          PrestigeLevelBadge(
                            level: (player['xp'] as int? ?? 0) ~/ 250 + 1,
                            isCompact: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatter.format(player['netWorth']),
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
          AppAvatar(
            avatarUrl: myStats['photoUrl'],
            radius: 18,
            fallbackName: myStats['name'],
            backgroundColor: const Color(0xFF2B3139),
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
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PrestigeLevelBadge(
                      level: (myStats['xp'] as int? ?? 0) ~/ 250 + 1,
                      isCompact: true,
                    ),
                  ],
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
    final leaderboard = ref.read(leaderboardProvider);
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: sheetHeight,
        child: PastSevenDaysMetricsSheet(
          totalTraders: leaderboard.totalTradersCount,
          newTradersToday: leaderboard.newTradersTodayCount,
          newTradersWeek: leaderboard.newTradersWeekCount,
          pastSevenDays: leaderboard.pastSevenDaysSummary,
          allTraders: leaderboard.allTraders,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outline,
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
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openSevenDaysMetricsSheet(initialMode: 'total'),
                  child: Text(
                    'Global Metrics',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary, size: 12),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outline,
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
                    color: badgeColor ?? AppColors.textPrimary,
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
      );
  }
}
