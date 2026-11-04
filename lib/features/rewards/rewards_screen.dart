import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../data/user_provider.dart';
import '../../data/models.dart';
import '../learn/quiz_screen.dart';
import '../common/widgets/animated_title_badge.dart';

/// Premium Gamified Rewards & Progression Hub.
/// Engineered with clean, high-craft dark UI: horizontal Trophy Road milestone track,
/// 7-day streak vault, live mission matrix with segmented filters, and achievement cabinet.
/// Uses crisp vector geometry and AcadrioTrade brand tokens (Crypto Teal, Gold & Obsidian).
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  final ScrollController _milestonesScrollController = ScrollController();
  String _missionFilter = 'All'; // 'All', 'Ready', 'In Progress'

  // ── Executive Financial Dark Palette (Prestige Gold & Obsidian) ─────────────
  static const Color _bgOled = Color(0xFF07090C); // Ultra-deep obsidian black
  static const Color _surfaceCard = Color(0xFF0F1318); // Primary container
  static const Color _surfaceRaised = Color(0xFF151B22); // Elevated component
  static const Color _surfaceHighest = Color(0xFF1C242E); // Top-level chip / button
  static const Color _borderSubtle = Color(0xFF222B36); // Crisp structural border
  static const Color _borderActive = Color(0xFF2F3C4B); // Focused border

  static const Color _textHigh = Color(0xFFF8FAFC); // High emphasis title
  static const Color _textMid = Color(0xFF94A3B8); // Body & subtitle slate
  static const Color _textMuted = Color(0xFF64748B); // Tertiary & caption

  static const Color _brandGold = Color(0xFFF0B90B); // Classic Financial Gold (Prestige Rewards)
  static const Color _brandGoldDark = Color(0xFFB38312); // Gold gradient secondary
  static const Color _brandGreen = Color(0xFF10B981); // Refined Forest Green (success / profit)
  static const Color _brandBlue = Color(0xFF3B82F6); // Sapphire Blue (intelligence / quiz)
  static const Color _brandFlame = Color(0xFFF97316); // Amber Streak Flame

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveMilestone();
    });
  }

  void _scrollToActiveMilestone() {
    if (!_milestonesScrollController.hasClients) return;
    final profile = ref.read(userProvider).profile;
    const milestones = UserNotifier.XP_MILESTONES;
    int targetIndex =
        milestones.indexWhere((m) => !profile.claimedXpMilestones.contains(m.id));
    if (targetIndex == -1) targetIndex = milestones.length - 1;

    // Card width (245) + track connector (20) = 265
    final targetOffset = (targetIndex * 265.0).clamp(
      0.0,
      _milestonesScrollController.position.maxScrollExtent,
    );

    _milestonesScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _milestonesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final profile = userState.profile;

    final currentLevel = (profile.xp ~/ 250) + 1;
    final xpForNextLevel = currentLevel * 250;
    final xpIntoCurrentLevel = profile.xp % 250;
    final rankName = profile.evolvedTitle;
    final progress = (xpIntoCurrentLevel / 250.0).clamp(0.0, 1.0);

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final quizAttemptedToday = profile.lastQuizAttempt != null &&
        profile.lastQuizAttempt!.startsWith(todayStr);

    // Progression cycle for daily rewards
    final now = DateTime.now().toLocal();
    int nextStreak = 1;
    final lastClaimStr = userState.profile.lastDailyClaim;
    if (lastClaimStr != null && lastClaimStr.isNotEmpty) {
      final lastClaim = DateTime.tryParse(lastClaimStr)?.toLocal();
      if (lastClaim != null) {
        final difference = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastClaim.year, lastClaim.month, lastClaim.day));
        if (difference.inDays == 1) {
          nextStreak = userState.profile.streak + 1;
        } else if (difference.inDays == 0) {
          nextStreak = userState.profile.streak;
        }
      }
    }
    final cycleIndex = ((nextStreak - 1) % 7).clamp(0, 6);
    final todayCash = UserNotifier.DAILY_CASH_TIERS[cycleIndex];
    final todayXp = UserNotifier.DAILY_XP_TIERS[cycleIndex];
    final displayCycleDay = ((nextStreak - 1) % 7) + 1;

    String formatCash(double usd) {
      return CurrencyFormatters.formatUsd(usd, profile.preferredCurrency,
          decimalDigits: 0);
    }

    return Scaffold(
      backgroundColor: _bgOled,
      appBar: _buildAppBar(context, profile),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. CAREER STATUS HERO DASHBOARD ───────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: _buildCareerDashboard(
                  profile: profile,
                  currentLevel: currentLevel,
                  rankName: rankName,
                  progress: progress,
                  xpForNextLevel: xpForNextLevel,
                  xpIntoCurrentLevel: xpIntoCurrentLevel,
                  userState: userState,
                ),
              ),

              // ── 2. MILESTONE TROPHY ROAD (HORIZONTAL GAME-PASS) ───────────
              _buildMilestoneRoad(
                profile: profile,
                formatCash: formatCash,
              ),

              const SizedBox(height: 16),

              // ── 3. 7-DAY STREAK VAULT MATRIX ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStreakVaultCard(
                  userState: userState,
                  profile: profile,
                  displayCycleDay: displayCycleDay,
                  todayCash: todayCash,
                  todayXp: todayXp,
                  formatCash: formatCash,
                ),
              ),

              const SizedBox(height: 14),

              // ── 4. DAILY CRYPTO IQ QUIZ CARD ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildDailyQuizCard(
                  context: context,
                  quizAttemptedToday: quizAttemptedToday,
                ),
              ),

              const SizedBox(height: 16),

              // ── 5. MISSION MATRIX & QUEST CENTER ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMissionCenter(
                  context: context,
                  userState: userState,
                ),
              ),

              const SizedBox(height: 16),

              // ── 6. TROPHY CABINET (BADGES) ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTrophyCabinet(profile: profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── APP BAR ───────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(BuildContext context, UserProfile profile) {
    return AppBar(
      backgroundColor: _bgOled,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brandGold, _brandGoldDark],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.military_tech_rounded,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rewards Hub',
                  style: GoogleFonts.inter(
                    color: _textHigh,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Career track & milestone grants',
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Tactile XP Pill
        InkWell(
          onTap: () => _showPointsInfoModal(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: _brandGold, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${profile.xp} XP',
                  style: GoogleFonts.inter(
                    color: _textHigh,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── 1. CAREER STATUS HERO DASHBOARD ──────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCareerDashboard({
    required UserProfile profile,
    required int currentLevel,
    required String rankName,
    required double progress,
    required int xpForNextLevel,
    required int xpIntoCurrentLevel,
    required UserState userState,
  }) {
    final nextLevelXpRemaining = xpForNextLevel - profile.xp;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Level Shield Insignia
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B242F), Color(0xFF0F141A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderActive, width: 1.2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LVL',
                      style: GoogleFonts.inter(
                        color: _textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '$currentLevel',
                      style: GoogleFonts.inter(
                        color: _brandGold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
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
                            profile.name.isEmpty ? 'Trader' : profile.name,
                            style: GoogleFonts.inter(
                              color: _textHigh,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedTitleBadge(
                          title: rankName,
                          fontSize: 10,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${profile.xp} Career XP • Ranking for Season 1',
                      style: GoogleFonts.inter(
                        color: _textMid,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Linear XP Progression Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level $currentLevel Progress',
                style: GoogleFonts.inter(
                  color: _textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$nextLevelXpRemaining XP to Level ${currentLevel + 1}',
                style: GoogleFonts.inter(
                  color: _brandGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: _surfaceHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(_brandGold),
            ),
          ),
          const SizedBox(height: 18),

          // HUD Performance Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderSubtle.withValues(alpha: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHudMetric(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: _brandFlame,
                  label: 'STREAK',
                  value: '${profile.streak} Days',
                ),
                Container(width: 1, height: 26, color: _borderSubtle),
                _buildHudMetric(
                  icon: Icons.assignment_turned_in_rounded,
                  iconColor: _brandGreen,
                  label: 'QUESTS',
                  value:
                      '${userState.missions.where((m) => m.completed).length}/${userState.missions.length}',
                ),
                Container(width: 1, height: 26, color: _borderSubtle),
                _buildHudMetric(
                  icon: Icons.military_tech_rounded,
                  iconColor: _brandGold,
                  label: 'TIERS',
                  value: '${profile.claimedXpMilestones.length}/7 Claimed',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 17),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                color: _textHigh,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── 2. MILESTONE TROPHY ROAD (HORIZONTAL GAME-PASS) ──────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMilestoneRoad({
    required UserProfile profile,
    required String Function(double) formatCash,
  }) {
    const milestones = UserNotifier.XP_MILESTONES;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Jump to Active Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alt_route_rounded, color: _brandGold, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Milestone Trophy Road',
                            style: GoogleFonts.inter(
                              color: _textHigh,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Horizontal career path • Swipe to track title evolutions',
                      style: GoogleFonts.inter(
                        color: _textMid,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _scrollToActiveMilestone,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded, color: _brandGold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Active Tier',
                        style: GoogleFonts.inter(
                          color: _brandGold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Connected Horizontal Road
        SizedBox(
          height: 220,
          child: ListView.builder(
            controller: _milestonesScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: milestones.length,
            itemBuilder: (context, index) {
              final milestone = milestones[index];
              final isReached = profile.xp >= milestone.requiredXp;
              final isClaimed = profile.claimedXpMilestones.contains(milestone.id);
              final canClaim = isReached && !isClaimed;
              final progressValue = (profile.xp / milestone.requiredXp).clamp(0.0, 1.0);
              final isLast = index == milestones.length - 1;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMilestonePassCard(
                    context: context,
                    index: index + 1,
                    totalCount: milestones.length,
                    milestone: milestone,
                    isReached: isReached,
                    isClaimed: isClaimed,
                    canClaim: canClaim,
                    progressValue: progressValue,
                    currentXp: profile.xp,
                    formatCash: formatCash,
                  ),
                  if (!isLast)
                    _buildTrackConnector(
                      isPassed: isReached,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackConnector({required bool isPassed}) {
    return Container(
      width: 20,
      height: 3,
      decoration: BoxDecoration(
        color: isPassed ? _brandGold : _borderSubtle,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildMilestonePassCard({
    required BuildContext context,
    required int index,
    required int totalCount,
    required XpMilestone milestone,
    required bool isReached,
    required bool isClaimed,
    required bool canClaim,
    required double progressValue,
    required int currentXp,
    required String Function(double) formatCash,
  }) {
    return Container(
      width: 245,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: canClaim
            ? _surfaceRaised
            : (isClaimed ? _surfaceCard.withValues(alpha: 0.85) : _surfaceCard),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canClaim
              ? _brandGold
              : (isClaimed ? _brandGreen.withValues(alpha: 0.4) : _borderSubtle),
          width: canClaim ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step Ribbon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _surfaceHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TIER $index OF $totalCount',
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isReached ? _brandGreen.withValues(alpha: 0.15) : _surfaceHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${milestone.requiredXp} XP',
                  style: GoogleFonts.inter(
                    color: isReached ? _brandGreen : _textMid,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Central Insignia & Title Unlocked
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF222B36), Color(0xFF131820)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canClaim ? _brandGold.withValues(alpha: 0.5) : _borderSubtle,
                  ),
                ),
                child: Center(
                  child: Text(
                    milestone.badgeIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.titleUnlocked,
                      style: GoogleFonts.inter(
                        color: _textHigh,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Lvl ${milestone.level} Career Evolution',
                      style: GoogleFonts.inter(
                        color: _textMid,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Minimal Capital Grant Capsule
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
            decoration: BoxDecoration(
              color: _surfaceHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Capital Grant:',
                  style: GoogleFonts.inter(
                    color: _textMid,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '+${formatCash(milestone.cashReward)}',
                  style: GoogleFonts.inter(
                    color: _brandGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Progress Gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isReached ? 'Threshold Reached' : '${milestone.requiredXp - currentXp} XP left',
                style: GoogleFonts.inter(
                  color: _textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progressValue * 100).toInt()}%',
                style: GoogleFonts.inter(
                  color: isReached ? _brandGreen : _textMid,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 4,
              backgroundColor: _surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isReached ? _brandGreen : _brandGold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 34,
            child: isClaimed
                ? Container(
                    decoration: BoxDecoration(
                      color: _brandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _brandGreen.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: _brandGreen, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Claimed ✓',
                            style: GoogleFonts.inter(
                              color: _brandGreen,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : canClaim
                    ? ElevatedButton(
                        onPressed: () {
                          final success =
                              ref.read(userProvider.notifier).claimXpMilestone(milestone.id);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Claimed +${formatCash(milestone.cashReward)} & evolved to "${milestone.titleUnlocked}"!',
                                ),
                                backgroundColor: AppColors.profit,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandGold,
                          foregroundColor: const Color(0xFF111417),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'CLAIM CAPITAL GRANT',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: _surfaceHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline_rounded, color: _textMuted, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Locked',
                                style: GoogleFonts.inter(
                                  color: _textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── 3. 7-DAY STREAK VAULT MATRIX ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStreakVaultCard({
    required UserState userState,
    required UserProfile profile,
    required int displayCycleDay,
    required double todayCash,
    required int todayXp,
    required String Function(double) formatCash,
  }) {
    final hasClaimedToday = userState.hasClaimedDaily;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: _brandGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '7-Day Streak Vault',
                    style: GoogleFonts.inter(
                      color: _textHigh,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _brandFlame.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: _brandFlame, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.streak} Days',
                      style: GoogleFonts.inter(
                        color: _brandFlame,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Maintain daily check-in habits. Complete Day 7 to unlock the legendary streak vault.',
            style: GoogleFonts.inter(
              color: _textMid,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // 7 Days Capsule Strip
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - (6 * 6)) / 7;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final dayNum = index + 1;
                  final xp = UserNotifier.DAILY_XP_TIERS[index];

                  final isPastCompleted =
                      hasClaimedToday ? dayNum <= displayCycleDay : dayNum < displayCycleDay;
                  final isToday = dayNum == displayCycleDay && !hasClaimedToday;
                  final isMegaDay = dayNum == 7;

                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isPastCompleted
                          ? _brandGreen.withValues(alpha: 0.12)
                          : (isToday ? _surfaceRaised : _surfaceCard),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPastCompleted
                            ? _brandGreen.withValues(alpha: 0.4)
                            : (isToday ? _brandGold : _borderSubtle),
                        width: isToday ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'D$dayNum',
                          style: GoogleFonts.inter(
                            color: isToday
                                ? _brandGold
                                : (isPastCompleted ? _brandGreen : _textMuted),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isPastCompleted)
                          const Icon(Icons.check_circle_rounded, color: _brandGreen, size: 16)
                        else if (isMegaDay)
                          const Text('🎁', style: TextStyle(fontSize: 14))
                        else
                          const Icon(Icons.stars_rounded, color: _brandGold, size: 16),
                        const SizedBox(height: 6),
                        Text(
                          '+$xp',
                          style: GoogleFonts.inter(
                            color: _textMid,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 16),

          // Tactile Streak Claim Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: hasClaimedToday
                  ? null
                  : () {
                      ref.read(userProvider.notifier).claimDailyReward(
                            customCash: todayCash,
                            customXp: todayXp,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Day $displayCycleDay vault claimed! +${formatCash(todayCash)} & +$todayXp XP',
                          ),
                          backgroundColor: AppColors.profit,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasClaimedToday ? _surfaceRaised : _brandGold,
                foregroundColor: hasClaimedToday ? _textMuted : const Color(0xFF111417),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                hasClaimedToday
                    ? 'Streak Maintained (Day $displayCycleDay Claimed ✓)'
                    : 'Claim Day $displayCycleDay (+${formatCash(todayCash)} & +$todayXp XP)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── 4. DAILY CRYPTO IQ QUIZ CARD ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDailyQuizCard({
    required BuildContext context,
    required bool quizAttemptedToday,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderSubtle),
            ),
            child: const Icon(Icons.psychology_rounded, color: _brandBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Crypto IQ Quiz',
                  style: GoogleFonts.inter(
                    color: _textHigh,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quizAttemptedToday
                      ? 'Completed for today • Great job!'
                      : 'Test your crypto market IQ • +120 XP',
                  style: GoogleFonts.inter(
                    color: quizAttemptedToday ? _brandGreen : _textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (quizAttemptedToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Done ✓',
                style: GoogleFonts.inter(
                  color: _brandGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                'Start',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── 5. MISSION MATRIX & QUEST CENTER ─────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMissionCenter({
    required BuildContext context,
    required UserState userState,
  }) {
    final allMissions = userState.missions;
    final readyMissions = allMissions.where((m) => m.completed).toList();
    final inProgressMissions = allMissions.where((m) => !m.completed).toList();

    List<Mission> displayedMissions;
    if (_missionFilter == 'Ready') {
      displayedMissions = readyMissions;
    } else if (_missionFilter == 'In Progress') {
      displayedMissions = inProgressMissions;
    } else {
      displayedMissions = allMissions;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, color: _brandGold, size: 19),
                const SizedBox(width: 8),
                Text(
                  'Trading Quests Matrix',
                  style: GoogleFonts.inter(
                    color: _textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Text(
              '${readyMissions.length}/${allMissions.length} Claimable',
              style: GoogleFonts.inter(
                color: readyMissions.isNotEmpty ? _brandGreen : _textMid,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Pills
        Row(
          children: [
            _buildFilterPill('All', allMissions.length),
            const SizedBox(width: 8),
            _buildFilterPill('Ready', readyMissions.length),
            const SizedBox(width: 8),
            _buildFilterPill('In Progress', inProgressMissions.length),
          ],
        ),
        const SizedBox(height: 14),

        if (displayedMissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderSubtle),
            ),
            child: Center(
              child: Text(
                _missionFilter == 'Ready'
                    ? 'No quests ready to claim yet. Execute trades below to progress!'
                    : 'All missions in this category are completed.',
                style: GoogleFonts.inter(color: _textMid, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...displayedMissions.map((m) {
            final safeTarget = m.target <= 0 ? 1 : m.target;
            final progressPercent = (m.progress / safeTarget).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: m.completed ? _brandGreen.withValues(alpha: 0.4) : _borderSubtle,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: m.completed
                              ? _brandGreen.withValues(alpha: 0.15)
                              : _surfaceRaised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: m.completed
                                ? _brandGreen.withValues(alpha: 0.3)
                                : _borderSubtle,
                          ),
                        ),
                        child: Icon(
                          m.completed ? Icons.check_circle_rounded : Icons.flag_rounded,
                          color: m.completed ? _brandGreen : _textMid,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              style: GoogleFonts.inter(
                                color: _textHigh,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '+${m.reward} XP Reward',
                              style: GoogleFonts.inter(
                                color: m.completed ? _brandGreen : _brandGold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (m.completed)
                        ElevatedButton(
                          onPressed: () {
                            ref.read(userProvider.notifier).claimMission(m.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quest claimed! +${m.reward} XP earned'),
                                backgroundColor: AppColors.profit,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Claim',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _surfaceRaised,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${m.progress}/${m.target}',
                            style: GoogleFonts.inter(
                              color: _textMid,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!m.completed) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        backgroundColor: _surfaceRaised,
                        valueColor: const AlwaysStoppedAnimation<Color>(_brandGold),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFilterPill(String label, int count) {
    final isSelected = _missionFilter == label;

    return InkWell(
      onTap: () {
        setState(() {
          _missionFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _brandGold : _surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _brandGold : _borderSubtle),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF111417) : _textMid,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── 6. TROPHY CABINET (BADGES) ───────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTrophyCabinet({required UserProfile profile}) {
    final unlockedCount = profile.unlockedBadges.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: _brandGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Trophy Cabinet',
                  style: GoogleFonts.inter(
                    color: _textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Text(
              '$unlockedCount/${ALL_BADGES.length} Badges',
              style: GoogleFonts.inter(
                color: _brandGold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: ALL_BADGES.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) {
            final badge = ALL_BADGES[index];
            final isUnlocked = profile.unlockedBadges.contains(badge.id);

            return Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isUnlocked ? _surfaceCard : _surfaceCard.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnlocked ? _brandGreen.withValues(alpha: 0.35) : _borderSubtle,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(badge.icon, style: const TextStyle(fontSize: 22)),
                      if (isUnlocked)
                        const Icon(Icons.check_circle_rounded, color: _brandGreen, size: 16)
                      else
                        const Icon(Icons.lock_outline_rounded, color: _textMuted, size: 14),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    badge.title,
                    style: GoogleFonts.inter(
                      color: isUnlocked ? _textHigh : _textMid,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.description,
                    style: GoogleFonts.inter(
                      color: _textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── REWARDS INFO SHEET ───────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  void _showPointsInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'About Rewards & Milestone Road',
                  style: GoogleFonts.inter(
                    color: _textHigh,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'XP tracks your real-time trading experience across Spot, Futures Pro, and 1v1 Blitz duels.',
                  style: GoogleFonts.inter(
                    color: _textMid,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '• Swipe horizontally along the Milestone Road to preview and claim capital grants as you rank up.\n• Check in daily to maintain your streak.\n• Complete trading quests to accelerate XP progression.',
                  style: GoogleFonts.inter(
                    color: _textMid,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandGold,
                      foregroundColor: const Color(0xFF111417),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Understood',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
