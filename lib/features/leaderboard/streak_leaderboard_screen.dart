import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_theme.dart';
import '../../core/avatar_helper.dart';
import '../../data/user_provider.dart';
import '../../data/leaderboard_provider.dart';
import '../community/widgets/user_profile_modal.dart';
import '../../core/widgets/prestige_level_badge.dart';

class StreakLeaderboardScreen extends ConsumerWidget {
  final List<QueryDocumentSnapshot>? initialDocs;
  final List<Map<String, dynamic>>? initialPlayers;

  const StreakLeaderboardScreen({
    super.key,
    this.initialDocs,
    this.initialPlayers,
  });

  static const Color _flameOrange = Color(0xFFF97316);
  static const Color _flameAmber = Color(0xFFF59E0B);
  static const Color _flameGold = Color(0xFFFBBF24);

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
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final lbState = ref.watch(leaderboardProvider);
    final players = lbState.streakPlayers;

    final myRank = lbState.myStreakRank;
    final myStats = lbState.myStreakStats ??
        (myRank > 0 && myRank <= players.length ? players[myRank - 1] : null);

    final nonPodiumCount = players.length > 3 ? players.length - 3 : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'STREAK RANKS',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Daily Active Check-in Streaks',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _flameOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _flameOrange.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, color: _flameOrange, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${userState.profile.streak}d Streak',
                  style: const TextStyle(
                    color: _flameOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: players.isEmpty
            ? (lbState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _flameOrange),
                  )
                : const Center(
                    child: Text('No streaks recorded yet.'),
                  ))
            : RefreshIndicator(
                color: _flameOrange,
                backgroundColor: AppColors.surface,
                onRefresh: () => ref.read(leaderboardProvider.notifier).refresh(),
                child: Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          slivers: [
                            // Streak Vault Incentive Banner
                            SliverToBoxAdapter(
                              child: _buildStreakBanner(userState.profile.streak),
                            ),

                            // Top 3 Podium
                            SliverToBoxAdapter(
                              child: RepaintBoundary(
                                child: _buildStreakPodium(context, players),
                              ),
                            ),

                            // Rank 4+ List
                            SliverPadding(
                              padding: const EdgeInsets.only(top: 8, bottom: 100),
                              sliver: SliverList.builder(
                                itemCount: nonPodiumCount,
                                itemBuilder: (context, index) {
                                  final player = players[index + 3];
                                  final rank = index + 4;
                                  return _buildListStreakPlayer(
                                    context,
                                    player,
                                    rank,
                                    userState.profile.name,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sticky Bottom Bar for Current User's Rank
                    if (myStats != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: _buildStickyUserStreakBar(context, myStats, myRank),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Top Info Banner ────────────────────────────────────────────────────────

  Widget _buildStreakBanner(int myStreak) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _flameOrange.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          colors: [
            _flameOrange.withValues(alpha: 0.12),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _flameOrange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: _flameOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Check-in Streaks',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check in daily in the Rewards tab to maintain your streak flame and climb the ranks!',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Podium for Top 3 ───────────────────────────────────────────────────────

  Widget _buildStreakPodium(BuildContext context, List<Map<String, dynamic>> players) {
    if (players.isEmpty) return const SizedBox();

    final top1 = players.isNotEmpty ? players[0] : null;
    final top2 = players.length > 1 ? players[1] : null;
    final top3 = players.length > 2 ? players[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? null : AppColors.surface,
        gradient: AppColors.isDarkMode
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF331606), Color(0xFF0F1722)],
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _flameOrange.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: top2 != null
                ? _buildPodiumAvatar(context, top2, 2, const Color(0xFFE2E8F0))
                : const SizedBox(),
          ),
          Expanded(
            child: top1 != null
                ? _buildPodiumAvatar(context, top1, 1, _flameGold)
                : const SizedBox(),
          ),
          Expanded(
            child: top3 != null
                ? _buildPodiumAvatar(context, top3, 3, const Color(0xFFF97316))
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumAvatar(BuildContext context, Map<String, dynamic> player, int rank, Color color) {
    final isTop1 = rank == 1;
    final radius = isTop1 ? 40.0 : 32.0;
    final streak = player['streak'] as int? ?? 0;

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
                Icon(Icons.emoji_events_rounded, color: color, size: isTop1 ? 20 : 16),
                const SizedBox(width: 4),
                Text(
                  isTop1 ? '1st' : (rank == 2 ? '2nd' : '3rd'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
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
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  player['name'],
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isTop1 ? 14 : 13,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _flameOrange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _flameOrange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: _flameOrange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$streak Days',
                    style: const TextStyle(
                      color: _flameOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
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

  // ─── List rows (rank 4+) ───────────────────────────────────────────────────

  Widget _buildListStreakPlayer(
    BuildContext context,
    Map<String, dynamic> player,
    int rank,
    String myName,
  ) {
    final isMe = player['name'] == myName;
    final rankString = rank.toString().padLeft(2, '0');
    final streak = player['streak'] as int? ?? 0;

    final List<Color> edgeGradient;
    if (rank == 1) {
      edgeGradient = [_flameGold, _flameAmber];
    } else if (rank == 2) {
      edgeGradient = [const Color(0xFFE2E8F0), const Color(0xFF94A3B8)];
    } else if (rank == 3) {
      edgeGradient = [_flameOrange, const Color(0xFFC2410C)];
    } else {
      edgeGradient = [_flameOrange.withValues(alpha: 0.6), const Color(0xFF334155)];
    }

    return GestureDetector(
      onTap: () => _openUserProfileModal(context, player, rank: rank),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? _flameOrange.withValues(alpha: 0.5) : AppColors.outline),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            // Colored left edge indicator
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
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
                    width: 36,
                    child: Text(
                      rankString,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
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
                  const SizedBox(width: 14),
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
                                  color: isMe ? _flameOrange : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _flameOrange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: _flameOrange,
                                    fontSize: 9.5,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _flameOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _flameOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: _flameOrange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$streak Days',
                          style: const TextStyle(
                            color: _flameOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  // ─── Sticky Bottom Bar for Current User's Streak Rank ──────────────────────

  Widget _buildStickyUserStreakBar(BuildContext context, Map<String, dynamic> myStats, int myRank) {
    final rankString = myRank > 0 ? myRank.toString().padLeft(2, '0') : '--';
    final streak = myStats['streak'] as int? ?? 0;

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
              width: 36,
              child: Text(
                rankString,
                style: const TextStyle(
                  color: _flameOrange,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            AppAvatar(
              avatarUrl: myStats['photoUrl'],
              radius: 18,
              fallbackName: myStats['name'],
              backgroundColor: const Color(0xFF2B3139),
            ),
            const SizedBox(width: 14),
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
                            color: _flameOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'YOUR STREAK RANK',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _flameOrange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _flameOrange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: _flameOrange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$streak Days',
                    style: const TextStyle(
                      color: _flameOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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
}
