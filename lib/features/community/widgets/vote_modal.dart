import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_theme.dart';
import '../../../data/community_provider.dart';
import '../../../data/models.dart';

class PredictionVoteModal extends ConsumerWidget {
  final CommunityPost post;

  const PredictionVoteModal({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityState = ref.watch(communityProvider);
    final currentPost = communityState.posts.firstWhere(
      (p) => p.id == post.id,
      orElse: () => post,
    );

    final totalVotes = currentPost.totalVotes;
    final agreePct = currentPost.agreePercentage;
    final disagreePct = totalVotes == 0 ? 0 : 100 - agreePct;
    final myVote = currentPost.myVote;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Community Prediction Vote',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.subtle),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            'Do you agree with ${currentPost.authorName}\'s trade prediction?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.subtle,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Live Consensus Meter
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🎯 $agreePct% Agree',
                      style: GoogleFonts.inter(
                        color: AppColors.profit,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '⚠️ $disagreePct% Disagree',
                      style: GoogleFonts.inter(
                        color: AppColors.loss,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Ratio Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        Expanded(
                          flex: totalVotes == 0 ? 1 : agreePct,
                          child: Container(color: AppColors.profit),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: totalVotes == 0 ? 1 : disagreePct,
                          child: Container(color: AppColors.loss),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  '$totalVotes total community votes cast',
                  style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vote Options Buttons
          Row(
            children: [
              // Agree Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref.read(communityProvider.notifier).votePrediction(currentPost.id, 'agree');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voted: Agree 🎯')),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: myVote == 'agree' ? AppColors.profit.withValues(alpha: 0.25) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: myVote == 'agree' ? AppColors.profit : AppColors.outline,
                        width: myVote == 'agree' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.thumb_up_rounded, color: AppColors.profit, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          'Agree 🎯',
                          style: GoogleFonts.inter(
                            color: AppColors.profit,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Disagree Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref.read(communityProvider.notifier).votePrediction(currentPost.id, 'disagree');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voted: Disagree ⚠️')),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: myVote == 'disagree' ? AppColors.loss.withValues(alpha: 0.25) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: myVote == 'disagree' ? AppColors.loss : AppColors.outline,
                        width: myVote == 'disagree' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.thumb_down_rounded, color: AppColors.loss, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          'Disagree ⚠️',
                          style: GoogleFonts.inter(
                            color: AppColors.loss,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
