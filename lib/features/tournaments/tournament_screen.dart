import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_theme.dart';
import '../../core/currency_formatters.dart';
import '../../core/championship_prize_manager.dart';
import '../../data/user_provider.dart';

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> {
  late final Stream<QuerySnapshot> _tournamentStream;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    // Cache stream once in initState to avoid re-subscribing and flickering on parent rebuilds
    _tournamentStream = FirebaseFirestore.instance.collection('weekly_championship').snapshots();
  }

  Future<void> _handleJoinTournament() async {
    setState(() => _isJoining = true);
    await ref.read(userProvider.notifier).joinWeeklyTournament();
    if (mounted) {
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Successfully joined Weekly Championship! Baseline: 0.0%'),
          backgroundColor: AppColors.profit,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _parseTournamentParticipants(List<QueryDocumentSnapshot> docs) {
    final List<Map<String, dynamic>> players = [];

    for (final doc in docs) {
      if (doc.id.startsWith('__') || doc.id.startsWith('prize_') || doc.id.startsWith('settlement_')) {
        continue;
      }
      try {
        final data = doc.data() as Map<String, dynamic>;
        final rawName = (data['name'] as String?) ?? 'Trader';
        final cleanName = rawName.contains('@') ? rawName.split('@').first : rawName;

        final wins = (data['wins'] as num?)?.toInt() ?? 0;
        final losses = (data['losses'] as num?)?.toInt() ?? 0;
        final rawScore = (data['tournamentScore'] as num?)?.toDouble() ?? (wins * 5.0);
        final score = rawScore < 0 ? 0.0 : rawScore;

        players.add({
          'uid': doc.id,
          'name': cleanName.isNotEmpty ? cleanName : 'Trader',
          'score': score,
          'wins': wins,
          'losses': losses,
          'photoUrl': (data['photoUrl'] as String?) ?? '',
          'xp': (data['xp'] as num?)?.toInt() ?? 0,
        });
      } catch (_) {
        // Skip invalid records
      }
    }

    // Sort descending by tournament score
    players.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return players;
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final formatter = AppCurrencyFormatter(userState.profile.preferredCurrency, decimalDigits: 0);
    final myName = userState.profile.name.contains('@') ? userState.profile.name.split('@').first : userState.profile.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Color(0xFFF3BA2F), size: 22),
            SizedBox(width: 8),
            Text('WEEKLY CHAMPIONSHIP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tournamentStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs = snapshot.hasError ? <QueryDocumentSnapshot>[] : (snapshot.data?.docs ?? []);
          final players = _parseTournamentParticipants(docs);

          // If list is empty or permissions fallback, show active user as baseline participant
          if (players.isEmpty) {
            final myScore = (userState.profile.blitzWins * 5.0);
            players.add({
              'uid': userState.profile.email,
              'name': myName,
              'score': myScore,
              'wins': userState.profile.blitzWins,
              'losses': userState.profile.blitzLosses,
              'photoUrl': userState.profile.photoUrl,
              'xp': userState.profile.xp,
            });
          }

          final myIndex = players.indexWhere((p) => p['name'] == myName || p['uid'].toString().contains(myName));
          final hasJoined = myIndex >= 0;
          final myRankStr = hasJoined ? '#${myIndex + 1}' : 'Not Joined';

          final top1 = players.isNotEmpty ? players[0] : null;
          final top2 = players.length > 1 ? players[1] : null;
          final top3 = players.length > 2 ? players[2] : null;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── HERO BANNER & COUNTDOWN ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2B1F0A), Color(0xFF161A1E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3BA2F).withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF3BA2F).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('SEASON #3 • DEDICATED LEAGUE', style: TextStyle(color: Color(0xFFF3BA2F), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 12),
                      const Text('Weekly Crypto Trading Cup', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('All participants start at 0.0% weekly baseline. Win 1v1 duels to boost score!', style: TextStyle(color: Colors.white60, fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 16),

                      // Isolated Countdown Timer Widget (Prevents full-screen rebuild flickering)
                      const _CountdownTimerWidget(),
                      const SizedBox(height: 16),

                      // ── WEEKLY PRIZE POOL SHOWCASE ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF3BA2F).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.workspace_premium, color: Color(0xFFF3BA2F), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${formatter.format(92000)} VIRTUAL CASH PRIZE POOL',
                                  style: const TextStyle(
                                    color: Color(0xFFF3BA2F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPrizePill('🥇 #1', formatter.format(50000), const Color(0xFFF3BA2F)),
                                _buildPrizePill('🥈 #2', formatter.format(25000), const Color(0xFFC0C0C0)),
                                _buildPrizePill('🥉 #3', formatter.format(10000), const Color(0xFFCD7F32)),
                                _buildPrizePill('🎖️ #4-10', formatter.format(1000), AppColors.profit),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3BA2F).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF3BA2F).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_rounded, color: Color(0xFFF3BA2F), size: 13),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Qualification Rule: Must cross >0.0% profit to receive prize money. 0.0% or negative scores are strictly ineligible.',
                                      style: TextStyle(color: Color(0xFFF3BA2F), fontSize: 10, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '💡 Virtual Cash credited directly to winner’s paper trading wallet',
                              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      if (!hasJoined) ...[
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _isJoining ? null : _handleJoinTournament,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF3BA2F),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isJoining
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text('JOIN CHAMPIONSHIP (0.0% BASELINE)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── PODIUM STAGE (TOP 3) ──────────────────────────────────────────
                const Text('LEADERBOARD PODIUM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                const SizedBox(height: 16),

                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // #2 Silver
                      Expanded(child: _buildPodiumColumn(top2, const Color(0xFFC0C0C0), 90, '🥈', 2, formatter)),
                      const SizedBox(width: 8),
                      // #1 Gold
                      Expanded(child: _buildPodiumColumn(top1, const Color(0xFFF3BA2F), 115, '🥇', 1, formatter)),
                      const SizedBox(width: 8),
                      // #3 Bronze
                      Expanded(child: _buildPodiumColumn(top3, const Color(0xFFCD7F32), 70, '🥉', 3, formatter)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── FULL RANKING LIST ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOURNAMENT PARTICIPANTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                    Text('Your Rank: $myRankStr', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),

                if (players.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF141A21), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        const Text('No tournament participants joined yet.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _handleJoinTournament,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text('Be First to Join (0.0%)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  ...players.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final item = entry.value;
                    final isMe = item['name'] == myName || item['uid'].toString().contains(myName);
                    final score = item['score'] as double;
                    final wins = item['wins'] as int;

                    return Container(
                      key: ValueKey(item['uid']),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFF141A21),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isMe ? AppColors.primary.withValues(alpha: 0.5) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text('#$rank', style: TextStyle(color: isMe ? AppColors.primary : Colors.white54, fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(color: Color(0xFF1E2329), shape: BoxShape.circle),
                            child: (item['photoUrl'] as String).isNotEmpty
                                ? ClipOval(child: Image.network(item['photoUrl'] as String, fit: BoxFit.cover))
                                : Center(
                                    child: Text(
                                      (item['name'] as String).trim().isNotEmpty
                                          ? (item['name'] as String).trim()[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item['name'] as String,
                                        style: TextStyle(color: Colors.white, fontWeight: isMe ? FontWeight.w900 : FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (isMe)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                  ],
                                ),
                                Text('$wins Wins • ${item['xp']} XP', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${score > 0 ? '+' : ''}${score.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: score > 0 ? AppColors.profit : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              if (rank <= 10 && score > 0.0)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (rank == 1
                                            ? const Color(0xFFF3BA2F)
                                            : rank == 2
                                                ? const Color(0xFFC0C0C0)
                                                : rank == 3
                                                    ? const Color(0xFFCD7F32)
                                                    : AppColors.profit)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    formatter.format(ChampionshipPrizeManager.getPrizeForRank(rank)),
                                    style: TextStyle(
                                      color: rank == 1
                                          ? const Color(0xFFF3BA2F)
                                          : rank == 2
                                              ? const Color(0xFFC0C0C0)
                                              : rank == 3
                                                  ? const Color(0xFFCD7F32)
                                                  : AppColors.profit,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // ── RULES & INFO ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF141A21), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.emoji_events_rounded, color: Color(0xFFF3BA2F), size: 18),
                          SizedBox(width: 8),
                          Text('Championship Rules & Prizes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('• Weekly Fresh Start: Leaderboard scores reset to 0.0% every week so all traders compete on equal footing.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                      Text('• ${formatter.format(92000)} Virtual Cash Prize Pool: Top 10 win virtual cash for trading (#1: ${formatter.format(50000)} • #2: ${formatter.format(25000)} • #3: ${formatter.format(10000)} • #4 to #10: ${formatter.format(1000)} each).', style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                      const Text('• Positive Profit Requirement (>0.0%): Traders must cross 0.0% profit (>0.0%) to qualify for prize payouts. Participants with 0.0% or negative scores will not receive prize money even if placed in the Top 10.', style: TextStyle(color: Color(0xFFF3BA2F), fontSize: 12, fontWeight: FontWeight.bold, height: 1.5)),
                      const Text('• Instant Winner Claim: All Top 10 winners receive an in-app celebration popup on app open to claim virtual cash into their wallet balance.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                      const Text('• Zero Real-Money Risk: Prizes are virtual paper trading capital credited to your account for risk-free strategy execution.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                      const Text('• 1v1 Blitz Arena Boost: Every blitz arena win awards +5.0% score directly to your championship tally.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrizePill(String rankLabel, String prizeStr, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(rankLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(prizeStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic>? data, Color color, double height, String badgeEmoji, int defaultRank, AppCurrencyFormatter formatter) {
    final name = data != null ? data['name'] as String : 'Waiting...';
    final score = data != null ? data['score'] as double : 0.0;
    final hasData = data != null;
    final prize = ChampionshipPrizeManager.getPrizeForRank(defaultRank);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(badgeEmoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          hasData ? '${score > 0 ? '+' : ''}${score.toStringAsFixed(1)}%' : '0.0%',
          style: TextStyle(color: score > 0 ? AppColors.profit : Colors.white70, fontWeight: FontWeight.w900, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${data != null ? data['rank'] ?? defaultRank : defaultRank}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              if (hasData && score > 0.0)
                Text(
                  formatter.format(prize),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── ISOLATED COUNTDOWN WIDGET (Prevents parent full-screen flickering) ─────────────────
class _CountdownTimerWidget extends StatefulWidget {
  const _CountdownTimerWidget();

  @override
  State<_CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<_CountdownTimerWidget> {
  Timer? _timer;
  late DateTime _seasonEndTime;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _seasonEndTime = _calculateSeasonEndTime();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemainingTime();
      }
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final diff = _seasonEndTime.difference(now);
    final newTimeLeft = diff.isNegative ? Duration.zero : diff;
    if (_timeLeft.inSeconds != newTimeLeft.inSeconds) {
      setState(() {
        _timeLeft = newTimeLeft;
      });
    }
  }

  DateTime _calculateSeasonEndTime() {
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday;
    final sundayEnd = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      23,
      59,
      59,
    );
    if (sundayEnd.isBefore(now)) {
      return sundayEnd.add(const Duration(days: 7));
    }
    return sundayEnd;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = (_timeLeft.inHours % 24).toString().padLeft(2, '0');
    final minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit('$days', 'DAYS'),
        _buildColon(),
        _buildTimeUnit(hours, 'HRS'),
        _buildColon(),
        _buildTimeUnit(minutes, 'MIN'),
        _buildColon(),
        _buildTimeUnit(seconds, 'SEC'),
      ],
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1E2329), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildColon() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(':', style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}
